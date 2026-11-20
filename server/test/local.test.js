import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, request } from 'node:http';
import { createLocalHandler } from '../src/app.js';

const body = { messages: [{role:'user', content:'가상 면접 질문을 JSON으로 생성해 주세요.'}] };
async function fixture(t, options = {}) {
  const calls = [];
  const handler = createLocalHandler({
    apiKey:'local-test-api-key',
    fetchImpl:async (url, init) => { calls.push({url,init}); return Response.json({choices:[{message:{content:'[]'}}]}); },
    ...options,
  });
  const server = createServer(handler);
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  t.after(() => new Promise(resolve => {server.close(resolve);server.closeAllConnections();}));
  const url = `http://127.0.0.1:${server.address().port}`;
  return {calls, request:(headers = {}, path='/v1/chat/completions') => new Promise((resolve,reject) => {
    const outgoing=request(url+path, {
      method:path === '/health' ? 'GET' : 'POST',
      headers:{'content-type':'application/json',...headers},
    }, incoming => {
      const chunks=[];
      incoming.on('data',chunk=>chunks.push(chunk));
      incoming.on('end',()=>resolve(new Response(Buffer.concat(chunks),{status:incoming.statusCode,headers:incoming.headers})));
    });
    outgoing.on('error',reject);
    outgoing.end(path === '/health' ? undefined : JSON.stringify(body));
  })};
}

test('local native requests use the PC API key without Firebase credentials', async t => {
  const f = await fixture(t);
  assert.equal((await f.request()).status,200);
  assert.equal(f.calls.length,1);
  assert.equal(f.calls[0].url,'https://api.openai.com/v1/chat/completions');
  assert.equal(f.calls[0].init.headers.authorization,'Bearer local-test-api-key');
  assert.equal(JSON.parse(f.calls[0].init.body).model,'gpt-4o-mini');
});
test('local health identifies the service without claiming OpenAI authentication succeeded', async t => {
  const f = await fixture(t);
  const response = await f.request({},'/health');
  assert.deepEqual(await response.json(),{status:'ok',service:'v-view-local-ai'});
  assert.equal(f.calls.length,0);
});
test('browser origins and untrusted Host headers cannot make paid local requests', async t => {
  const f = await fixture(t);
  for (const headers of [{origin:'https://untrusted.example'},{origin:'null'},
    {host:'untrusted.example:8080'},{'sec-fetch-site':'cross-site'}]) {
    assert.equal((await f.request(headers)).status,403,JSON.stringify(headers));
  }
  assert.equal(f.calls.length,0);
});
test('non-loopback peers are rejected even with a local Host header', async () => {
  let calls=0;
  const handler=createLocalHandler({apiKey:'local-test-api-key',fetchImpl:async()=>{calls++;}});
  let status;
  const response={writeHead:code=>{status=code;},end:()=>{}};
  await handler({method:'POST',url:'/v1/chat/completions',headers:{host:'localhost:8080'},socket:{remoteAddress:'192.168.1.8'}},response);
  assert.equal(status,403);
  assert.equal(calls,0);
});
test('local errors identify a rejected API key without returning upstream details', async t => {
  const f=await fixture(t,{fetchImpl:async()=>Response.json({error:{message:'private provider details'}},{status:401})});
  const response=await f.request();
  assert.equal(response.status,503);
  assert.deepEqual(await response.json(),{error:'api_key_invalid'});
});
test('local requests share the existing process limit',async t=>{
  const f=await fixture(t,{requestsPerHour:1});
  assert.equal((await f.request()).status,200);
  assert.equal((await f.request()).status,429);
  assert.equal(f.calls.length,1);
});
