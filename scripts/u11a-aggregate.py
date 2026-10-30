#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Aggregate tagged U11a process samples; never collect or infer measurements."""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import html
import io
import json
import math
from pathlib import Path
import statistics

ROLES = ('App', 'WebContent', 'GPU')
PHASES = ('before-open', 'open', 'idle', 'after-close', 'repeated-open-close')
NATIVE_SOURCE = 'native-self-counters'
TOOLS = ('powermetrics', 'top', 'instruments', NATIVE_SOURCE)
NATIVE_CONTRACT = {
    'version': 1,
    'scope': 'owned App process only; no WebContent or GPU attribution',
    'cpuCounter': 'getrusage(RUSAGE_SELF): cumulative user + system CPU seconds',
    'cpuExport': '100 * delta CPU seconds / delta monotonic elapsed seconds; 100% is one core',
    'firstCpuInterval': 'absent per process capture; no prior interval',
    'rssCounter': 'task_info resident_size, in bytes',
    'energyImpact': 'unsupported',
    'timestamps': 'recorded wall-clock start + monotonic elapsed; interval-end phase',
}
METRICS = ('cpu_percent', 'rss_bytes', 'energy_impact')
REQUIRED = {'run_id', 'scenario', 'timestamp', 'role', 'phase', 'pid'}
FIELDS = REQUIRED | set(METRICS) | {'cycle'}


def numeric(value, integer=False):
    if value is None or value == '':
        return None
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise ValueError('metric/identifier must be numeric, not a boolean or object')
    number = float(value)
    if not math.isfinite(number) or number < 0 or (integer and not number.is_integer()):
        raise ValueError('numbers must be finite, nonnegative and integral where required')
    if integer:
        return value if isinstance(value, int) else int(number)
    return number


def timestamp(value):
    if isinstance(value, bool) or not isinstance(value, (int, float, str)):
        raise ValueError('timestamp must be RFC3339 or Unix seconds')
    try:
        seconds = float(value)
    except ValueError:
        date = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if date.utcoffset() is None:
            raise ValueError('timestamps require an explicit timezone')
        seconds = date.timestamp()
    if not math.isfinite(seconds):
        raise ValueError('timestamp must be finite')
    datetime.fromtimestamp(seconds, timezone.utc)  # Reject out-of-range times.
    return seconds


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate JSON key')
        result[key] = value
    return result


