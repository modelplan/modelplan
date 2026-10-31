export const TRUSTED_MAC_ROUTE = "runs-on: ${{ (inputs.task != 'native' && inputs.os == 'macos-latest' && (github.repository == 'modelplan/modelplan' && github.actor_id == '11829005' && github.actor == 'guanbear' && github.triggering_actor == 'guanbear') && (((github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository && github.event.pull_request.user.id == 11829005 && !github.event.pull_request.draft) || ((github.event_name == 'push' || github.event_name == 'workflow_dispatch') && startsWith(github.ref, 'refs/heads/')))) && (vars.MAC_CI_RUNNER == 'self-hosted' || (inputs.task == 'probe' && github.event_name == 'workflow_dispatch'))) && fromJSON('[\"self-hosted\",\"macOS\",\"ARM64\",\"modelplan-mac\"]') || (inputs.os == 'ubuntu-latest' && 'ubuntu-latest' || inputs.os == 'macos-14' && 'macos-14' || 'macos-latest') }}";
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

// GitHub runs top-level .yml and .yaml files under .github/workflows/.
export function isWorkflowFile(path) {
  return /^\.github\/workflows\/[^/]+\.ya?ml$/.test(path);
}

// YAML double-quoted scalars may spell a key with escapes ("pull_request_tar\u0067et") or split it
// over an escaped line break. Checking the decoded text as well closes that gap without a YAML
// parser; decoding only ever adds lines to check, so ordinary shell and regex backslashes stay legal.
function decodedVariant(text) {
  return text
    .replace(/\\\r?\n[ \t]*/g, "")
    .replace(/\\(?:x([0-9a-fA-F]{2})|u([0-9a-fA-F]{4})|U([0-9a-fA-F]{8}))/g,
      (_, x, u, U) => String.fromCodePoint(parseInt(x || u || U, 16)));
}

function lineProblems(raw, problems) {
  const line = raw.trim();
  if (/modelplans-(publish|ci)/.test(line)) problems.add("private runner label");
  if (/^runs-on:.*\b(format|join)\(/.test(line)) problems.add("dynamically constructed runner label");
  if ((line.includes("self-hosted") || line.includes("pull_request_target")) && !ALLOWED_ROUTES.has(line))
    problems.add("non-canonical self-hosted route or pull_request_target");
}

export function workflowProblems(text, path = "") {
  const problems = new Set();
  const check = (raw) => {
    if (path === ".github/workflows/trusted-mac.yml" && raw.trim() === TRUSTED_MAC_ROUTE) return;
    lineProblems(raw, problems);
  };
  for (const raw of text.split("\n")) check(raw);
  if (text.includes("\\")) for (const raw of decodedVariant(text).split("\n")) check(raw);
  return [...problems];
}
