// SPDX-License-Identifier: MIT
// Runner and trigger rules for public workflows. Defence in depth only: the enforced boundaries
// are the dedicated Mac's owner-only pre-job gate and the private runners' private-repo registration.
const ROUTE_GUARD = "github.event_name != 'pull_request_target'";

export function workflowProblems(text) {
  const problems = [];
  const code = text.split("\n").map((l) => l.replace(/(^|\s)#.*$/, "")); // comments never count
  if (code.some((l) => l.includes("modelplans-publish") || l.includes("modelplans-ci"))) problems.push("private runner label");
  if (/format\(|join\(/.test(code.filter((l) => /runs-on:/.test(l)).join("\n"))) problems.push("dynamically constructed runner label");
  // Any mention of pull_request_target outside the routing guard is a trigger in some YAML form.
  for (const l of code) if (l.includes("pull_request_target") && !l.includes(ROUTE_GUARD)) problems.push("pull_request_target trigger");
  for (const l of code.filter((l) => l.includes("self-hosted"))) {
    const ok = /runs-on:\s*\$\{\{/.test(l) && l.includes("modelplan-mac") && l.includes("vars.MAC_CI_RUNNER == 'self-hosted'")
      && l.includes(ROUTE_GUARD) && l.includes("github.event.pull_request.head.repo.full_name == github.repository");
    if (!ok) problems.push("unguarded self-hosted selection");
  }
  return problems;
}
