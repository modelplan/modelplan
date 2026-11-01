// SPDX-License-Identifier: MIT
// Exact, self-contained vendor marks. Their trademark rights remain external.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync,lstatSync} from 'node:fs';
import {resolve} from 'node:path';
const sha=b=>createHash('sha256').update(b).digest('hex');
export function verifyVendorSvg(root){
 const dir=resolve(root,'desktop/third-party/vendor-marks');
 for(const part of ['desktop','desktop/third-party','desktop/third-party/vendor-marks'])assert.ok(!lstatSync(resolve(root,part)).isSymbolicLink(),'symlink in vendor mark path');
 const raw=readFileSync(resolve(dir,'svg-manifest.json')),policy=JSON.parse(readFileSync(resolve(root,'source-policy.json')));
 assert.equal(sha(raw),policy.thirdPartyVendorSvgManifestSha256,'vendor SVG manifest hash');
 const manifest=JSON.parse(raw);assert.equal(manifest.schemaVersion,1);assert.match(manifest.notice,/trademarks remain/i);
 const expected=['claude.svg','copilot.svg','cursor.svg','kimi.svg','openai.svg','opencode.svg','zai-white.svg'];
 assert.deepEqual(Object.keys(manifest.files).sort(),expected,'vendor SVG paths');
 for(const name of expected){const file=resolve(dir,name);assert.ok(lstatSync(file).isFile()&&!lstatSync(file).isSymbolicLink(),'vendor SVG file');const data=readFileSync(file);assert.equal(sha(data),manifest.files[name],'vendor SVG hash');const svg=data.toString('utf8');assert.ok(Buffer.from(svg).equals(data)&&/^\s*(?:<\?xml[^?]*\?>\s*)?<svg\b/i.test(svg),'vendor SVG format');assert.doesNotMatch(svg,/<(?:script|foreignObject|image|iframe)\b|<!DOCTYPE|<!ENTITY|\b(?:href|on[a-z]+)\s*=|@import/i,'active vendor SVG');for(const match of svg.matchAll(/url\(\s*(['"]?)([^)'"\s]+)\1\s*\)/gi))assert.ok(match[2].startsWith('#'),'external vendor SVG URL');}
 return manifest;
}
