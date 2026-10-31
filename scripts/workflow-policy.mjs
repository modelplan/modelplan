// SPDX-License-Identifier: MIT
// Runner and trigger rules for public workflows. Defence in depth only: the enforced boundaries
// are the dedicated Mac's owner-only pre-job gate and the private runners' private-repo registration.
//
// Design: an allow-list, not a pattern search. Any line mentioning `self-hosted` or
// `pull_request_target` must be exactly one of the two canonical routing lines below; anything
// else (other triggers, branch filters, `|| true`, comments, composed selectors) fails.
const GUARD = "vars.MAC_CI_RUNNER == 'self-hosted' && github.event_name != 'pull_request_target' && (github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository)";
const LABELS = `fromJSON('["self-hosted","macOS","ARM64","modelplan-mac"]')`;
export const ALLOWED_ROUTES = new Set([
  `runs-on: \${{ (${GUARD}) && ${LABELS} || 'macos-latest' }}`,
  `runs-on: \${{ (matrix.os == 'macos-latest' && ${GUARD}) && ${LABELS} || matrix.os }}`,
]);

export function workflowProblems(text) {
  const problems = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (/modelplans-(publish|ci)/.test(line)) problems.push("private runner label");
    if (/^runs-on:.*\b(format|join)\(/.test(line)) problems.push("dynamically constructed runner label");
    if ((line.includes("self-hosted") || line.includes("pull_request_target")) && !ALLOWED_ROUTES.has(line))
      problems.push("non-canonical self-hosted route or pull_request_target");
  }
  return problems;
}
