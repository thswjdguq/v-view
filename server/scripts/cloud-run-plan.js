function onlyKeys(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value) ||
      Object.keys(value).some(key => !allowed.includes(key))) {
    throw new Error('Unsupported deployment configuration. Use secret references, not secret values.');
  }
}

function text(value, pattern, label) {
  if (typeof value !== 'string' || !pattern.test(value)) throw new Error(`Invalid ${label}`);
  return value;
}

function secretRef(value) {
  onlyKeys(value, ['name', 'version']);
  return {
    name: text(value.name, /^[A-Za-z0-9_-]{1,255}$/, 'secret name'),
    version: text(String(value.version ?? ''), /^[1-9][0-9]{0,8}$/, 'pinned secret version'),
  };
}

export function createCloudRunPlan(config) {
  onlyKeys(config, ['projectId','region','serviceName','runtimeAccount','openAiSecret','allowedUsersSecret']);
  const projectId = text(config.projectId, /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/, 'project ID');
  const region = text(config.region, /^[a-z]+-[a-z]+[0-9]+$/, 'region');
  const serviceName = text(config.serviceName, /^[a-z](?:[a-z0-9-]{0,47}[a-z0-9])?$/, 'service name');
  const account = text(config.runtimeAccount, /^[a-z][a-z0-9-]{4,28}[a-z0-9]$/, 'runtime account');
  const openAi = secretRef(config.openAiSecret);
  const users = secretRef(config.allowedUsersSecret);
  if (openAi.name === users.name) throw new Error('API key and user allowlist must use separate secrets');
  const identity = `${account}@${projectId}.iam.gserviceaccount.com`;
  const common = [`--project=${projectId}`, '--quiet'];
  const steps = [{ id: 'enable-apis', args: ['services','enable','run.googleapis.com',
    'cloudbuild.googleapis.com','artifactregistry.googleapis.com','secretmanager.googleapis.com', ...common] }];
  for (const [id, secret] of [['api-key',openAi],['allowed-users',users]]) {
    steps.push({ id: `verify-secret-${id}`, expectEnabled: true,
      args: ['secrets','versions','describe',secret.version,`--secret=${secret.name}`,'--format=value(state)',...common] });
  }
  steps.push({ id: 'runtime-account',
    checkArgs: ['iam','service-accounts','describe',identity,...common],
    args: ['iam','service-accounts','create',account,'--display-name=v-view AI runtime',...common] });
  steps.push({ id: 'auth-read', args: ['projects','add-iam-policy-binding',projectId,
    `--member=serviceAccount:${identity}`, '--role=roles/firebaseauth.viewer', '--condition=None', ...common] });
  for (const [id, secret] of [['api-key',openAi],['allowed-users',users]]) {
    steps.push({ id: `secret-access-${id}`, args: ['secrets','add-iam-policy-binding',secret.name,
      `--member=serviceAccount:${identity}`, '--role=roles/secretmanager.secretAccessor', '--condition=None', ...common] });
  }
  steps.push({ id: 'deploy', args: ['run','deploy',serviceName,'--source=.',`--region=${region}`,
    `--service-account=${identity}`, '--min=0','--max=1','--concurrency=2', '--memory=512Mi','--cpu=1',
    '--timeout=35s','--port=8080', '--allow-unauthenticated', '--labels=app=v-view,stage=portfolio',
    `--set-env-vars=GOOGLE_CLOUD_PROJECT=${projectId}`,
    `--set-secrets=OPENAI_API_KEY=${openAi.name}:${openAi.version},ALLOWED_FIREBASE_UIDS=${users.name}:${users.version}`,
    ...common] });
  steps.push({ id: 'service-url', args: ['run','services','describe',serviceName,`--region=${region}`,
    '--format=value(status.url)', ...common] });
  return { projectId, region, serviceName, runtimeIdentity: identity,
    notes: [
      'The HTTP endpoint is public at Cloud Run; the application enforces Firebase ID token verification and its UID allowlist.',
      'Secret versions must already exist and be ENABLED. No secret payload is read or printed.',
      'Scaling limits are not a monthly spending cap. This plan is for a small authenticated pilot.',
    ], steps };
}

function quote(value) {
  return /^[A-Za-z0-9_./:@=,+-]+$/.test(value) ? value : "'" + value.replaceAll("'", "'\"'\"'") + "'";
}

export function renderCloudRunScript(plan) {
  const command = args => ['gcloud', ...args.map(quote)].join(' ');
  const lines = ['#!/usr/bin/env bash', 'set -euo pipefail',
    'task_script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"',
    'cd -- "$task_script_dir/.."',
    `printf '%s\\n' ${quote(`Project: ${plan.projectId}; region: ${plan.region}; service: ${plan.serviceName}`)}`,
    'command -v gcloud >/dev/null || { echo "Run this script in Google Cloud Shell." >&2; exit 1; }',
    'test -f Dockerfile || { echo "Server source directory not found." >&2; exit 1; }'];
  for (const step of plan.steps) {
    lines.push('', `# ${step.id}`);
    if (step.expectEnabled) {
      lines.push(`task_secret_state="$(${command(step.args)})"`,
        'if [[ "$task_secret_state" != "ENABLED" ]]; then echo "Expected ENABLED secret version." >&2; exit 1; fi');
    } else if (step.checkArgs) {
      lines.push(`if ! ${command(step.checkArgs)} >/dev/null 2>&1; then`, `  ${command(step.args)}`, 'fi');
    } else if (step.id === 'service-url') {
      lines.push(`task_service_url="$(${command(step.args)})"`,
        'printf "\\nAI_PROXY_URL=%s/v1\\n" "${task_service_url%/}"');
    } else {
      lines.push(command(step.args));
    }
  }
  return lines.join('\n') + '\n';
}
