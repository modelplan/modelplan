import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdir,writeFile,unlink,rmdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
function check(){return execFileSync(process.execPath,['scripts/check-source-policy.mjs'],{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']})}
test('the real public policy gate rejects a private source path and an unreviewed official asset',async()=>{
 assert.match(check(),/verified/);
 const cases=[['server/','__source_policy_probe__.txt'],['codex/ui/kit/','__source_policy_probe__.svg']];
 for(const [directory,name] of cases){
  const dir=new URL(directory,'file://'+root),file=new URL(name,dir);
  let created=false;
  try{await mkdir(dir);created=true}catch(e){if(e.code!=='EEXIST')throw e}
  try{await writeFile(file,'Synthetic policy probe; not production data.',{flag:'wx'});assert.throws(check,/Command failed/)}
  finally{await unlink(file);if(created)await rmdir(dir)}
 }
 assert.match(check(),/verified/);
});
