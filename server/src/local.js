import { createServer } from 'node:http';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createLocalHandler } from './app.js';
import { readLocalConfig } from './local-config.js';

export async function startLocalServer({ apiKey, port = 8080, fetchImpl = fetch }) {
  const server = createServer(createLocalHandler({ apiKey, fetchImpl }));
  server.headersTimeout = 10000;
  server.requestTimeout = 15000;
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', resolve);
  });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const config = readLocalConfig();
    const server = await startLocalServer(config);
    console.log(`v-view local AI: http://127.0.0.1:${server.address().port} (keep this process running)`);
    console.log('GPT requests use the PC API key. Firebase and cloud deployment are not used.');
    process.on('SIGTERM', () => server.close());
    process.on('SIGINT', () => server.close());
  } catch (error) {
    console.error(error?.code === 'EADDRINUSE'
      ? 'The local port is already in use. Check the existing process or change PORT in server/.env.local.'
      : 'Local AI could not start. Check the API key and PORT in server/.env.local.');
    process.exitCode = 1;
  }
}
