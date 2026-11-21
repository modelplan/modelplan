#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""WP-17 (G3-123): one JSON summary and one markdown table from the automated cockpit measurement.

Reads the files CockpitPerfMeasurementTests (CommunityCockpitEntryTests.testWP17...) wrote into --dir:

  cold-start.log   `timing launch stage=...` lines, one run per cold start (starts at stage=main)
  attached.log     the app's own `timing open ...` / `timing close ...` lines, one cycle after another
  detached.log     the same with the cockpit detached
  idle-cpu.txt     `<second> <pid> <%cpu> <label>` per process per second (100 = one core), cockpit open and idle

and uses summarize_timing.py for the stage samples. Writes perf-summary.json and perf-summary.md next to them, prints the
markdown, and exits 1 only when a measurement could not be taken (fewer than N=10 samples, fewer than 60 idle seconds,
a missing file). Budgets are printed beside the numbers and are NOT enforced here (WP-17 needs the numbers first).

  perf_report.py --dir <dir> [--cores N] [--meta key=value ...]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import summarize_timing  # noqa: E402

REQUIRED = 10
IDLE_SECONDS = 60
BUDGETS = {"visibleMs": 200, "animationMs": 400, "idleCpuPercent": 10}
# (json key, stage name in the log)
COLD_STAGES = [("engineHandshake", "engine-handshake"), ("firstRendered", "first-rendered"),
               ("firstRenderedWithData", "first-rendered-with-data")]
OPEN_STAGES = [("windowVisible", "window-visible"), ("pageRendered", "page-rendered"), ("animationComplete", "animation-complete")]
CLOSE_STAGES = [("gone", "gone")]
OPEN_LABELS = {"windowVisible": "visible", "pageRendered": "rendered", "animationComplete": "animation complete"}


def percentile(samples: list, pct: float):
    """Nearest rank: the smallest sample with at least pct percent of the samples at or below it."""
    ordered = sorted(samples)
    return ordered[max(0, math.ceil(pct / 100 * len(ordered)) - 1)]


def stats(samples: list) -> dict:
    if not samples:
        return {"n": 0, "min": None, "median": None, "p90": None, "max": None}
    return {"n": len(samples), "min": min(samples), "median": statistics.median(samples),
            "p90": percentile(samples, 90), "max": max(samples)}


def build(directory: str, cores: int = 0, meta: dict | None = None) -> dict:
    problems: list[str] = []

    def timing(name: str) -> "dict":
        path = os.path.join(directory, name)
        if not os.path.exists(path):
            problems.append(f"{name} is missing")
            return {}
        return summarize_timing.stage_samples([path])

    def pick(groups: dict, group: str, stage: str) -> list:
        return list(groups.get(group, {}).get(stage, []))

    sections: dict = {}
    cold = timing("cold-start.log")
    sections["coldStart"] = {}
    for key, stage in COLD_STAGES:
        row = sections["coldStart"][key] = stats(pick(cold, "launch", stage))
        if key == "firstRenderedWithData" and os.path.exists(os.path.join(directory, "cold-start.log")) and row["n"] < REQUIRED:
            problems.append(f"coldStart first-rendered-with-data: n={row['n']} < {REQUIRED}")
    for scenario in ("attached", "detached"):
        groups = timing(f"{scenario}.log")
        sections[scenario] = {"open": {}, "close": {}}
        for key, stage in OPEN_STAGES:
            row = sections[scenario]["open"][key] = stats(pick(groups, "open", stage))
            if os.path.exists(os.path.join(directory, f"{scenario}.log")) and key in ("windowVisible", "animationComplete") and row["n"] < REQUIRED:
                problems.append(f"{scenario} open {stage}: n={row['n']} < {REQUIRED}")
        for key, stage in CLOSE_STAGES:
            row = sections[scenario]["close"][key] = stats(pick(groups, "close", stage))
            if os.path.exists(os.path.join(directory, f"{scenario}.log")) and row["n"] < REQUIRED:
                problems.append(f"{scenario} close {stage}: n={row['n']} < {REQUIRED}")
    idle_path = os.path.join(directory, "idle-cpu.txt")
    if os.path.exists(idle_path):
        result = summarize_timing.cpu([idle_path], cores)
        sections["idleCpu"] = {"samples": result["samples"], "meanPercent": result["totalMeanPercent"],
                               "maxPercent": result["totalMaxPercent"], "commands": result["commands"]}
        if result["samples"] < IDLE_SECONDS:
            problems.append(f"idle CPU: {result['samples']} samples < {IDLE_SECONDS}")
    else:
        problems.append("idle-cpu.txt is missing")
        sections["idleCpu"] = {"samples": 0, "meanPercent": None, "maxPercent": None, "commands": []}

    checks = []

    def check(name: str, statistic: str, value, budget: float) -> None:
        if value is not None:
            checks.append({"name": name, "statistic": statistic, "value": value, "budget": budget,
                           "status": "within" if value <= budget else "over"})

    for scenario in ("attached", "detached"):
        for key, label, budget in (("windowVisible", "visible", BUDGETS["visibleMs"]), ("animationComplete", "animation", BUDGETS["animationMs"])):
            row = sections[scenario]["open"][key]
            check(f"{scenario} {label} ms", "median", row["median"], budget)
            check(f"{scenario} {label} ms", "p90", row["p90"], budget)
    check("idle CPU %", "mean", sections["idleCpu"]["meanPercent"], BUDGETS["idleCpuPercent"])
    return {"schema": 1, "required": REQUIRED, "budgets": BUDGETS, "meta": meta or {}, "sections": sections,
            "budgetCheck": checks, "problems": problems}


