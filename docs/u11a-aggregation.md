<!-- SPDX-License-Identifier: MIT -->
# U11a measurement-log aggregation

`scripts/u11a-aggregate.py` summarizes supplied **per-process samples**. It does
not sample processes, launch an app, read a profile, operate a Mac, or decide a
performance budget. It uses Python 3.10+ and the standard library only.

```sh
mkdir -p .tmp
python3 scripts/u11a-aggregate.py \
  --input top=scripts/testdata/u11a/synthetic-top.csv \
  --input instruments=scripts/testdata/u11a/synthetic-instruments.jsonl \
  --cpu-basis one-core \
  --output-dir .tmp/u11a-example
```

The new output directory contains `report.json` and `report.md`. Existing output
directories are rejected. Inputs are read without modification. Each input's
basename, exact byte SHA-256, tool and sample count appear in both reports; full
input paths are not included. The committed sample files contain invented data,
not Mac measurements, and are MIT test fixtures.

## CSV and JSONL contract

These are tagged numeric sample exports, **not** parsers for arbitrary terminal
`top` output, native `powermetrics` text/plists or Instruments trace bundles.
Export the actual observed values to these columns without aggregating them
first. Select the original measuring tool with each `--input TOOL=FILE`:
`top`, `powermetrics`, `instruments` (Instruments export), or
`native-self-counters` (the explicit export contract below). Do not relabel one
tool's readings as another's. A source without attributable GPU or energy data
leaves those metrics unavailable; the aggregator cannot manufacture attribution.

CSV uses a header row. JSONL uses one object per nonblank line with the same keys.

| Field | Meaning |
|---|---|
| `run_id` | Required nonempty run/attempt identifier. Separate attempts must have separate IDs. |
| `scenario` | Required nonempty scenario/input variant, for example `A` or `B`. |
| `timestamp` | Required RFC3339 timestamp with timezone, or numeric Unix seconds. Numeric CSV cells are Unix seconds too. |
| `role` | Exactly `App`, `WebContent`, or `GPU`. Supply only processes actually attributed to the measured subject. |
| `phase` | `open`, `idle`, `after-close`, `repeated-open-close`, or optional `before-open` baseline. |
| `pid` | Required positive process ID. Multiple owned processes can share a role. |
| `cycle` | Optional positive cycle number, only for `repeated-open-close`. Required for cycle-growth results. |
| `cpu_percent` | Optional nonnegative finite CPU percentage. Values above 100 are allowed. |
| `rss_bytes` | Optional nonnegative integer RSS in bytes. Convert explicitly from the source unit. Do not substitute physical footprint, virtual size or another memory basis. |
| `energy_impact` | Optional nonnegative finite energy-impact reading in that tool's scale, not inferred power or joules. |

An omitted metric, empty CSV cell or JSON `null` means unavailable. A measured
numeric zero is available. Booleans, negative/nonfinite metrics, fractional byte
counts, unknown fields/roles/phases, missing identifiers, duplicate JSON/CSV keys
and duplicate process samples are rejected. No timestamp, missing role or absent
process is interpreted as zero. Unknown columns must be removed deliberately by
the exporter, not silently ignored by this tool.

All inputs in one invocation must use the selected CPU convention:
`--cpu-basis one-core` means 100% is one core; `machine` means 100% is the whole
machine. This setting labels values; it does not convert them. Use separate
invocations for different CPU conventions. RSS is always bytes; energy scales
stay tool-specific. Results are separated by `(run_id, scenario, tool)`, so A/B,
different runs and different measurement tools are never pooled.

## Native self-counter export contract v1

Use `--input native-self-counters=FILE` for an owned App's native self-counter
export in the same CSV or JSONL format. This source is **not** `top`,
`powermetrics`, or an Instruments export. The measuring/exporting code supplies:

- CPU counters from `getrusage(RUSAGE_SELF)`: cumulative user CPU seconds plus
  system CPU seconds for the same process. For consecutive readings, export
  `cpu_percent = 100 * delta_cpu_seconds / delta_monotonic_elapsed_seconds`.
  Elapsed time must increase; CPU counters must not decrease. Never difference
  counters across processes, restarts or counter resets. Values above 100 are
  valid; 100% is one core. `--cpu-basis machine` is rejected for this source.
