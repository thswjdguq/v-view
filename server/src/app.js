const HOUR = 3600000;
const MAX_BODY = 65536;

class HttpError extends Error {
  constructor(status, code = 'request_failed') { super('Request failed'); this.status = status; this.code = code; }
}

function send(res, status, body, headers = {}) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store', 'x-content-type-options': 'nosniff', ...headers,
  });
  res.end(JSON.stringify(body));
}

async function readBody(req) {
  if (Number(req.headers['content-length']) > MAX_BODY) {
    req.resume(); throw new HttpError(413);
  }
  const bytes = await new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    let oversized = false;
    req.on('data', chunk => {
      size += chunk.length;
      if (size > MAX_BODY) {
        if (!oversized) { oversized = true; reject(new HttpError(413)); }
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => { if (!oversized) resolve(Buffer.concat(chunks)); });
    req.on('error', () => reject(new HttpError(400)));
  });
  try { return JSON.parse(bytes.toString('utf8')); }
  catch { throw new HttpError(400); }
}

function messagesFrom(body) {
  const messages = body?.messages;
  if (!Array.isArray(messages) || messages.length < 1 || messages.length > 4) throw new HttpError(400);
  let length = 0;
  const result = messages.map(message => {
    if (!['system', 'user'].includes(message?.role) || typeof message?.content !== 'string' || !message.content.trim()) {
      throw new HttpError(400);
    }
    length += message.content.length;
    return { role: message.role, content: message.content };
  });
  if (length > 20000) throw new HttpError(400);
  return result;
}

export function createHandler({ apiKey, verifyToken, allowedUids, ...options }) {
  if (!apiKey || typeof verifyToken !== 'function' || !Array.isArray(allowedUids) || !allowedUids.length) {
    throw new Error('Server API key, Firebase verifier and pilot user allowlist are required');
  }
  const allowed = new Set(allowedUids);
  return createCompletionHandler({ apiKey, ...options, authorizeRequest: async req => {
    const token = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '')?.[1];
    if (!token || token.length > 8192) throw new HttpError(401);
    let user;
    try { user = await verifyToken(token); }
    catch { throw new HttpError(401); }
    if (!allowed.has(user?.uid)) throw new HttpError(403);
    return user.uid;
  } });
}

// Separate native-only local entry point. The deployed entry point never uses it.
export function createLocalHandler({ apiKey, ...options }) {
  const handler = createCompletionHandler({ apiKey, ...options,
    local: true, authorizeRequest: async () => 'local-pc' });
  return (req, res) => {
    const peer = req.socket?.remoteAddress;
    const localPeer = ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(peer);
    const localHost = /^(?:localhost|127\.0\.0\.1|10\.0\.2\.2|\[::1\])(?::[0-9]{1,5})?$/.test(req.headers.host ?? '');
    if (!localPeer || !localHost || req.headers.origin !== undefined ||
        (req.headers['sec-fetch-site'] && req.headers['sec-fetch-site'] !== 'none')) {
      return send(res, 403, { error: 'local_only' });
    }
    if (req.method === 'GET' && req.url === '/health') {
      return send(res, 200, { status: 'ok', service: 'v-view-local-ai' });
    }
    return handler(req, res);
  };
}

function createCompletionHandler({ apiKey, authorizeRequest, fetchImpl = fetch,
  requestsPerHour = 30, concurrentPerUser = 2, timeoutMs = 25000, now = Date.now, local = false }) {
  if (!apiKey || typeof authorizeRequest !== 'function') throw new Error('API key and authorization are required');
  if (![requestsPerHour, concurrentPerUser, timeoutMs].every(value => Number.isSafeInteger(value) && value > 0)) {
    throw new Error('Limits must be positive integers');
  }
  // Only allowlisted users create entries. Limits are per process, not a distributed quota.
  const usage = new Map();
  return async (req, res) => {
    if (req.method === 'GET' && req.url === '/health') return send(res, 200, { status: 'ok' });
    if (req.method !== 'POST' || req.url !== '/v1/chat/completions') return send(res, 404, { error: 'not_found' });
    let active;
    try {
      const uid = await authorizeRequest(req);
      const time = now();
      let entry = usage.get(uid);
      if (!entry) { entry = { count: 0, start: time, active: 0 }; usage.set(uid, entry); }
      if (time - entry.start >= HOUR) { entry.count = 0; entry.start = time; }
      if (entry.count >= requestsPerHour || entry.active >= concurrentPerUser) {
        const retry = entry.count >= requestsPerHour ? Math.max(1, Math.ceil((HOUR - (time - entry.start)) / 1000)) : 1;
        req.resume();
        return send(res, 429, { error: 'rate_limited' }, { 'retry-after': String(retry) });
      }
      entry.active++;
      active = entry;
      if (!(req.headers['content-type'] ?? '').startsWith('application/json')) throw new HttpError(415);
      const messages = messagesFrom(await readBody(req));
      entry.count++;
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await fetchImpl('https://api.openai.com/v1/chat/completions', {
          method: 'POST', signal: controller.signal,
          headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
          body: JSON.stringify({ model: 'gpt-4o-mini', messages, max_completion_tokens: 2000 }),
        });
        if (!response.ok) {
          if (local && [401, 403].includes(response.status)) throw new HttpError(503, 'api_key_invalid');
          throw new HttpError(response.status === 429 ? 429 : 502);
        }
        const data = await response.json();
        const content = data?.choices?.[0]?.message?.content;
        if (typeof content !== 'string' || !content.trim() || content.length > MAX_BODY) throw new HttpError(502);
        // Do not return provider metadata, internal diagnostics or prompts.
        return send(res, 200, { choices: [{ message: { content } }] });
      } catch (error) {
        if (controller.signal.aborted) throw new HttpError(504);
        throw error instanceof HttpError ? error : new HttpError(502);
      } finally { clearTimeout(timer); }
    } catch (error) {
      req.resume();
      return send(res, error instanceof HttpError ? error.status : 500,
        { error: error instanceof HttpError ? error.code : 'request_failed' });
    } finally { if (active) active.active--; }
  };
}
