import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, mkdir, writeFile, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { readLocalConfig } from '../src/local-config.js';
import { setupLocalConfig } from '../scripts/setup-local.js';

const key='sk-test-not-a-real-key-for-local-configuration';
async function fixture(t) {
  const root=await mkdtemp(join(tmpdir(),'vview_local_config_'));
  t.after(()=>rm(root,{recursive:true,force:true}));
  const serverRoot=join(root,'server');
  await mkdir(serverRoot);
  await mkdir(join(root,'v_view'));
  return {root,serverRoot};
}
test('local setup migrates only the project API key, never other old settings',async t=>{
  const {root,serverRoot}=await fixture(t);
  await writeFile(join(root,'v_view','.env'),`OPENAI_API_KEY=${key}\nOTHER_PRIVATE_SETTING=not-copied\n`);
  const result=setupLocalConfig({serverRoot,env:{}});
  assert.equal(result.ready,true);
  assert.equal(JSON.stringify(result).includes(key),false);
  const saved=await readFile(join(serverRoot,'.env.local'),'utf8');
  assert.equal(saved.includes('OTHER_PRIVATE_SETTING'),false);
  assert.equal(readLocalConfig({serverRoot,env:{}}).apiKey,key);
});
test('existing local settings are never overwritten by migration',async t=>{
  const {root,serverRoot}=await fixture(t);
  const original='OPENAI_API_KEY=\nPORT=8099\n';
  await writeFile(join(serverRoot,'.env.local'),original);
  await writeFile(join(root,'v_view','.env'),`OPENAI_API_KEY=${key}`);
  assert.equal(setupLocalConfig({serverRoot,env:{}}).ready,false);
  assert.equal(await readFile(join(serverRoot,'.env.local'),'utf8'),original);
});
test('missing key prepares an editable local file without claiming authentication',async t=>{
  const {serverRoot}=await fixture(t);
  assert.equal(setupLocalConfig({serverRoot,env:{}}).ready,false);
  assert.throws(()=>readLocalConfig({serverRoot,env:{}}),/\.env.local/);
});
test('local startup ignores Firebase settings, rejects cloud context and invalid port',async t=>{
  const {serverRoot}=await fixture(t);
  const config=readLocalConfig({serverRoot,env:{OPENAI_API_KEY:key,PORT:'8081'}});
  assert.equal(config.host,'127.0.0.1');
  assert.equal(config.port,8081);
  assert.throws(()=>readLocalConfig({serverRoot,env:{OPENAI_API_KEY:key,K_SERVICE:'cloud-service'}}));
  for(const PORT of ['0','65536','bad','8080;echo']) {
    assert.throws(()=>readLocalConfig({serverRoot,env:{OPENAI_API_KEY:key,PORT}}));
  }
});
