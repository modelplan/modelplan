#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""WP-17 (G3-123): turn ModelPlan timing logs into per-stage tables (n, min, median, max in ms).

Standard library only. Reads ModelPlan.log (~/Library/Logs/ModelPlan, rotated copies too) or a test run's stderr:

  timing launch stage=<name> uptimeMs=<u> sinceStartMs=<ms> [key=value ...]   cold start, once per process
  timing open stage=<name> elapsedMs=<ms>                                     one open, from the click
  timing close stage=<name> elapsedMs=<ms>                                    one close, from the request
  timing open <event...> clickMs=<ms>          older open lines (ready, shown, rendered n=1, display=fresh ...)
  timing page stage=navigation-finish loadMs=<ms> files=<n> verifyMs=<ms>    one page load

A cold-start run begins at `launch stage=main`; an open cycle begins at `open stage=request`; a close at
`close stage=request`. In each run a stage counts once (its first line). Extra numeric `key=value` tokens on a launch
or page line become their own rows (`bundle-verified ms`, `page-navigation-finish verifyMs`).

  summarize_timing.py timing ModelPlan.log [more logs ...] [--json]
  summarize_timing.py cpu cpu-samples.txt [--cores N] [--json]

The cpu mode reads `ps` samples written by the WP-17 plan, one line per process per sample:
  <epoch-seconds> <pid> <%cpu> <command...>
