// SPDX-License-Identifier: MIT
// Which subscription a reported session belongs to, and each subscription's identity colour and mark: one place, so
// the faders, the record strip, the MFD lists and the HUD agree (owner build 13: Codex sessions matched nothing).
// A producer-verified subscriptionRef wins. Without one, a session joins the single subscription of its tool when
// there is exactly one; with two or more of the same tool it stays unbound, because nothing says which account ran it.
import type {WireCockpitData} from '../generated/wire.js';
import {cockpitMembers} from './members.js';

type Session=NonNullable<WireCockpitData['details']>['sessions'][number];
type Member=ReturnType<typeof cockpitMembers>[number];

// A session's harness (the producer's source) to the tool row that reads its quota.
const sessionTools:Readonly<Record<string,string>>={codex:'codex','claude-code':'claude',claude:'claude',zcode:'zai',zai:'zai',glm:'zai',opencode:'opencodego',opencodego:'opencodego',gemini:'gemini',grok:'grok',kimi:'kimi',qwen:'qwen',cursor:'cursor',copilot:'copilot'};
export const sessionTool=(source:string)=>sessionTools[source.toLowerCase()]??null;
// A subscription's tool to the developer of the models it runs (the CLI's eligibleCockpitVendors).
export const toolDevelopers:Readonly<Record<string,string>>={codex:'openai',claude:'anthropic',gemini:'google',grok:'xai',kimi:'kimi',zai:'zhipuai',minimax:'minimax',qwen:'alibaba'};
// Identity colour and allowlisted mark per vendor key (the engine bar's palette).
export const vendorPalette:Readonly<Record<string,{colour:string;logo:string}>>={openai:{colour:'#6aa8ff',logo:'openai'},claude:{colour:'#ff9a6a',logo:'claude'},cursor:{colour:'#eef2f6',logo:'cursor'},copilot:{colour:'#c08cff',logo:'copilot'},kimi:{colour:'#ff8fcf',logo:'kimi'},glm:{colour:'#8f7dff',logo:'zai-white'},opencode:{colour:'#b5d65a',logo:'opencode'}};
export const NEUTRAL='#c6ccd4';
export const memberColour=(m:{readonly row:{readonly vendorKey:string|null}}|null|undefined)=>m?.row.vendorKey&&Object.hasOwn(vendorPalette,m.row.vendorKey)?vendorPalette[m.row.vendorKey]!.colour:NEUTRAL;

/** The member a session belongs to, or null when that cannot be said. */
export function sessionMember(members:readonly Member[],session:Pick<Session,'source'|'subscriptionRef'>):Member|null {
 if(session.subscriptionRef){const exact=members.find(m=>m.key===session.subscriptionRef);if(exact)return exact;}
 const tool=sessionTool(session.source);if(!tool)return null;
 const same=members.filter(m=>m.row.id===tool);
 return same.length===1?same[0]!:null;
}
/** Every session's member key (null when unbound), for one render. */
export function sessionMembers(data:WireCockpitData|null|undefined):Map<string,string|null> {
 const out=new Map<string,string|null>();if(!data?.details)return out;
 const members=cockpitMembers(data);
 for(const s of data.details.sessions)out.set(s.sessionRef,sessionMember(members,s)?.key??null);
 return out;
}
