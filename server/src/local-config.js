import { existsSync, readFileSync } from 'node:fs';
import { parseEnv } from 'node:util';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const serverRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const isUsableApiKey = value => typeof value === 'string' && /^sk-[A-Za-z0-9_-]{20,}$/.test(value);
export function readLocalConfig({ serverRoot: root = serverRoot, env = process.env } = {}) {
  if (env.K_SERVICE || env.FUNCTION_TARGET || env.GAE_ENV) {
    throw new Error('This entry point is only for your local PC.');
  }
  const path = resolve(root, '.env.local');
  const file = existsSync(path) ? parseEnv(readFileSync(path, 'utf8')) : {};
  const values = { ...file, ...env };
  if (!isUsableApiKey(values.OPENAI_API_KEY)) {
    throw new Error('Set OPENAI_API_KEY in server/.env.local, then restart. Do not paste the key into chat.');
  }
  const rawPort = String(values.PORT ?? '8080');
  if (!/^[0-9]+$/.test(rawPort) || Number(rawPort) < 1 || Number(rawPort) > 65535) {
    throw new Error('PORT must be between 1 and 65535.');
  }
  return { apiKey: values.OPENAI_API_KEY, port: Number(rawPort), host: '127.0.0.1' };
}