and prints the mean %CPU per process (pid), per command (its processes added up per sample) and in total
(100 = one core).
"""
from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from collections import OrderedDict

TOKEN = re.compile(r"^([A-Za-z][A-Za-z0-9_.-]*)=(-?[0-9]+)$")
SKIP_EXTRA = {"uptimeMs", "sinceStartMs", "elapsedMs", "clickMs", "loadMs", "n"}


def tokens(text: str) -> list[str]:
    return text.split()


def numeric(parts: list[str]) -> "OrderedDict[str, int]":
    out: "OrderedDict[str, int]" = OrderedDict()
    for part in parts:
        match = TOKEN.match(part)
        if match:
            out[match.group(1)] = int(match.group(2))
    return out


class Collector:
    def __init__(self) -> None:
        # group -> list of runs; a run is an ordered stage -> ms map.
        self.runs: "OrderedDict[str, list[OrderedDict[str, int]]]" = OrderedDict(
            (group, []) for group in ("launch", "open", "close", "page"))

    def _run(self, group: str, new: bool) -> "OrderedDict[str, int]":
        runs = self.runs[group]
        if new or not runs:
            runs.append(OrderedDict())
        return runs[-1]

    def _put(self, group: str, stage: str, value: int, new: bool = False) -> None:
        run = self._run(group, new)
        run.setdefault(stage, value)

    def line(self, raw: str) -> None:
        at = raw.find("timing ")
        if at < 0:
            return
        parts = tokens(raw[at + len("timing "):])
        if not parts:
            return
        head, rest = parts[0], parts[1:]
        values = numeric(rest)
        stage = next((p.split("=", 1)[1] for p in rest if p.startswith("stage=")), None)
        if head == "launch" and stage is not None and "sinceStartMs" in values:
            new = stage == "main"
            self._put("launch", stage, values["sinceStartMs"], new=new)
            for key, value in values.items():
                if key not in SKIP_EXTRA:
                    self._put("launch", f"{stage} {key}", value)
        elif head in ("open", "close") and stage is not None and "elapsedMs" in values:
            self._put(head, stage, values["elapsedMs"], new=stage == "request")
        elif head == "open" and "clickMs" in values:
            # Older open lines: the words before clickMs name the event. They join the current open cycle.
            words = [p for p in rest if not p.startswith("clickMs=")]
            if values["clickMs"] >= 0:
                self._put("open", "legacy " + " ".join(words), values["clickMs"])
        elif head == "page" and stage is not None and "loadMs" in values:
            self._put("page", stage, values["loadMs"], new=True)
            for key, value in values.items():
                if key not in SKIP_EXTRA:
                    self._put("page", f"{stage} {key}", value)

    def table(self) -> "OrderedDict[str, list[dict]]":
        out: "OrderedDict[str, list[dict]]" = OrderedDict()
        for group, runs in self.runs.items():
            order: list[str] = []
            for run in runs:
                for stage in run:
                    if stage not in order:
                        order.append(stage)
            rows = []
            for stage in order:
                samples = [run[stage] for run in runs if stage in run]
                rows.append({
                    "stage": stage, "n": len(samples), "min": min(samples),
                    "median": statistics.median(samples), "max": max(samples),
                })
            if rows:
                out[group] = rows
        return out


def summarize(paths: list[str]) -> "OrderedDict[str, list[dict]]":
    collector = Collector()
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for raw in handle:
                collector.line(raw.rstrip("\n"))
    return collector.table()


def cpu(paths: list[str], cores: int) -> dict:
    """Per process (pid + command), per command (all its processes added up in each sample) and in total."""
    per_process: "OrderedDict[tuple[str, str], list[float]]" = OrderedDict()
    per_sample: "OrderedDict[str, OrderedDict[str, float]]" = OrderedDict()
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for raw in handle:
                parts = raw.split(None, 3)
                if len(parts) < 4:
                    continue
                try:
                    stamp, pid, value = parts[0], parts[1], float(parts[2])
                except ValueError:
                    continue
                name = parts[3].strip().rsplit("/", 1)[-1]
                per_process.setdefault((pid, name), []).append(value)
                sample = per_sample.setdefault(stamp, OrderedDict())
                sample[name] = sample.get(name, 0.0) + value
    count = len(per_sample)
    names: list[str] = []
    for sample in per_sample.values():
        names.extend(n for n in sample if n not in names)
    totals = [sum(sample.values()) for sample in per_sample.values()]
    return {
        "samples": count,
        # A process absent from a sample (not yet started, or gone) is not counted as 0 in its own mean.
        "processes": [{"pid": pid, "command": name, "meanPercent": round(statistics.mean(v), 2), "maxPercent": round(max(v), 2)}
                      for (pid, name), v in per_process.items()],
        # Per command: the sum over its processes in each sample, averaged over every sample (absent = 0).
        "commands": [{"command": name,
                      "meanPercent": round(sum(s.get(name, 0.0) for s in per_sample.values()) / count, 2),
                      "maxPercent": round(max(s.get(name, 0.0) for s in per_sample.values()), 2)} for name in names],
        "totalMeanPercent": round(statistics.mean(totals), 2) if totals else None,
        "totalMaxPercent": round(max(totals), 2) if totals else None,
        "totalMeanPercentOfAllCores": round(statistics.mean(totals) / cores, 2) if totals and cores else None,
    }


def render(table: "OrderedDict[str, list[dict]]") -> str:
    lines = []
    titles = {"launch": "cold start (ms since process start)", "open": "open (ms since click)",
              "close": "close (ms since request)", "page": "page load (ms)"}
    for group, rows in table.items():
        width = max(len(r["stage"]) for r in rows)
        lines.append(f"## {titles[group]}")
        lines.append(f"{'stage'.ljust(width)}  {'n':>3}  {'min':>7}  {'median':>7}  {'max':>7}")
        for r in rows:
            median = r["median"]
            median_text = str(int(median)) if float(median).is_integer() else f"{median:.1f}"
            lines.append(f"{r['stage'].ljust(width)}  {r['n']:>3}  {r['min']:>7}  {median_text:>7}  {r['max']:>7}")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("mode", choices=["timing", "cpu"])
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--cores", type=int, default=0, help="cpu mode: logical cores, for a share of the whole machine")
    args = parser.parse_args(argv)
    if args.mode == "cpu":
        result = cpu(args.paths, args.cores)
        if args.json:
            print(json.dumps(result, indent=2))
        else:
            print(f"samples={result['samples']} total mean={result['totalMeanPercent']}% max={result['totalMaxPercent']}% "
                  f"(100% = one core; budget CKP-SHELL-19: mean <= 10%)")
            for c in result["commands"]:
                print(f"  {c['command']} (all its processes): mean={c['meanPercent']}% max={c['maxPercent']}%")
            for p in result["processes"]:
                print(f"    pid {p['pid']} {p['command']}: mean={p['meanPercent']}% max={p['maxPercent']}%")
        return 0
    table = summarize(args.paths)
    if args.json:
        print(json.dumps(table, indent=2))
    else:
        print(render(table) if table else "no timing lines found")
    return 0 if table else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