def utc(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat().replace('+00:00', 'Z')


def read_samples(tool, path):
    if tool not in TOOLS:
        raise ValueError('tool must be one of: ' + ', '.join(TOOLS))
    path = Path(path)
    raw = path.read_bytes()
    text = raw.decode('utf-8-sig')
    if path.suffix.lower() == '.csv':
        reader = csv.DictReader(io.StringIO(text), strict=True)
        headers = reader.fieldnames or []
        if len(set(headers)) != len(headers) or not REQUIRED <= set(headers) or set(headers) - FIELDS:
            raise ValueError(f'{path.name}: invalid CSV header')
        records = list(reader)
        if any(None in row or any(v is None for v in row.values()) for row in records):
            raise ValueError(f'{path.name}: inconsistent CSV row width')
    elif path.suffix.lower() == '.jsonl':
        records = [json.loads(line, object_pairs_hook=unique_object) for line in text.splitlines() if line.strip()]
    else:
        raise ValueError('input extension must be .csv or .jsonl')
    if not records:
        raise ValueError(f'{path.name}: no samples')
    normalized = []
    for index, row in enumerate(records, 1):
        try:
            if not isinstance(row, dict) or not REQUIRED <= row.keys() or row.keys() - FIELDS:
                raise ValueError('missing or unknown sample fields')
            for field in ('run_id', 'scenario'):
                if not isinstance(row[field], str) or not row[field].strip() or any(ord(c) < 32 for c in row[field]):
                    raise ValueError('run_id and scenario must be nonempty single-line strings')
            if row['role'] not in ROLES or row['phase'] not in PHASES:
                raise ValueError('unknown role or phase')
            sample = {key: row[key] for key in ('run_id', 'scenario', 'role', 'phase')}
            sample.update(timestamp=timestamp(row['timestamp']), pid=numeric(row['pid'], True),
                          cycle=numeric(row.get('cycle'), True))
            if not sample['pid'] or sample['cycle'] == 0:
                raise ValueError('pid and any cycle must be positive integers')
            if sample['cycle'] is not None and row['phase'] != 'repeated-open-close':
                raise ValueError('cycle tags belong to repeated-open-close samples')
            sample.update({metric: numeric(row.get(metric), metric == 'rss_bytes') for metric in METRICS})
            if tool == NATIVE_SOURCE:
                if sample['role'] != 'App':
                    raise ValueError('native-self-counters supports only the owned App role')
                if sample['energy_impact'] is not None:
                    raise ValueError('native-self-counters does not measure energy impact')
            normalized.append(sample)
        except (ValueError, TypeError, OverflowError) as exc:
            raise ValueError(f'{path.name}: sample {index}: {exc}') from exc
    source = {'name': path.name, 'tool': tool, 'sha256': hashlib.sha256(raw).hexdigest(),
              'samples': len(normalized)}
    if tool == NATIVE_SOURCE:
        source['sourceContract'] = dict(NATIVE_CONTRACT)
    return normalized, source


def stats(values):
    present = sorted(v for v in values if v is not None)
    count, missing = len(present), len(values) - len(present)

    def percentile(fraction):
        position = (count - 1) * fraction
        lower = int(position)
        return present[lower] + (present[math.ceil(position)] - present[lower]) * (position - lower)

    return {'status': 'unsupported' if not count else 'partial' if missing else 'available',
            'count': count, 'missing': missing,
            'average': statistics.fmean(present) if count else None,
            'p50': percentile(.5) if count else None, 'p90': percentile(.9) if count else None,
            'peak': present[-1] if count else None}


def snapshots(samples):
    batches = {}
    cycle_at = {}
    for row in samples:
        if row['timestamp'] in cycle_at and cycle_at[row['timestamp']] != row['cycle']:
            raise ValueError('conflicting cycle tags in one role timestamp')
        cycle_at[row['timestamp']] = row['cycle']
        batches.setdefault((row['timestamp'], row['cycle']), []).append(row)
    result = []
    for (at, cycle), rows in sorted(batches.items(), key=lambda item: item[0][0]):
        totals = {'timestamp': at, 'cycle': cycle}
        for metric in METRICS:
            values = [row[metric] for row in rows]
            totals[metric] = sum(values) if all(v is not None for v in values) else None
            if totals[metric] is not None and not math.isfinite(totals[metric]):
                raise ValueError('role total is out of numeric range')
        result.append(totals)
    return result


def cycle_growth(repeated):
    cycles = []
    windows = []
    for cycle in sorted({s['cycle'] for s in repeated if s['cycle'] is not None}):
        samples = [s for s in repeated if s['cycle'] == cycle]
        cycles.append({'cycle': cycle, 'rssEndBytes': samples[-1]['rss_bytes'],
                       'endTimestamp': utc(samples[-1]['timestamp']),
                       'rss': stats([s['rss_bytes'] for s in samples])})
        windows.append((samples[0]['timestamp'], samples[-1]['timestamp']))
    reason = None
    if any(s['cycle'] is None for s in repeated):
        reason = 'missing cycle tags'
    elif len(cycles) < 2:
        reason = 'at least two cycles required'
    elif any(c['rssEndBytes'] is None for c in cycles):
        reason = 'missing cycle-end RSS'
    elif any(left[1] >= right[0] for left, right in zip(windows, windows[1:])):
        reason = 'cycle windows overlap or are not chronological'
    result = {'status': 'unsupported' if reason else 'available', 'reason': reason,
              'cycles': cycles, 'bytes': None, 'bytesPerCycle': None}
    if not reason:
        result['bytes'] = cycles[-1]['rssEndBytes'] - cycles[0]['rssEndBytes']
        result['bytesPerCycle'] = result['bytes'] / (cycles[-1]['cycle'] - cycles[0]['cycle'])
    return result


def aggregate(inputs, cpu_basis='one-core'):
    if cpu_basis not in ('one-core', 'machine'):
        raise ValueError('unknown CPU basis')
    sources, grouped, seen = [], {}, set()
    for tool, path in inputs:
        if tool == NATIVE_SOURCE and cpu_basis != 'one-core':
            raise ValueError('native-self-counters requires the one-core CPU basis')
        samples, source = read_samples(tool, path)
        sources.append(source)
        for row in samples:
            group = (row['run_id'], row['scenario'], tool)
            key = (*group, row['role'], row['phase'], row['cycle'], row['timestamp'], row['pid'])
            if key in seen:
                raise ValueError('duplicate process sample, including across input files')
            seen.add(key)
            grouped.setdefault(group, []).append(row)
    if not sources:
        raise ValueError('at least one input is required')
    groups = []
    for (run_id, scenario, tool), rows in sorted(grouped.items()):
        if tool == NATIVE_SOURCE:
            first_by_pid = {}
            for row in sorted(rows, key=lambda row: row['timestamp']):
                first_by_pid.setdefault(row['pid'], row)
            if any(row['cpu_percent'] is not None for row in first_by_pid.values()):
                raise ValueError('native-self-counters requires an absent first CPU interval per process capture')
        roles = {}
        for role in ROLES:
            phases, batches = {}, {}
            for phase in PHASES:
                phase_rows = [s for s in rows if s['role'] == role and s['phase'] == phase]
                batches[phase] = snapshots(phase_rows)
                phases[phase] = {'processSamples': len(phase_rows), 'snapshots': len(batches[phase]),
                                 'firstTimestamp': utc(batches[phase][0]['timestamp']) if phase_rows else None,
                                 'lastTimestamp': utc(batches[phase][-1]['timestamp']) if phase_rows else None,
                                 'metrics': {m: stats([s[m] for s in batches[phase]]) for m in METRICS}}
            before = phases['before-open']['metrics']['rss_bytes']
            after = phases['after-close']['metrics']['rss_bytes']
            reason = None
            if not before['count'] or not after['count']:
                reason = 'missing before-open or after-close RSS'
            elif batches['before-open'][-1]['timestamp'] >= batches['after-close'][0]['timestamp']:
                reason = 'baseline must precede after-close samples'
            supported = reason is None
            delta = {'status': ('partial' if 'partial' in (before['status'], after['status']) else 'available')
                     if supported else 'unsupported', 'reason': reason, 'beforeOpenAverageBytes': before['average'],
                     'afterCloseAverageBytes': after['average'],
                     'bytes': after['average'] - before['average'] if supported else None}
            roles[role] = {'phases': phases, 'afterCloseDelta': delta,
                           'repeatedCycleGrowth': cycle_growth(batches['repeated-open-close'])}
        groups.append({'runId': run_id, 'scenario': scenario, 'tool': tool, 'roles': roles})
    return {'schemaVersion': 1, 'cpuBasis': cpu_basis, 'memoryBasis': 'RSS bytes',
            'energyBasis': 'tool-specific energy impact; no conversion or cross-tool pooling',
            'statistics': 'sample-weighted role totals; linear percentiles at (n-1)*p',
            'inputs': sources, 'groups': groups}


def markdown(report):
    def escape(value):
        return html.escape(str(value)).replace('\\', '\\\\').replace('|', '\\|').replace('`', '\\`')

    def number(value):
        return 'unsupported' if value is None else f'{value:.6g}'

    lines = ['# U11a measurement summary', '',
             f"CPU basis: {report['cpuBasis']}; memory: RSS bytes. Energy impact stays tool-specific.",
             'Sample-weighted role totals; p50/p90 use linear interpolation. No budget verdict is inferred.', '',
             '| Input | Tool | SHA-256 | Process samples |', '|---|---|---|---:|']
    for source in report['inputs']:
        lines.append(f"| {escape(source['name'])} | {source['tool']} | {source['sha256']} | {source['samples']} |")
    if any(source['tool'] == NATIVE_SOURCE for source in report['inputs']):
        lines += ['', 'Native self-counter export contract v1:']
        lines += [f'- {key}: {escape(value)}' for key, value in NATIVE_CONTRACT.items() if key != 'version']
        lines += ['CPU percentages are supplied interval deltas, not recomputed from wall timestamps. '
                  'Raw cumulative counters are not supplied or independently verified by this reducer.', '']
    for group in report['groups']:
        lines += ['', f"## {escape(group['runId'])} / {escape(group['scenario'])} / {group['tool']}", '',
                  '| Role | Phase | Metric | Status | Count | Missing | Average | p50 | p90 | Peak |',
                  '|---|---|---|---|---:|---:|---:|---:|---:|---:|']
        for role, data in group['roles'].items():
            for phase, values in data['phases'].items():
                for metric, s in values['metrics'].items():
                    fields = [role, phase, metric, s['status'], str(s['count']), str(s['missing'])]
                    fields += [number(s[key]) for key in ('average', 'p50', 'p90', 'peak')]
                    lines.append('| ' + ' | '.join(fields) + ' |')
        lines += ['', '### Memory deltas', '',
                  'after-close delta = mean(after-close RSS) − mean(before-open RSS).',
                  'Cycle growth uses the last RSS snapshot of each repeated-open-close cycle, not an inferred close.', '',
                  '| Role | After-close status | Delta bytes | Cycle status | Growth bytes | Bytes/cycle | Cycle ends (bytes) | Reason if unsupported |',
                  '|---|---|---:|---|---:|---:|---|---|']
        for role, data in group['roles'].items():
            delta, growth = data['afterCloseDelta'], data['repeatedCycleGrowth']
            ends = ', '.join(f"{c['cycle']}: {number(c['rssEndBytes'])}" for c in growth['cycles'])
            reasons = '; '.join(filter(None, (delta['reason'], growth['reason'])))
            lines.append(f"| {role} | {delta['status']} | {number(delta['bytes'])} | {growth['status']} | "
                         f"{number(growth['bytes'])} | {number(growth['bytesPerCycle'])} | {ends or 'unsupported'} | {reasons} |")
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', action='append', required=True, metavar='TOOL=FILE')
    parser.add_argument('--cpu-basis', choices=('one-core', 'machine'), default='one-core')
    parser.add_argument('--output-dir', type=Path, required=True, help='new directory; never overwrite a report')
    args = parser.parse_args()
    try:
        inputs = []
        for value in args.input:
            tool, separator, path = value.partition('=')
            if not separator or not path:
                raise ValueError('--input requires TOOL=FILE')
            inputs.append((tool, Path(path)))
        report = aggregate(inputs, args.cpu_basis)
        json_text = json.dumps(report, indent=2, allow_nan=False) + '\n'
        md_text = markdown(report)
        args.output_dir.mkdir()  # Exclusive; parse/validate before creating output.
        (args.output_dir / 'report.json').write_text(json_text, encoding='utf-8')
        (args.output_dir / 'report.md').write_text(md_text, encoding='utf-8')
    except (ValueError, OSError, csv.Error, OverflowError) as exc:
        parser.exit(2, f'Aggregation failed: {exc}\n')
    print('Wrote report.json and report.md')


if __name__ == '__main__':
    main()
