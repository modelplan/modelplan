// SPDX-License-Identifier: MIT
// Git proofs for the merge-queue gate, run in a blobless clone of the repository (objects are fetched on
// demand). Every function fails closed: a missing object or an unexpected shape means "not proven".
import { execFileSync } from "node:child_process";

const SHA = /^[0-9a-f]{40}$/;

export function git(cwd, args, { allowFail = false } = {}) {
  try {
    return execFileSync("git", args, { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], maxBuffer: 64 << 20 });
  } catch (e) {
    if (allowFail) return null;
    throw e;
  }
}

// Make sure a commit is present locally; fetch it by id if not (GitHub serves reachable commits by sha,
// including PR heads and merge-queue branches).
export function ensure(cwd, sha) {
  if (!SHA.test(sha)) return false;
  if (git(cwd, ["cat-file", "-e", `${sha}^{commit}`], { allowFail: true }) !== null) return true;
  git(cwd, ["fetch", "-q", "--no-tags", "--filter=blob:none", "origin", sha], { allowFail: true });
  return git(cwd, ["cat-file", "-e", `${sha}^{commit}`], { allowFail: true }) !== null;
}

export const parents = (cwd, sha) => git(cwd, ["rev-list", "--parents", "-n", "1", sha]).trim().split(" ").slice(1);
export const tree = (cwd, sha) => git(cwd, ["rev-parse", `${sha}^{tree}`]).trim();
export const isAncestor = (cwd, a, b) => git(cwd, ["merge-base", "--is-ancestor", a, b], { allowFail: true }) !== null;
export const mergeBase = (cwd, a, b) => (git(cwd, ["merge-base", a, b], { allowFail: true }) ?? "").trim() || null;

// The commits reachable from sha that main does not have, as a Set of full ids.
export function commitsOnlyIn(cwd, sha, mainRef) {
  if (!ensure(cwd, sha)) throw new Error(`commit ${sha} not found`);
  return new Set(git(cwd, ["rev-list", sha, `^${mainRef}`]).split("\n").filter(Boolean));
}

// The contribution between two commits as Git object identity: one record per changed path with old and
// new mode and object id and the change letter, NUL-delimited, renames off. Unlike a patch id this sees
// mode-only changes, binaries, symlinks and deletions exactly.
export function contribution(cwd, from, to) {
  return git(cwd, ["diff", "--raw", "-z", "--no-renames", "--no-abbrev", "--no-ext-diff", "--no-textconv", from, to]);
}

// VERDICT-CARRY old -> new holds when new is a merge whose first parent is the reviewed head and whose
// second parent is on main, and the PR's own contribution (reviewed head against its fork point from that
// main commit, versus new against that main commit) is object-identical. A file that main also changed
// therefore never carries: it needs a fresh review.
export function verifyCarry(cwd, oldSha, newSha, mainRef) {
  if (!ensure(cwd, oldSha) || !ensure(cwd, newSha)) return { ok: false, why: "commit not found" };
  const p = parents(cwd, newSha);
  if (p.length !== 2) return { ok: false, why: "not a two-parent merge" };
  if (p[0] !== oldSha) return { ok: false, why: "first parent is not the reviewed head" };
  if (!isAncestor(cwd, p[1], mainRef)) return { ok: false, why: "second parent is not on main" };
  const mb = mergeBase(cwd, oldSha, p[1]);
  if (!mb) return { ok: false, why: "no merge base" };
  const reviewed = contribution(cwd, mb, oldSha);
  if (!reviewed) return { ok: false, why: "reviewed head has no contribution" };
  if (reviewed !== contribution(cwd, p[1], newSha)) return { ok: false, why: "contribution changed by the merge" };
  return { ok: true, why: "object-identical contribution" };
}

// A merge-group step is clean when it is a two-parent merge and Git's own merge of the two parents
// produces exactly its tree (so no hand resolution and no extra change rode along).
export function verifyCleanMerge(cwd, sha) {
  if (!ensure(cwd, sha)) return { ok: false, why: "group commit not found" };
  const p = parents(cwd, sha);
  if (p.length !== 2) return { ok: false, why: "group commit is not a two-parent merge" };
  const out = git(cwd, ["merge-tree", "--write-tree", "--no-messages", p[0], p[1]], { allowFail: true });
  if (out === null) return { ok: false, why: "parents do not merge cleanly" };
  if (out.trim().split("\n")[0] !== tree(cwd, sha)) return { ok: false, why: "group tree differs from a clean merge of its parents" };
  return { ok: true, why: "clean merge" };
}

// The PR's own change from `from` to `to` as patch text that does not depend on where main moved: per file the
// headers (path, mode, new or deleted) and every hunk's removed, added and context lines, byte for byte, binaries
// in full. Only the parts a main merge shifts are dropped: blob ids on `index` lines and the line numbers and
// function text of `@@` hunk headers. Patch content lines always start with ' ', '+', '-' or '\', and a binary
// patch's base85 lines contain no space, so the two patterns below never touch content.
export function ownPatch(cwd, from, to) {
  const out = git(cwd, ["-c", "diff.noprefix=false", "-c", "diff.mnemonicPrefix=false", "diff", "--no-renames", "--no-ext-diff", "--no-textconv", "--no-color",
    "--binary", "--full-index", "--diff-algorithm=myers", "--unified=3", from, to]);
  return out.split("\n").filter((l) => !l.startsWith("index ")).map((l) => (l.startsWith("@@ ") ? "@@" : l)).join("\n");
}

// D243 G6 auto-carry: an earlier review of `oldSha` holds for `newSha` without any carry comment when
//   1. following first parents from newSha reaches oldSha within 20 commits, and every commit on that path is a
//      two-parent merge whose second parent is on main (so every other commit in old..new came from main), and
//   2. the PR's own change is identical: ownPatch(merge-base(main, old), old) == ownPatch(merge-base(main, new), new).
// A conflict resolution or a regenerated file that alters the PR's own hunks breaks (2) and needs a fresh review.
// `between` lists the first-parent commits after oldSha up to newSha, so the rules can refuse a carry over a head
// that was reviewed after oldSha.
export function verifyMainMerges(cwd, oldSha, newSha, mainRef) {
  const no = (why) => ({ ok: false, why, between: [] });
  if (oldSha === newSha) return no("same commit");
  if (!ensure(cwd, oldSha) || !ensure(cwd, newSha)) return no("commit not found");
  if (!isAncestor(cwd, oldSha, newSha)) return no("reviewed head is not an ancestor");
  const between = [];
  let c = newSha;
  for (let hop = 0; c !== oldSha; hop++) {
    if (hop >= 20) return no("more than 20 commits after the reviewed head");
    const p = parents(cwd, c);
    if (p.length !== 2) return no(`${c.slice(0, 8)} is not a merge of main`);
    if (!isAncestor(cwd, p[1], mainRef)) return no(`${c.slice(0, 8)}: second parent is not on main`);
    if (!isAncestor(cwd, oldSha, p[0])) return no(`${c.slice(0, 8)}: first parent does not descend from the reviewed head`);
    between.push(c);
    c = p[0];
  }
  const oldBase = mergeBase(cwd, mainRef, oldSha), newBase = mergeBase(cwd, mainRef, newSha);
  if (!oldBase || !newBase) return no("no merge base with main");
  const reviewed = ownPatch(cwd, oldBase, oldSha);
  if (!reviewed.trim()) return no("reviewed head has no change of its own");
  if (reviewed !== ownPatch(cwd, newBase, newSha)) return no("the PR's own diff changed");
  return { ok: true, why: "main merges only, diff unchanged", between };
}
