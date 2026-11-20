// SPDX-License-Identifier: MIT
// Shadow report before cutover (D352): for each PR, every head the shadow lane reviewed, its verdict and the verdict
// that counts there (sticky reviewer, else the counting GPT lanes). Reads public data; GH_TOKEN is optional.
//   node scripts/pr-review/sol-agreement.mjs <pr> [<pr> ...]
import { client } from "../merge-gates/github.mjs";
import { feed } from "../merge-gates/rules.mjs";
import { verdictLines } from "./brief.mjs";
import { agreement, SOL_SHADOW_LANE } from "./sol.mjs";

const gh = client({ token: process.env.GH_TOKEN, repo: process.env.GITHUB_REPOSITORY ?? "modelplan/modelplan" });
let agree = 0, disagree = 0, open = 0;
for (const arg of process.argv.slice(2)) {
  const n = Number(arg);
  const items = feed(await gh.all(`/issues/${n}/comments`), await gh.all(`/pulls/${n}/reviews`));
  const heads = [...new Set(verdictLines(items).filter((v) => v.lane === `(${SOL_SHADOW_LANE})`).map((v) => v.sha))];
  if (!heads.length) console.log(`#${n}: no shadow verdict`);
  for (const h of heads) {
    const a = agreement(items, h);
    a.agree === null ? open++ : a.agree ? agree++ : disagree++;
    console.log(`#${n} ${a.text}`);
  }
}
console.log(`total: ${agree} agree, ${disagree} disagree, ${open} without a lane verdict`);