- An absent `cpu_percent` (empty CSV cell or JSON `null`) on the first sample of
  each process capture: no prior interval exists. Include that initial sample;
  the reducer validates its absence across all files in the run/scenario/source
  group, sorted chronologically by PID. Use a separate run ID for a restarted
  capture or reused PID. Later unavailable intervals stay absent, never zero.
  Changing phase does not restart a process's CPU interval history.
- RSS from `task_info`'s `resident_size`, in bytes, without substituting physical
  footprint or converting a byte value as if it were KiB.
- Wall timestamps from the recorded wall-clock run start plus measured
  monotonic elapsed time. Label CPU intervals by their end timestamp/phase; an
  interval can span a phase transition. An `open` tag describes the requested
  phase and does not establish visible, active, key-window or animation state.
- Only the owned `App` role. This contract does not attribute WebContent or GPU
  processes and provides no energy-impact measurement. Non-App rows and any
  supplied energy value, including zero, are rejected. Do not insert synthetic
  rows or numeric zeros for missing roles/metrics.

The CSV/JSONL contains exported interval percentages, not raw cumulative CPU or
monotonic counters. The reducer preserves supplied values; it cannot verify
the exporter's deltas, clock provenance or subject attribution, and does not
recompute CPU from wall timestamps. Each native input's JSON `sourceContract`
records the API, CPU, memory, timestamp and missing-data semantics; Markdown
prints the same versioned contract alongside the input hash/source label.

```sh
python3 scripts/u11a-aggregate.py \
  --input native-self-counters=scripts/testdata/u11a/synthetic-native.csv \
  --output-dir .tmp/u11a-native-example
```

App-only data cannot establish a combined App/WebContent/GPU budget. Without
after-close or repeated-cycle measurements those memory results remain
unsupported too; an interrupted run is not evidence of a complete measurement.
The tool produces statistics, not a pass/fail budget decision.

## Calculations and missing data

For each role/phase, processes sharing an **exact normalized timestamp** are
summed into one role snapshot before statistics. The exporter must stamp each
complete process batch with the same timestamp; no resampling or interpolation
across process timestamps is performed. Only the supplied processes are known;
the exporter is responsible for complete, correct subject attribution.

If any process in a role snapshot lacks a metric, that snapshot's total for that
metric is unavailable, rather than the sum of an incomplete subset. Available
snapshots produce the arithmetic average, p50, p90 and peak. Percentiles use
linear interpolation at `(n - 1) * p`; a single observation has identical
percentiles and peak. Statistics are **sample-weighted, not time-weighted**;
irregular sampling does not imply a time-average or energy integral. Counts of
process rows, snapshots, available values and missing totals remain explicit,
along with each phase's first/last observed UTC timestamps and each cycle end's
timestamp. These bounds do not claim continuous sampling between observations.
Status is `available`, `partial`, or `unsupported`. Unavailable statistics are
JSON `null` and printed as `unsupported` in Markdown. Markdown rounds display
numbers to six significant digits; JSON retains numeric results.

The after-close RSS delta is `mean(after-close) - mean(before-open)`, calculated
separately for each role/run/scenario/tool. A missing baseline or after-close
measurement, or baseline timestamps not preceding close timestamps, yields
`unsupported`. Partial windows yield an explicitly partial delta. No first-open
sample is silently reused as a pre-open baseline. Signed deltas can be negative.

Repeated-cycle output includes each cycle's RSS statistics and **last measured
RSS snapshot**, the last-minus-first endpoint growth in bytes and that delta
divided by the cycle-number difference (`bytesPerCycle`). This is an endpoint
slope, not a fitted trend or leak verdict. It does not claim the last sample is
post-close unless the sampler arranged it that way. Missing cycle tags, fewer
than two cycles, missing cycle-end RSS or overlapping/nonchronological cycle
windows yield unsupported growth. Budgets and measurement validity remain the
measurement owner's decisions.

## Synthetic regression checks

```sh
mkdir -p .tmp
TMPDIR="$PWD/.tmp" python3 -m unittest discover \
  -s scripts/tests -p test_u11a_aggregate.py -v
```

Checks cover role totals, percentiles, measured zeros versus missing energy,
separate variants/tools/runs, provenance hashes, partial process snapshots,
memory deltas/cycles, invalid input, Markdown escaping and the real CLI's JSON
and Markdown output without input modification or report overwrite. Native
checks also cover source provenance, byte units, the initial absent CPU interval
across files/phases/PIDs, and rejection of unsupported roles, energy and CPU basis.
