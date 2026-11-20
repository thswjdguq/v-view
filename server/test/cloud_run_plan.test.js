import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createCloudRunPlan, renderCloudRunScript } from '../scripts/cloud-run-plan.js';

const config = {
  projectId: 'example-vview-project', region: 'asia-northeast3', serviceName: 'v-view-ai',
  runtimeAccount: 'v-view-ai-runtime',
  openAiSecret: { name: 'v-view-openai-api-key', version: '1' },
  allowedUsersSecret: { name: 'v-view-allowed-firebase-uids', version: '1' },
};

test('confirmed Firebase project is explicit in every gcloud command', () => {
  const plan = createCloudRunPlan(config);
  for (const step of plan.steps) {
    assert.ok(step.args.includes('--project=example-vview-project'));
    if (step.checkArgs) assert.ok(step.checkArgs.includes('--project=example-vview-project'));
  }
});
test('deploys with dedicated identity and limits for a small pilot', () => {
  const plan = createCloudRunPlan(config);
  const deploy = plan.steps.find(step => step.id === 'deploy');
  assert.ok(deploy.args.includes('--service-account=v-view-ai-runtime@example-vview-project.iam.gserviceaccount.com'));
  for (const flag of ['--min=0','--max=1','--concurrency=2','--memory=512Mi','--cpu=1','--timeout=35s']) {
    assert.ok(deploy.args.includes(flag));
  }
  assert.ok(deploy.args.includes('--allow-unauthenticated'));
  assert.ok(plan.notes.some(note => note.includes('Firebase')));
});
test('both sensitive values are version-pinned secret references, never raw keys or UIDs', () => {
  const deploy = createCloudRunPlan(config).steps.find(step => step.id === 'deploy');
  assert.ok(deploy.args.includes('--set-secrets=OPENAI_API_KEY=v-view-openai-api-key:1,ALLOWED_FIREBASE_UIDS=v-view-allowed-firebase-uids:1'));
  assert.ok(deploy.args.includes('--set-env-vars=GOOGLE_CLOUD_PROJECT=example-vview-project'));
  assert.equal(JSON.stringify(deploy).includes('sk-'), false);
});
test('runtime receives read-only Auth access and secret access scoped to each secret', () => {
  const plan = createCloudRunPlan(config);
  const auth = plan.steps.find(step => step.id === 'auth-read');
  assert.ok(auth.args.includes('--role=roles/firebaseauth.viewer'));
  assert.equal(plan.steps.some(step => step.args.includes('--role=roles/editor')), false);
  const secrets = plan.steps.filter(step => step.id.startsWith('secret-access-'));
  assert.equal(secrets.length, 2);
  for (const step of secrets) {
    assert.deepEqual(step.args.slice(0,2), ['secrets','add-iam-policy-binding']);
    assert.ok(step.args.includes('--role=roles/secretmanager.secretAccessor'));
  }
});
test('rejects missing identity, latest secret versions and unexpected raw secret fields', () => {
  for (const invalid of [
    { ...config, projectId: '' },
    { ...config, region: 'asia-northeast3; echo bad' },
    { ...config, runtimeAccount: 'root@example.com' },
    { ...config, openAiSecret: { name: 'key', version: 'latest' } },
    { ...config, allowedUsersSecret: null },
    { ...config, openAiApiKey: 'private-value' },
  ]) assert.throws(() => createCloudRunPlan(invalid));
});
test('rendering only produces a reviewable script, validates secrets before deployment', () => {
  const plan = createCloudRunPlan(config);
  const script = renderCloudRunScript(plan);
  assert.ok(script.includes('set -euo pipefail'));
  assert.ok(script.includes("cd --"));
  assert.ok(script.indexOf('secrets versions describe') < script.indexOf('run deploy'));
  assert.equal(script.includes('secrets versions access'), false);
  assert.equal(script.includes('auth print-access-token'), false);
  assert.ok(script.includes('Expected ENABLED'));
});
test('source upload ignores local credentials and deployment material', async () => {
  const { readFile } = await import('node:fs/promises');
  const ignore = await readFile(new URL('../.gcloudignore', import.meta.url), 'utf8');
  assert.ok(ignore.startsWith('**\n'));
  assert.ok(ignore.includes('!Dockerfile'));
  assert.ok(ignore.includes('!src/**'));
  assert.equal(ignore.includes('!.env'), false);
  assert.equal(ignore.includes('!node_modules'), false);
  assert.equal(ignore.includes('!deploy/'), false);
});
