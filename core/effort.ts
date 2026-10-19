/**
 * Balanced ★ v5 (ADR 0045): within one model, U = ability − a·cost − b·log₂(cost) − t·log₂(time).
 * (a, b, t) ranges over the polytope the owner's recorded choices allow; the ★ minimises the
 * worst regret over its vertices. Time is a same-model ratio, so its unit cancels; an uncertain
 * time is an interval, read worst-case for the candidate and best-case for its rivals. When either
 * side of a comparison rests on a single run, a second time source (`crossCheck`, its own unit)
 * also scores the pair, and the larger regret counts.
 */
export type V5Config = { id: string; score: number; cost: number; seconds?: number };
export type V5Preference = { preferred: V5Config; alternative: V5Config; provenance: string };
export type V5Vertex = { absolute: number; relative: number; time: number };
export type V5Candidate = {
  id: string;
  score: number;
  cost: number;
  /** Same-model time interval in any unit shared by the model's efforts; null when unknown. */
  time: readonly [number, number] | null;
  /** The time above is one run of one source, not a mean of several. */
  singleRun?: boolean;
  /** An independent same-model time in its own unit, read only against a single-run pair. */
  crossCheck?: number | null;
};
type Plane = { n: [number, number, number]; limit: number };

const EPS = 1e-9;
const det3 = (m: number[][]) =>
  m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
  m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
  m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
const cross = (p: number[], q: number[]): [number, number, number] => [
  p[1] * q[2] - p[2] * q[1],
  p[2] * q[0] - p[0] * q[2],
  p[0] * q[1] - p[1] * q[0],
];
const dot = (p: number[], q: number[]) => p[0] * q[0] + p[1] * q[1] + p[2] * q[2];

function planes(preferences: V5Preference[]): Plane[] {
  const out: Plane[] = [
    { n: [-1, 0, 0], limit: 0 },
    { n: [0, -1, 0], limit: 0 },
    { n: [0, 0, -1], limit: 0 },
  ];
  for (const { preferred: p, alternative: q } of preferences) {
    for (const v of [p, q])
      if (!(v.cost > 0) || !Number.isFinite(v.score) || (v.seconds !== undefined && !(v.seconds > 0)))
        throw new Error("invalid_v5_preference");
    // A choice made without a time shown constrains price only.
    const time = p.seconds !== undefined && q.seconds !== undefined ? Math.log2(p.seconds / q.seconds) : 0;
    out.push({ n: [p.cost - q.cost, Math.log2(p.cost / q.cost), time], limit: p.score - q.score });
  }
  return out;
}

/** Vertices of {w ≥ 0 : U(preferred) ≥ U(alternative) for every choice}, and whether it is bounded. */
export function priceTimeRegion(preferences: V5Preference[]) {
  const ps = planes(preferences);
  const vertices: V5Vertex[] = [];
  for (let i = 0; i < ps.length; i++)
    for (let j = i + 1; j < ps.length; j++)
      for (let k = j + 1; k < ps.length; k++) {
        const m = [ps[i].n, ps[j].n, ps[k].n],
          l = [ps[i].limit, ps[j].limit, ps[k].limit],
          d = det3(m);
        if (Math.abs(d) < EPS) continue;
        const x = [0, 1, 2].map((c) => det3(m.map((r, ri) => r.map((v, ci) => (ci === c ? l[ri] : v)))) / d);
        if (!ps.every((p) => dot(p.n, x) <= p.limit + EPS)) continue;
        const v = { absolute: Math.max(0, x[0]), relative: Math.max(0, x[1]), time: Math.max(0, x[2]) };
        if (!vertices.some((u) => Math.abs(u.absolute - v.absolute) + Math.abs(u.relative - v.relative) + Math.abs(u.time - v.time) < 1e-7))
          vertices.push(v);
      }
  // Unbounded when a nonzero direction d ≥ 0 keeps every choice: its extreme rays lie on two planes.
  const unboundedRay = ps.some((p, i) =>
    ps.slice(i + 1).some((q) => {
      const r = cross(p.n, q.n);
      return [r, r.map((x) => -x)].some(
        (d) => Math.hypot(...d) > EPS && d.every((x) => x >= -EPS) && ps.every((s) => dot(s.n, d) <= EPS),
      );
    }),
  );
  return {
    status: !vertices.length ? ("inconsistent" as const) : unboundedRay ? ("unbounded" as const) : ("bounded" as const),
    vertices,
  };
}

export function recommendBalancedV5(candidates: V5Candidate[], preferences: V5Preference[]) {
  if (new Set(candidates.map((c) => c.id)).size !== candidates.length) throw new Error("duplicate_candidate_id");
  for (const c of candidates)
    if (
      !c.id ||
      !Number.isFinite(c.score) ||
      !(c.cost > 0) ||
      (c.time && (!(c.time[0] > 0) || !(c.time[1] >= c.time[0]))) ||
      (c.crossCheck !== undefined && c.crossCheck !== null && !(c.crossCheck > 0))
    )
      throw new Error("invalid_v5_candidate");
  const region = priceTimeRegion(preferences);
  if (region.status !== "bounded" || !candidates.length)
    return { status: region.status === "bounded" ? ("no-feasible-candidate" as const) : ("calibration-unresolved" as const), region, compromise: null, rankings: [] };
  const known = candidates.flatMap((c) => (c.time ? [...c.time] : []));
  // Unknown time spans the model's observed range; with no time at all the term cancels.
  const range: readonly [number, number] = known.length ? [Math.min(...known), Math.max(...known)] : [1, 1];
  const t = (c: V5Candidate) => c.time ?? range;
  const u = (c: V5Candidate, v: V5Vertex, seconds: number) =>
    c.score - v.absolute * c.cost - v.relative * Math.log2(c.cost) - v.time * Math.log2(seconds);
  const regret = (c: V5Candidate, o: V5Candidate, v: V5Vertex) => {
    const primary = u(o, v, t(o)[0]) - u(c, v, t(c)[1]);
    return (c.singleRun || o.singleRun) && c.crossCheck && o.crossCheck
      ? Math.max(primary, u(o, v, o.crossCheck) - u(c, v, c.crossCheck))
      : primary;
  };
  const rankings = candidates
    .map((c) => {
      const worstRegret = Math.max(
        0,
        ...region.vertices.flatMap((v) => candidates.filter((o) => o !== c).map((o) => regret(c, o, v))),
      );
      return { ...c, worstRegret, robustWinner: worstRegret <= EPS };
    })
    .sort((a, b) => a.worstRegret - b.worstRegret || a.cost - b.cost || b.score - a.score || a.id.localeCompare(b.id));
  return { status: "comparison-only" as const, region, compromise: rankings[0], rankings };
}
