// SPDX-License-Identifier: MIT
import test from 'node:test';
import assert from 'node:assert/strict';
import {cpSync,mkdtempSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {verifyVendorSvg} from '../../../../scripts/check-vendor-svg.mjs';
const source=fileURLToPath(new URL('../../../..',import.meta.url));
const hash=b=>createHash('sha256').update(b).digest('hex');
test('vendor marks reject tampering and active SVG even with a repinned manifest',()=>{
 const root=mkdtempSync(join(tmpdir(),'cockpit-vendor-svg-'));
 try{
  const dir=join(root,'desktop/third-party/vendor-marks');cpSync(join(source,'desktop/third-party/vendor-marks'),dir,{recursive:true});cpSync(join(source,'source-policy.json'),join(root,'source-policy.json'));
  assert.doesNotThrow(()=>verifyVendorSvg(root));
  const mark=join(dir,'openai.svg'),bytes=readFileSync(mark);writeFileSync(mark,Buffer.concat([bytes,Buffer.from(' ')]));assert.throws(()=>verifyVendorSvg(root),/hash/);
  const injected=Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>1</script></svg>');writeFileSync(mark,injected);
  const manifestFile=join(dir,'svg-manifest.json'),manifest=JSON.parse(readFileSync(manifestFile));manifest.files['openai.svg']=hash(injected);writeFileSync(manifestFile,JSON.stringify(manifest));
  const policyFile=join(root,'source-policy.json'),policy=JSON.parse(readFileSync(policyFile));policy.thirdPartyVendorSvgManifestSha256=hash(readFileSync(manifestFile));writeFileSync(policyFile,JSON.stringify(policy));
  assert.throws(()=>verifyVendorSvg(root),/active vendor SVG/);
 }finally{rmSync(root,{recursive:true,force:true});}
});
