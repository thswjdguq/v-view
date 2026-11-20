import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { parseEnv } from 'node:util';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { serverRoot, isUsableApiKey } from '../src/local-config.js';

export function setupLocalConfig({ serverRoot: root = serverRoot, env = process.env } = {}) {
  const destination = resolve(root, '.env.local');
  if (existsSync(destination)) {
    const config = parseEnv(readFileSync(destination, 'utf8'));
    return { ready: isUsableApiKey(env.OPENAI_API_KEY ?? config.OPENAI_API_KEY), created: false, source: 'existing-local' };
  }
  if (isUsableApiKey(env.OPENAI_API_KEY)) return { ready: true, created: false, source: 'environment' };
  for (const candidate of [resolve(root, '.env'), resolve(root, '../v_view/.env')]) {
    if (!existsSync(candidate)) continue;
    const config = parseEnv(readFileSync(candidate, 'utf8'));
    if (isUsableApiKey(config.OPENAI_API_KEY)) {
      writeFileSync(destination, `OPENAI_API_KEY=${config.OPENAI_API_KEY}\nPORT=8080\n`, { flag: 'wx', mode: 0o600 });
      return { ready: true, created: true, source: 'project-config' };
    }
  }
  writeFileSync(destination, 'OPENAI_API_KEY=\nPORT=8080\n', { flag: 'wx', mode: 0o600 });
  return { ready: false, created: true, source: 'needs-key' };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const result = setupLocalConfig();
    console.log(result.ready ? 'Local API key configuration is ready. Key values are never displayed.'
      : 'Enter your GPT API key in server/.env.local, then run npm start. Do not paste the key into chat.');
    process.exitCode = result.ready ? 0 : 2;
  } catch {
    console.error('Could not prepare server/.env.local. Existing files were not overwritten.');
    process.exitCode = 1;
  }
}
