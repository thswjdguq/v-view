import { createServer } from 'node:http';
import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { createHandler } from './app.js';

// Production never accepts unsigned tokens or an authentication bypass flag.
if (process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Auth emulator is not allowed in the pilot server');
initializeApp({ credential: applicationDefault(), projectId: process.env.GOOGLE_CLOUD_PROJECT });
const handler = createHandler({
  apiKey: process.env.OPENAI_API_KEY,
  allowedUids: (process.env.ALLOWED_FIREBASE_UIDS ?? '').split(',').map(value => value.trim()).filter(Boolean),
  verifyToken: token => getAuth().verifyIdToken(token, true),
});
const server = createServer(handler);
server.headersTimeout = 10000;
server.requestTimeout = 15000;
server.listen(Number(process.env.PORT ?? 8080), '0.0.0.0', () => {
  console.log('v-view pilot proxy listening');
});
process.on('SIGTERM', () => server.close());
