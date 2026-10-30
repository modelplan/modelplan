// SPDX-License-Identifier: MIT
// Derive the web DTOs and the validator's reachable schema from the Go wire schema.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
const source = await readFile(new URL('../../schema/app-cli/app-server.json', import.meta.url));
const schema = JSON.parse(source), found = new Set();
const allowed = new Set(['$ref','type','properties','additionalProperties','required','items','enum','anyOf','format','pattern','minimum','maximum','minItems','maxItems','uniqueItems','minLength','maxLength']);
function visit(node) {
  for (const key of Object.keys(node)) if (!allowed.has(key)) throw Error('Unmodeled wire-schema keyword: '+key);
  if (node.$ref) {
    const name = node.$ref.replace('#/$defs/', '');
    if (!schema.$defs[name] || node.$ref !== '#/$defs/'+name) throw Error('Non-local schema reference');
    if (!found.has(name)) { found.add(name); visit(schema.$defs[name]); }
  }
  for (const value of Object.values(node.properties ?? {})) visit(value);
  if (node.items) visit(node.items);
  for (const value of node.anyOf ?? []) visit(value);
}
visit({$ref:'#/$defs/CockpitData'});
function type(node) {
  if (node.$ref) return 'Wire'+node.$ref.replace('#/$defs/','');
  if (node.anyOf) return node.anyOf.map(type).join(' | ');
  if (node.enum) return node.enum.map(JSON.stringify).join(' | ');
  if (node.type==='array') return `ReadonlyArray<${type(node.items)}>`;
  if (node.type==='object') return '{\n'+Object.entries(node.properties ?? {}).map(([key,value]) => `  readonly ${JSON.stringify(key)}${node.required?.includes(key)?'':'?'}: ${type(value)};`).join('\n')+'\n}';
  return ({integer:'number',number:'number',boolean:'boolean',string:'string',null:'null'})[node.type] ?? (()=>{throw Error('Unmodeled wire type');})();
}
const names=[...found].sort();
let output='// SPDX-License-Identifier: MIT\n// Generated from schema/app-cli/app-server.json (Go wire DTOs). DO NOT EDIT.\n';
output+=`// Schema SHA-256: ${createHash('sha256').update(source).digest('hex')}\n`;
output+="import type { Schema } from '../src/schema.js';\n\n";
output+=names.map(name=>`export type Wire${name} = ${type(schema.$defs[name])};`).join('\n\n');
output+='\n\nexport const definitions: Readonly<Record<string, Schema>> = '+JSON.stringify(Object.fromEntries(names.map(name=>[name,schema.$defs[name]])),null,2)+';\n';
const destination=new URL('./generated/wire.ts',import.meta.url);
if (process.argv.includes('--check')) {
  if (await readFile(destination,'utf8')!==output) throw Error('Web wire drift: npm run generate');
} else { await mkdir(new URL('./generated/',import.meta.url),{recursive:true}); await writeFile(destination,output); }
