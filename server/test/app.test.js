import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createHandler } from '../src/app.js';

const payload = { messages: [{ role: 'system', content: 'JSON only' }, { role: 'user', content: 'question' }] };
const completion = { choices: [{ message: { content: '[{"id":"q1","text":"질문","intent":"경험"}]' } }] };

async function fixture(t, options = {}) {
  const calls = [];
  const handler = createHandler({
    apiKey: 'server-only-test-key', allowedUids: ['user1'],
    verifyToken: async token => {
      if (token === 'valid') return { uid: 'user1' };
      if (token === 'other') return { uid: 'user2' };
      throw new Error('sensitive verifier details');
    },
    fetchImpl: async (url, init) => {
      calls.push({ url, init });
      return Response.json(completion);
    },
    ...options,
  });
  const server = createServer(handler);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  const url = `http://127.0.0.1:${server.address().port}`;
  return { calls, request: (body = payload, token = 'valid', path = '/v1/chat/completions') => fetch(url + path, {
    method: 'POST', headers: { 'content-type': 'application/json', ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  }) };
}

test('missing or invalid Firebase token never calls OpenAI', async t => {
  const f = await fixture(t);
  assert.equal((await f.request(payload, '')).status, 401);
  const invalid = await f.request(payload, 'invalid');
  assert.equal(invalid.status, 401);
  assert.equal((await invalid.text()).includes('sensitive'), false);
  assert.equal(f.calls.length, 0);
});

test('valid user outside pilot allowlist is denied', async t => {
  const f = await fixture(t);
  assert.equal((await f.request(payload, 'other')).status, 403);
  assert.equal(f.calls.length, 0);
});

test('only server selects model, output limit and upstream authorization', async t => {
  const f = await fixture(t);
  const response = await f.request({ ...payload, model: 'expensive-client-model', max_tokens: 999999, stream: true });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), completion);
  assert.equal(f.calls[0].url, 'https://api.openai.com/v1/chat/completions');
  assert.equal(f.calls[0].init.headers.authorization, 'Bearer server-only-test-key');
  const body = JSON.parse(f.calls[0].init.body);
  assert.equal(body.model, 'gpt-4o-mini');
  assert.equal(body.max_completion_tokens, 2000);
  assert.equal(body.stream, undefined);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('bad JSON, wrong role and excessive content are rejected before upstream', async t => {
  const f = await fixture(t);
  for (const body of ['{bad', { messages: [] }, { messages: [{ role: 'tool', content: 'x' }] },
    { messages: [{ role: 'user', content: 'x'.repeat(20001) }] }]) {
    assert.equal((await f.request(body)).status, 400);
  }
  assert.equal(f.calls.length, 0);
});

test('oversized body is refused', async t => {
  const f = await fixture(t);
  assert.equal((await f.request('x'.repeat(65537))).status, 413);
  assert.equal(f.calls.length, 0);
});

test('per-user limit denies excess requests and resets after window', async t => {
  let time = 0;
  const f = await fixture(t, { requestsPerHour: 2, now: () => time });
  assert.equal((await f.request()).status, 200);
  assert.equal((await f.request()).status, 200);
  const denied = await f.request();
  assert.equal(denied.status, 429);
  assert.equal(denied.headers.get('retry-after'), '3600');
  time = 3600001;
  assert.equal((await f.request()).status, 200);
});

test('parallel calls from a single user are bounded', async t => {
  let release;
  let started;
  const ready = new Promise(resolve => { started = resolve; });
  const waiting = new Promise(resolve => { release = resolve; });
  const f = await fixture(t, { concurrentPerUser: 1, fetchImpl: async () => {
    started(); await waiting; return Response.json(completion);
  } });
  const first = f.request();
  await ready;
  try { assert.equal((await f.request()).status, 429); }
  finally { release(); }
  assert.equal((await first).status, 200);
});

test('upstream secrets and response errors are not returned to app', async t => {
  const f = await fixture(t, { fetchImpl: async () => Response.json({ secret: 'private upstream' }, { status: 401 }) });
  const response = await f.request();
  assert.equal(response.status, 502);
  assert.equal((await response.text()).includes('private'), false);
});

test('upstream throttling remains retryable', async t => {
  const f = await fixture(t, { fetchImpl: async () => new Response('', { status: 429 }) });
  assert.equal((await f.request()).status, 429);
});

test('timeout returns bounded failure without retrying paid request', async t => {
  let count = 0;
  const f = await fixture(t, { timeoutMs: 10, fetchImpl: async (_, { signal }) => {
    count++;
    await new Promise((_, reject) => signal.addEventListener('abort', () => reject(signal.reason), { once: true }));
  } });
  assert.equal((await f.request()).status, 504);
  assert.equal(count, 1);
});

test('malformed upstream completion is refused', async t => {
  const f = await fixture(t, { fetchImpl: async () => Response.json({ choices: [] }) });
  assert.equal((await f.request()).status, 502);
});

test('missing server configuration fails closed', () => {
  assert.throws(() => createHandler({ apiKey: '', allowedUids: ['u'], verifyToken: async () => ({uid:'u'}) }));
  assert.throws(() => createHandler({ apiKey: 'key', allowedUids: [], verifyToken: async () => ({uid:'u'}) }));
});
