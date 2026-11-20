// SPDX-License-Identifier: MIT
// pr-review-sol.yml job "resolve": which PR and head this event is about. A ci workflow_run carries the PR number; a
// mac-compile status names only a commit, so the open trusted PR whose head it is is looked up; a dispatch names the
// PR. Outputs pr (empty = nothing to review) and sha (the head the trigger was for; empty for a dispatch).
import { appendFileSync } from "node:fs";
import { client } from "../merge-gates/github.mjs";
import { prForSha } from "./sol.mjs";

const env = process.env;
const out = (pr, sha, why) => {
  appendFileSync(env.GITHUB_OUTPUT, `pr=${pr}\nsha=${sha}\n`);
  console.log(`pr-review-sol: ${pr ? `PR #${pr}${sha ? ` @ ${sha}` : ""}` : "nothing to review"}${why ? ` (${why})` : ""}`);
};
const sha = String(env.TRIGGER_SHA ?? "").toLowerCase();
if (env.EVENT === "status") {
  if (!/^[0-9a-f]{40}$/.test(sha)) out("", "", "status without a sha");
  else {
    const gh = client({ token: env.GITHUB_TOKEN, repo: env.GITHUB_REPOSITORY });
    const n = prForSha(await gh.get(`/commits/${sha}/pulls`), sha, env.GITHUB_REPOSITORY);
    out(n ?? "", n ? sha : "", n ? "" : "no single open trusted PR has this head");
  }
} else {
  const n = String(env.PR_INPUT ?? "");
  if (!/^[1-9][0-9]*$/.test(n)) out("", "", `bad PR number '${n}'`);
  else out(n, /^[0-9a-f]{40}$/.test(sha) ? sha : "");
}
