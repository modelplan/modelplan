// SPDX-License-Identifier: MIT
export interface Schema {
  readonly $ref?: string;
  readonly type?: string;
  readonly properties?: Readonly<Record<string, Schema>>;
  readonly additionalProperties?: boolean;
  readonly required?: readonly string[];
  readonly items?: Schema;
  readonly enum?: readonly unknown[];
  readonly anyOf?: readonly Schema[];
  readonly format?: string;
  readonly pattern?: string;
  readonly minimum?: number;
  readonly maximum?: number;
  readonly minItems?: number;
  readonly maxItems?: number;
  readonly uniqueItems?: boolean;
  readonly minLength?: number;
  readonly maxLength?: number;
}
export function record(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
export function exact(value: unknown, required: readonly string[]): value is Record<string, unknown> {
  return record(value) && Object.keys(value).length === required.length && required.every(key=>Object.hasOwn(value,key));
}
function timestamp(value:string):boolean {
  const m=/^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?(?:Z|([+-])(\d\d):(\d\d))$/.exec(value);
  if(!m)return false;
  const [year,month,day,hour,minute,second]=m.slice(1,7).map(Number);
  const leap=year%4===0&&(year%100!==0||year%400===0);
  const days=[31,leap?29:28,31,30,31,30,31,31,30,31,30,31];
  return month>=1&&month<=12&&day>=1&&day<=days[month-1]&&hour<24&&minute<60&&second<60&&
    (!m[7]||(Number(m[8])<24&&Number(m[9])<60));
}
// Bounded schema interpreter: no eval/Function, remote refs, coercion or defaults.
export function conforms(value: unknown, schema: Schema, definitions: Readonly<Record<string,Schema>>, depth=0): boolean {
  if (depth>48) return false;
  if (schema.$ref) {
    const reference=definitions[schema.$ref.replace('#/$defs/','')];
    return !!reference && conforms(value,reference,definitions,depth+1);
  }
  if (schema.anyOf) return schema.anyOf.some(choice=>conforms(value,choice,definitions,depth+1));
  if (schema.enum && !schema.enum.includes(value)) return false;
  switch (schema.type) {
    case 'null': return value===null;
    case 'boolean': return typeof value==='boolean';
    case 'number': case 'integer':
      return typeof value==='number' && Number.isFinite(value) && (schema.type!=='integer'||Number.isSafeInteger(value)) &&
        (schema.minimum===undefined||value>=schema.minimum) && (schema.maximum===undefined||value<=schema.maximum);
    case 'string':
      return typeof value==='string' && value.length<=65536 &&
        (schema.minLength===undefined||[...value].length>=schema.minLength) && (schema.maxLength===undefined||[...value].length<=schema.maxLength) &&
        (!schema.pattern||new RegExp(schema.pattern).test(value)) &&
        (!schema.format || (schema.format==='date-time' && timestamp(value)));
    case 'array':
      return Array.isArray(value) && value.length<=1024 && (schema.minItems===undefined||value.length>=schema.minItems) &&
        (schema.maxItems===undefined||value.length<=schema.maxItems) && (!schema.uniqueItems||new Set(value.map(v=>JSON.stringify(v))).size===value.length) &&
        !!schema.items && value.every(item=>conforms(item,schema.items!,definitions,depth+1));
    case 'object':
      return record(value) && Object.keys(value).length<=64 && (schema.required??[]).every(key=>Object.hasOwn(value,key)) &&
        Object.entries(value).every(([key,item])=>schema.properties?.[key] ? conforms(item,schema.properties[key],definitions,depth+1) : schema.additionalProperties!==false);
    default: return false;
  }
}
// JSON.parse alone silently accepts duplicate keys. Scan structure before parsing,
// with depth/node limits, then let JSON.parse validate numbers, escapes and syntax.
export function parseMessage(raw: string): unknown {
  let i=0,nodes=0;
  const white=()=>{while (/\s/.test(raw[i]??'')&&i<raw.length) i++;};
  function string(): string {
    const start=i++;
    while (i<raw.length) {
      const ch=raw[i++];
      if (ch==='\\') { i++; continue; }
      if (ch==='"') return JSON.parse(raw.slice(start,i));
    }
    throw Error('json');
  }
  function value(depth: number): void {
    if (++nodes>50000||depth>48) throw Error('json');
    white();
    if (raw[i]==='"') { string(); return; }
    if (raw[i]==='{') {
      i++; white(); const seen=new Set<string>();
      if (raw[i]==='}') {i++;return;}
      for (;;) {
        white(); if (raw[i]!== '"') throw Error('json');
        const key=string(); if (seen.has(key)||['__proto__','constructor','prototype'].includes(key)) throw Error('json'); seen.add(key);
        white(); if (raw[i++]!==':') throw Error('json'); value(depth+1); white();
        const end=raw[i++]; if (end==='}') return; if (end!==',') throw Error('json');
      }
    }
    if (raw[i]==='[') {
      i++; white(); if (raw[i]===']') {i++;return;}
      for (;;) { value(depth+1); white(); const end=raw[i++]; if(end===']') return; if(end!==',') throw Error('json'); }
    }
    const start=i; while(i<raw.length&&!/[\s,\]}]/.test(raw[i])) i++;
    if (start===i) throw Error('json'); JSON.parse(raw.slice(start,i));
  }
  value(0); white(); if(i!==raw.length) throw Error('json');
  return JSON.parse(raw);
}
