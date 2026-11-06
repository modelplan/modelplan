// SPDX-License-Identifier: MIT
// THROWAWAY SPIKE: synthetic host messages (load, visibility, display) for the porthole measurement harness.
import {writeFileSync} from 'node:fs';
import {appearance,commands,sample,shell} from '../../tests/cockpit/fixture.mjs';
const send=commands(),reduceMotion=process.argv[3]==='reduced';
writeFileSync(process.argv[2],JSON.stringify([
  send('load',{appearance:{...appearance,reduceMotion},shell}),
  send('visibility',{visible:true,occluded:false,key:true}),
  send('display',{data:sample()}),
]));
