// SPDX-License-Identifier: MIT
export function selectBuildEdition(args) {
 if(args.length===0)return 'community';
 if(args.length===1&&args[0]==='--official')return 'official';
 if(args.length===1&&args[0]==='--internal-acceptance')throw Error('internal-acceptance unavailable: reviewed helper, pins and resource mapping are not integrated');
 throw Error('Usage: node build.mjs [--official]');
}
