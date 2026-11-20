import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createCloudRunPlan, renderCloudRunScript } from './cloud-run-plan.js';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const input = resolve(process.argv[2] ?? resolve(root, 'deploy/cloud-run.example.json'));
const config = JSON.parse(await readFile(input, 'utf8'));
const plan = createCloudRunPlan(config);
const output = resolve(root, '.deploy');
await mkdir(output, { recursive: true });
await writeFile(resolve(output, 'plan.json'), JSON.stringify(plan, null, 2) + '\n');
await writeFile(resolve(output, 'deploy-cloud-run.sh'), renderCloudRunScript(plan));
console.log(`Prepared ${plan.serviceName} for ${plan.projectId} (${plan.region}).`);
console.log('Files: .deploy/plan.json and .deploy/deploy-cloud-run.sh');
console.log('No cloud commands executed. Review the plan before running the script in Cloud Shell.');
