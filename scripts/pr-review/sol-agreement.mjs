// SPDX-License-Identifier: MIT
// Shadow report before cutover (D352): for each PR, every head the shadow lane reviewed, its verdict and the verdict
// that counts there under the gate's tier rules (REVIEW_GLM_TIERS as set in the repo, default empty). Reads public data;
// GH_TOKEN is optional.
//   node scripts/pr-review/sol-agreement.mjs <pr> [<pr> ...]
import { client } from "../merge-gates/github.mjs";
import { feed, parseGlmTiers, pathTier, prPaths, tierOverride } from "../merge-gates/rules.mjs";
import { verdictLines } from "./brief.mjs";
import { agreement, GLM_SHADOW_LANE, SOL_SHADOW_LANE } from "./sol.mjs";

const gh = client({ token: process.env.GH_TOKEN, repo: process.env.GITHUB_REPOSITORY ?? "modelplan/modelplan" });
let agree = 0, disagree = 0, open = 0;
for (const arg of process.argv.slice(2)) {
  const n = Number(arg);
  const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
  const tier = tierOverride(items) ?? pathTier(prPaths(await gh.all(`/pulls/${n}/files`)));
  const shadows = verdictLines(items).filter((v) => v.lane === `(${SOL_SHADOW_LANE})` || v.lane === `(${GLM_SHADOW_LANE})`);
  if (!shadows.length) console.log(`#${n}: no shadow verdict`);
  for (const key of new Set(shadows.map((v) => `${v.sha} ${v.lane.slice(1, -1)}`))) {
    const [h, lane] = key.split(" ");
    const a = agreement(items, h, lane, tier, parseGlmTiers(process.env.REVIEW_GLM_TIERS));
    a.agree === null ? open++ : a.agree ? agree++ : disagree++;
    console.log(`#${n} tier ${tier} ${a.text}`);
  }
}
console.log(`total: ${agree} agree, ${disagree} disagree, ${open} without a lane verdict`);
