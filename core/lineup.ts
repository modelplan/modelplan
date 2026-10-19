/** Published deterministic verdicts. Consumers render them; they do not re-fit ranks. */
export const LINEUP_METHOD = "lineup-v1";
export const LINEUP_TIE = 1.0;
export type LineupInput = {
  id: string;
  ability: number | null;
  cost: number | null;
};
export type LineupDominance = { id: string; kind: "equivalent" | "weaker" };
export type LineupTag =
  "cheapest" | "strongest" | "best_value" | "equivalent_costlier" | "dominated";
export type LineupMember = {
  id: string;
  ability?: number;
  cost?: number;
  costRelative?: number;
  status?: "incomplete";
  tags: LineupTag[];
  dominatedBy: LineupDominance | null;
};
export type Lineup = {
  method: typeof LINEUP_METHOD;
  tie: number;
  baseline: string;
  frontier: string[];
  steps: {
    from: string;
    to: string;
    abilityDelta: number;
    costRatio: number;
  }[];
  members: LineupMember[];
};
const finite = (n: unknown): n is number =>
  typeof n === "number" && Number.isFinite(n);
export function lineup(members: readonly LineupInput[]): Lineup | null {
  if (new Set(members.map((m) => m.id)).size !== members.length)
    throw Error("duplicate_lineup_model");
  const known = members.filter(
    (m): m is { id: string; ability: number; cost: number } =>
      finite(m.ability) && finite(m.cost) && m.cost > 0,
  );
  const knownIds = new Set(known.map((m) => m.id));
  const incomplete: LineupMember[] = members
    .filter((m) => !knownIds.has(m.id))
    .map((m) => ({
      id: m.id,
      status: "incomplete",
      tags: [],
      dominatedBy: null,
    }));
  if (known.length < 2) return null;
  const compare = (
    a: { id: string; ability: number; cost: number },
    b: typeof a,
  ) =>
    a.cost - b.cost ||
    b.ability - a.ability ||
    (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const cheapest = [...known].sort(compare)[0],
    cMin = cheapest.cost;
  const rows = known.map((m) => {
    const d = known
      .filter(
        (o) =>
          o !== m &&
          ((o.cost < m.cost && o.ability >= m.ability - LINEUP_TIE) ||
            (o.cost === m.cost && o.ability > m.ability)),
      )
      .sort(compare)[0];
    return {
      id: m.id,
      ability: m.ability,
      cost: m.cost,
      costRelative: m.cost / cMin,
      tags: [] as LineupTag[],
      dominatedBy: d
        ? {
            id: d.id,
            kind:
              Math.abs(d.ability - m.ability) <= LINEUP_TIE
                ? ("equivalent" as const)
                : ("weaker" as const),
          }
        : null,
    };
  });
  const frontier = rows.filter((r) => !r.dominatedBy).sort(compare),
    aMax = Math.max(...rows.map((r) => r.ability));
  const strongest = rows
      .filter((r) => r.ability >= aMax - LINEUP_TIE)
      .sort(compare)[0],
    base = rows.find((r) => r.id === cheapest.id)!;
  let best: { row: typeof base; gain: number } | null = null;
  for (const r of frontier) {
    if (r === base || r.cost === base.cost) continue;
    const gain = (r.ability - base.ability) / Math.log2(r.cost / base.cost);
    if (!best || gain > best.gain) best = { row: r, gain };
  }
  base.tags.push("cheapest");
  strongest.tags.push("strongest");
  if (best) best.row.tags.push("best_value");
  for (const r of rows)
    if (r.dominatedBy)
      r.tags.push(
        r.dominatedBy.kind === "equivalent"
          ? "equivalent_costlier"
          : "dominated",
      );
  return {
    method: LINEUP_METHOD,
    tie: LINEUP_TIE,
    baseline: base.id,
    frontier: frontier.map((r) => r.id),
    steps: frontier
      .slice(1)
      .map((q, i) => ({
        from: frontier[i].id,
        to: q.id,
        abilityDelta: q.ability - frontier[i].ability,
        costRatio: q.cost / frontier[i].cost,
      })),
    members: [...rows, ...incomplete],
  };
}
