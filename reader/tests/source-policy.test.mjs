import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdir,writeFile,unlink,rmdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
function check(){return execFileSync(process.execPath,['scripts/check-source-policy.mjs'],{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']})}
test('the real public policy gate rejects private source, official assets and owner paths in verification/tools',async()=>{
 assert.match(check(),/verified/);
 const cases=[['server/','__source_policy_probe__.txt'],['core/','__scoring_probe__.mjs'],['codex/ui/kit/','__source_policy_probe__.svg']];
 for(const directory of ['desktop/native/verification/','tools/'])
  for(const literal of ['/mnt/private/ledger','/home/private/ledger'])
   cases.push([directory,'__owner_path_probe__.txt',literal]);
 for(const [directory,name,content='Synthetic policy probe; not production data.'] of cases){
  const dir=new URL(directory,'file://'+root),file=new URL(name,dir);
  let created=false;
  try{await mkdir(dir);created=true}catch(e){if(e.code!=='EEXIST')throw e}
  try{
   await writeFile(file,content,{flag:'wx'});
   assert.throws(check,error=>{
    if(content.startsWith('/'))assert.match(String(error.stderr),/verification\/tools must use configured paths/);
    else assert.match(error.message,/Command failed/);
    return true;
   });
  }
  finally{await unlink(file);if(created)await rmdir(dir)}
 }
 assert.match(check(),/verified/);
});