def fmt(value) -> str:
    if value is None:
        return "-"
    return str(int(value)) if float(value).is_integer() else f"{value:.1f}"


def markdown(result: dict) -> str:
    sections = result["sections"]
    lines = ["## WP-17 cockpit measurement (report only, budgets not enforced)", ""]
    meta = result.get("meta") or {}
    if meta:
        lines += [", ".join(f"{k}={v}" for k, v in meta.items()), ""]
    lines += ["| measurement | n | median | p90 | min | max |", "|---|---:|---:|---:|---:|---:|"]

    def row(label: str, s: dict) -> None:
        lines.append(f"| {label} | {s['n']} | {fmt(s['median'])} | {fmt(s['p90'])} | {fmt(s['min'])} | {fmt(s['max'])} |")

    for key, stage in COLD_STAGES:
        row(f"cold start: {stage} (ms from launch)", sections["coldStart"][key])
    for scenario in ("attached", "detached"):
        for key, _ in OPEN_STAGES:
            row(f"{scenario} open: {OPEN_LABELS[key]} (ms)", sections[scenario]["open"][key])
        row(f"{scenario} close: gone (ms)", sections[scenario]["close"]["gone"])
    idle = sections["idleCpu"]
    lines += [f"| idle CPU, cockpit open (% of one core, per second) | {idle['samples']} | {fmt(idle['meanPercent'])} (mean) | - | - | {fmt(idle['maxPercent'])} |", ""]
    lines += ["| budget | statistic | measured | budget | |", "|---|---|---:|---:|---|"]
    for c in result["budgetCheck"]:
        lines.append(f"| {c['name']} | {c['statistic']} | {fmt(c['value'])} | budget {fmt(c['budget'])} | {c['status']} |")
    if result["problems"]:
        lines += ["", "Measurement problems:"] + [f"- {p}" for p in result["problems"]]
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dir", required=True)
    parser.add_argument("--cores", type=int, default=0)
    parser.add_argument("--meta", nargs="*", default=[], help="key=value pairs recorded in the summary (runner, commit ...)")
    args = parser.parse_args(argv)
    meta = dict(item.split("=", 1) for item in args.meta if "=" in item)
    result = build(args.dir, args.cores, meta)
    with open(os.path.join(args.dir, "perf-summary.json"), "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
        handle.write("\n")
    text = markdown(result)
    with open(os.path.join(args.dir, "perf-summary.md"), "w", encoding="utf-8") as handle:
        handle.write(text)
    print(text, end="")
    return 1 if result["problems"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
