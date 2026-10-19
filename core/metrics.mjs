/* Portable, pure internal-preview module. No DOM, network, storage or production writes. */
export function calculateMetrics(data, state = {}) {
  state = {
    sourceMode: "all",
    timeSource: "all",
    anchors: false,
    excludedSources: [],
    ...state,
  };
  if (
    !["all", "aa"].includes(state.sourceMode) ||
    !["all", "aa-agent", "tb", "bughunt"].includes(state.timeSource) ||
    typeof state.anchors !== "boolean"
  )
    throw new Error("invalid_metric_options");
  for (const [source, fields] of Object.entries(data.references))
    for (const [field, ref] of Object.entries(fields))
      if (
        ref.status === "ready" &&
        (!Number.isFinite(ref.mu) ||
          (field === "ability" && (!Number.isFinite(ref.sd) || ref.sd <= 0)))
      )
        throw new Error("invalid_frozen_reference:" + source + ":" + field);
  for (const field of ["ability", "cost", "time"])
    if (
      Math.abs(
        Object.values(data.sources).reduce((a, s) => a + s[field], 0) - 1,
      ) > 1e-8
    )
      throw new Error("metric_budgets_must_sum_to_one");
  for (const m of data.models)
    for (const row of m.rows)
      if (
        new Set(row.observations.map((o) => o.source)).size !==
        row.observations.length
      )
        throw new Error("duplicate_same_configuration_source");
  const enabled = (s) =>
    !state.excludedSources.includes(s) &&
    (state.sourceMode !== "aa" || ["aa", "aa-agent"].includes(s));
  const ready = (s, field) => data.references[s]?.[field]?.status === "ready";
  const norm = (o) => {
    const r = data.references[o.source].ability;
    return (o.ability - r.mu) / r.sd;
  };
  const median = (xs) => {
    const v = [...xs].sort((a, b) => a - b);
    return v.length % 2
      ? v[(v.length - 1) / 2]
      : (v[v.length / 2 - 1] + v[v.length / 2]) / 2;
  };
  const budget = (field) =>
    Object.values(data.sources).reduce((a, s) => a + s[field], 0);
  const sourceCount = (xs) =>
    new Set(xs.map((o) => data.sources[o.source].publisher)).size;
  const ratio = (obs, field, weights, selectedOnly = false) => {
    const valid = obs.filter(
      (o) =>
        enabled(o.source) &&
        Number.isFinite(o[field]) &&
        o[field] >= 0 &&
        ready(o.source, field),
    );
    const used = selectedOnly
      ? valid.filter(
          (o) => state.timeSource === "all" || state.timeSource === o.source,
        )
      : valid;
    const zeros = used.filter((o) => o[field] === 0);
    const positives = used.filter((o) => o[field] > 0);
    const den = positives.reduce(
      (a, o) => a + data.sources[o.source][weights] * o.reliability,
      0,
    );
    const value = zeros.length
      ? positives.length
        ? null
        : 0
      : den
        ? Math.exp(
            used.reduce(
              (a, o) =>
                a +
                data.sources[o.source][weights] *
                  o.reliability *
                  (Math.log(o[field]) - data.references[o.source][field].mu),
              0,
            ) / den,
          )
        : null;
    const completeness =
      (100 * used.reduce((a, o) => a + data.sources[o.source][weights], 0)) /
      budget(weights);
    return {
      value,
      completeness,
      unavailableReason:
        zeros.length && positives.length
          ? "zero-and-positive-workloads-not-pooled"
          : null,
      independentPublishers: sourceCount(used),
      used: used.map((o) => ({
        source: o.source,
        ratio:
          o[field] === 0
            ? 0
            : Math.exp(
                Math.log(o[field]) - data.references[o.source][field].mu,
              ),
        weight: data.sources[o.source][weights] * o.reliability,
        cohort: o.cohort,
        note: o.note,
        repeats: o.repeats,
        boundary: o.boundary,
        absolute: o[field],
        kind: "observed-source-reference",
      })),
    };
  };
  return data.models.map((m) => ({
    id: m.id,
    name: m.name,
    developer: m.developer,
    recommended: m.recommended,
    rows: m.rows.map((row) => {
      const direct = row.observations.filter(
        (o) =>
          enabled(o.source) &&
          Number.isFinite(o.ability) &&
          ready(o.source, "ability"),
      );
      const aa = direct.find((o) => o.source === "aa");
      let used = direct.map((o) => ({ ...o, z: norm(o), kind: "observed" }));
      // One shared shrinkage, measured anchors of the EXACT same model version.
      // Predictions do not count toward factual completeness and never become raw source values.
      if (aa && state.anchors === true)
        for (const [s, spec] of Object.entries(data.sources)) {
          if (
            !enabled(s) ||
            s === "aa" ||
            !spec.ability ||
            !ready(s, "ability") ||
            direct.some((o) => o.source === s)
          )
            continue;
          const pairs = m.rows.flatMap((r) => {
            const a = r.observations.find((o) => o.source === "aa");
            const b = r.observations.find((o) => o.source === s);
            return a && b && Number.isFinite(b.ability)
              ? [{ aa: norm(a), z: norm(b), effort: r.effort }]
              : [];
          });
          if (!pairs.length) continue;
          const inside =
            norm(aa) >= Math.min(...pairs.map((p) => p.aa)) &&
            norm(aa) <= Math.max(...pairs.map((p) => p.aa));
          const reliability = inside
            ? data.parameters.predictionReliabilityInside
            : data.parameters.predictionReliabilityOutside;
          const z =
            norm(aa) +
            (pairs.length /
              (pairs.length + data.parameters.predictionShrinkage)) *
              median(pairs.map((p) => p.z - p.aa));
          used.push({
            source: s,
            z,
            reliability,
            kind: inside
              ? "estimated-between-anchors"
              : "estimated-outside-anchors",
            cohort: "same-version normalized residual shrinkage",
            note: "同版本其他档位锚定试算；不增加数据完善度。",
            anchorEfforts: pairs.map((p) => p.effort),
          });
        }
      const denominator = used.reduce(
        (a, o) => a + data.sources[o.source].ability * o.reliability,
        0,
      );
      const q = denominator
        ? used.reduce(
            (a, o) => a + data.sources[o.source].ability * o.reliability * o.z,
            0,
          ) / denominator
        : null;
      const ability = {
        value: q === null ? null : 50 + 10 * q,
        completeness:
          (100 *
            direct.reduce((a, o) => a + data.sources[o.source].ability, 0)) /
          budget("ability"),
        independentPublishers: sourceCount(direct),
        used: used.map((o) => ({
          source: o.source,
          z: o.z,
          weight: data.sources[o.source].ability * o.reliability,
          kind: o.kind,
          cohort: o.cohort,
          note: o.note,
          anchorEfforts: o.anchorEfforts,
        })),
      };
      const expense = ratio(row.observations, "cost", "cost");
      // Task-boundary cohorts are not averaged. Prefer exact AA active-agent wall,
      // else TB trial, else an uncontended Bug Hunt run; keep the chosen boundary.
      const timeAvailable = row.observations.filter(
        (o) =>
          enabled(o.source) &&
          data.sources[o.source].time > 0 &&
          Number.isFinite(o.seconds) &&
          o.seconds > 0 &&
          ready(o.source, "seconds"),
      );
      const ordered = ["aa-agent", "tb", "bughunt"];
      const chosen = ordered
        .map((s) => timeAvailable.find((o) => o.source === s))
        .find(
          (o) =>
            o && (state.timeSource === "all" || state.timeSource === o.source),
        );
      const time = {
        value: chosen
          ? chosen.seconds /
            data.references[chosen.source].seconds.geometricReference
          : null,
        completeness:
          (100 *
            timeAvailable
              .filter(
                (o) =>
                  state.timeSource === "all" || state.timeSource === o.source,
              )
              .reduce((a, o) => a + data.sources[o.source].time, 0)) /
          budget("time"),
        independentPublishers: sourceCount(
          timeAvailable.filter(
            (o) => state.timeSource === "all" || state.timeSource === o.source,
          ),
        ),
        selectedSource: chosen?.source ?? null,
        selectedBoundary: chosen?.boundary ?? null,
        absoluteSeconds: chosen?.seconds ?? null,
        used: timeAvailable.map((o) => ({
          source: o.source,
          ratio:
            o.seconds / data.references[o.source].seconds.geometricReference,
          cohort: o.cohort,
          note: o.note,
          repeats: o.repeats,
          boundary: o.boundary,
          absolute: o.seconds,
          kind:
            o === chosen ? "chosen-task-reference" : "separate-task-reference",
        })),
      };
      const aaTask = row.observations.find(
        (o) => o.source === "aa-agent" && Number.isFinite(o.seconds),
      );
      return {
        effort: row.effort,
        ability,
        expense,
        time,
        aaTaskSeconds: aaTask?.seconds ?? null,
        observations: row.observations,
        referenceOnly: row.observations.filter(
          (o) => o.referenceSeconds || o.referenceCost,
        ),
        status:
          ability.value === null
            ? "insufficient-observations"
            : ability.independentPublishers <= 1
              ? direct.some((o) => o.source === "aa" || o.source === "aa-agent")
                ? "AA基础估计"
                : "单发布者基础估计"
              : "多源校准估计",
      };
    }),
  }));
}
