# SPDX-License-Identifier: MIT
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1]
TOOL = SCRIPTS / 'u11a-aggregate.py'
FIXTURES = SCRIPTS / 'testdata/u11a'
spec = importlib.util.spec_from_file_location('u11a_aggregate', TOOL)
aggregate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aggregate)


class AggregatorTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)

    def report(self, inputs=None):
        return aggregate.aggregate(inputs or [('top', FIXTURES / 'synthetic-top.csv')])

    def rows(self, rows):
        path = self.root / 'samples.jsonl'
        path.write_text(''.join(json.dumps(row) + '\n' for row in rows))
        return [('powermetrics', path)]

    def sample(self, **extra):
        return dict(run_id='run', scenario='A', timestamp=0, role='App', phase='open',
                    pid=1, cpu_percent=1, rss_bytes=100, **extra)

    def test_stats_role_totals_memory_deltas_and_cycles(self):
        group = self.report()['groups'][0]
        app = group['roles']['App']
        self.assertEqual(app['phases']['open']['metrics']['cpu_percent'],
                         dict(status='available', count=4, missing=0, average=25,
                              p50=25, p90=37, peak=40))
        self.assertEqual(group['roles']['WebContent']['phases']['open']['metrics']['rss_bytes']['average'], 120)
        self.assertEqual(group['roles']['WebContent']['phases']['open']['metrics']['cpu_percent']['average'], 12)
        self.assertEqual(app['afterCloseDelta']['bytes'], 20)
        self.assertEqual(app['repeatedCycleGrowth']['bytes'], 25)
        self.assertEqual(app['repeatedCycleGrowth']['bytesPerCycle'], 12.5)
        self.assertEqual([c['rssEndBytes'] for c in app['repeatedCycleGrowth']['cycles']], [125, 140, 150])

    def test_file_hashes_and_tools_do_not_pool_scenarios(self):
        inputs = [('top', FIXTURES / 'synthetic-top.csv'),
                  ('instruments', FIXTURES / 'synthetic-instruments.jsonl')]
        report = self.report(inputs)
        self.assertEqual([(g['scenario'], g['tool']) for g in report['groups']], [('A', 'top'), ('B', 'instruments')])
        energy = report['groups'][1]['roles']['App']['phases']['open']['metrics']['energy_impact']
        self.assertEqual((energy['average'], energy['p50'], energy['p90'], energy['peak']), (8, 8, 9.6, 10))
        for source, (tool, path) in zip(report['inputs'], inputs):
            self.assertEqual(source['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertEqual(source['tool'], tool)
            self.assertNotIn(str(path.parent), json.dumps(source))

    def test_missing_energy_and_baseline_are_not_zero(self):
        group = self.report()['groups'][0]
        app = group['roles']['App']
        self.assertEqual(app['phases']['open']['metrics']['energy_impact']['status'], 'unsupported')
        self.assertIsNone(app['phases']['open']['metrics']['energy_impact']['average'])
        self.assertEqual(group['roles']['GPU']['phases']['open']['metrics']['rss_bytes']['average'], 0)
        self.assertEqual(group['roles']['GPU']['afterCloseDelta']['status'], 'unsupported')
        self.assertIsNone(group['roles']['GPU']['afterCloseDelta']['bytes'])

    def test_partial_process_snapshots_are_not_undercounted(self):
        first = self.sample()
        missing = {**first, 'pid': 2, 'rss_bytes': None}
        later = [{**first, 'timestamp': 1, 'rss_bytes': 110},
                 {**first, 'timestamp': 1, 'pid': 2, 'rss_bytes': 50}]
        report = self.report(self.rows([first, missing, *later]))
        rss = report['groups'][0]['roles']['App']['phases']['open']['metrics']['rss_bytes']
        self.assertEqual((rss['status'], rss['count'], rss['missing'], rss['average']), ('partial', 1, 1, 160))

    def test_missing_cycle_labels_or_endpoints_are_unsupported(self):
        row = {**self.sample(), 'phase': 'repeated-open-close'}
        report = self.report(self.rows([row]))
        self.assertEqual(report['groups'][0]['roles']['App']['repeatedCycleGrowth']['status'], 'unsupported')
        rows = [{**row, 'cycle': 1}, {**row, 'timestamp': 1, 'cycle': 2, 'rss_bytes': None}]
        report = self.report(self.rows(rows))
        self.assertIsNone(report['groups'][0]['roles']['App']['repeatedCycleGrowth']['bytes'])

    def test_invalid_samples_and_duplicates_fail(self):
        for change in ({'cpu_percent': -1}, {'rss_bytes': 1.5}, {'energy_impact': float('nan')},
                       {'role': 'unrelated'}, {'phase': 'unknown'}, {'pid': 0}, {'cycle': 0},
                       {'timestamp': '2026-01-01T00:00:00'}, {'rss_bytes': True}, {'extra': 'unknown'}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.report(self.rows([{**self.sample(), **change}]))
        with self.assertRaises(ValueError):
            self.report(self.rows([self.sample(), self.sample()]))
        self.assertEqual(self.report(self.rows([{**self.sample(), 'cpu_percent': 250}]))['groups'][0]
                         ['roles']['App']['phases']['open']['metrics']['cpu_percent']['average'], 250)

    def test_nonchronological_windows_cannot_claim_memory_growth(self):
        row = self.sample()
        rows = [{**row, 'timestamp': 2, 'phase': 'before-open'},
                {**row, 'timestamp': 1, 'phase': 'after-close', 'rss_bytes': 150},
                {**row, 'timestamp': 4, 'phase': 'repeated-open-close', 'cycle': 1},
                {**row, 'timestamp': 3, 'phase': 'repeated-open-close', 'cycle': 2}]
        role = self.report(self.rows(rows))['groups'][0]['roles']['App']
        self.assertEqual(role['afterCloseDelta']['status'], 'unsupported')
        self.assertIsNone(role['repeatedCycleGrowth']['bytes'])

    def test_tools_runs_and_cpu_conventions_stay_explicit(self):
        path = self.rows([self.sample()])[0][1]
        report = aggregate.aggregate([('top', path), ('powermetrics', path)], 'machine')
        self.assertEqual(report['cpuBasis'], 'machine')
        self.assertEqual(len(report['groups']), 2)
        rows = [self.sample(), {**self.sample(), 'run_id': 'separate-run'}]
        self.assertEqual(len(self.report(self.rows(rows))['groups']), 2)

    def test_native_source_preserves_intervals_and_missing_roles(self):
        path = FIXTURES / 'synthetic-native.csv'
        report = self.report([('native-self-counters', path)])
        source = report['inputs'][0]
        self.assertEqual(source['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
        self.assertEqual(source['sourceContract']['version'], 1)
        self.assertIn('getrusage', source['sourceContract']['cpuCounter'])
        self.assertIn('task_info', source['sourceContract']['rssCounter'])
        roles = report['groups'][0]['roles']
        baseline = roles['App']['phases']['before-open']['metrics']['cpu_percent']
        self.assertEqual((baseline['status'], baseline['count'], baseline['missing'], baseline['average']),
                         ('partial', 1, 1, 2))
        opened = roles['App']['phases']['open']['metrics']
        self.assertEqual(opened['cpu_percent']['average'], 6)  # First open interval is retained.
        self.assertEqual(opened['rss_bytes']['average'], 1300000)  # Bytes, no unit conversion.
        self.assertIsNone(opened['energy_impact']['average'])
        for role in ('WebContent', 'GPU'):
            for phase in roles[role]['phases'].values():
                self.assertEqual(phase['processSamples'], 0)
                for metric in phase['metrics'].values():
                    self.assertEqual(metric['status'], 'unsupported')
                    for key in ('average', 'p50', 'p90', 'peak'):
                        self.assertIsNone(metric[key])
        self.assertIsNone(roles['App']['afterCloseDelta']['bytes'])
        self.assertIsNone(roles['App']['repeatedCycleGrowth']['bytes'])
        text = aggregate.markdown(report)
        self.assertIn('Native self-counter export contract v1', text)
        self.assertIn('not recomputed from wall timestamps', text)

    def test_native_source_rejects_false_attribution_energy_and_cpu_basis(self):
        first = {**self.sample(), 'cpu_percent': None}
        for change in ({'role': 'WebContent'}, {'role': 'GPU'}, {'energy_impact': 0}, {'cpu_percent': 0}):
            path = self.rows([{**first, **change}])[0][1]
            with self.subTest(change=change), self.assertRaises(ValueError):
                aggregate.aggregate([('native-self-counters', path)])
        with self.assertRaisesRegex(ValueError, 'one-core'):
            aggregate.aggregate([('native-self-counters', FIXTURES / 'synthetic-native.csv')], 'machine')

    def test_native_first_interval_per_capture_across_files_phases_and_pids(self):
        first = {**self.sample(), 'cpu_percent': None}
        path = self.rows([{**first, 'phase': 'before-open'}])[0][1]
        other = self.root / 'later.jsonl'
        later = [{**self.sample(), 'timestamp': 1, 'cpu_percent': 0},
                 {**first, 'timestamp': 2, 'pid': 2},
                 {**self.sample(), 'timestamp': 3, 'pid': 2, 'cpu_percent': 200}]
        other.write_text(''.join(json.dumps(row) + '\n' for row in reversed(later)))
        report = self.report([('native-self-counters', other), ('native-self-counters', path)])
        cpu = report['groups'][0]['roles']['App']['phases']['open']['metrics']['cpu_percent']
        self.assertEqual((cpu['count'], cpu['missing'], cpu['average'], cpu['peak']), (2, 1, 100, 200))
        # A new process must supply its initial unavailable interval too.
        other.write_text(json.dumps(later[-1]) + '\n')
        with self.assertRaisesRegex(ValueError, 'absent first CPU interval'):
            self.report([('native-self-counters', path), ('native-self-counters', other)])

    def test_native_cli_outputs_contract_without_modifying_input(self):
        source = FIXTURES / 'synthetic-native.csv'
        original = source.read_bytes()
        output = self.root / 'native-report'
        result = subprocess.run([sys.executable, str(TOOL), '--input', 'native-self-counters=' + str(source),
                                 '--output-dir', str(output)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads((output / 'report.json').read_text())
        self.assertEqual(report['inputs'][0]['tool'], 'native-self-counters')
        self.assertEqual(report['inputs'][0]['sourceContract']['energyImpact'], 'unsupported')
        self.assertIn(report['inputs'][0]['sha256'], (output / 'report.md').read_text())
        self.assertEqual(original, source.read_bytes())

    def test_bad_csv_json_and_empty_inputs_fail_without_reports(self):
        for text in ('', '{"role":"App","role":"GPU"}\n', '[1,2]\n', '{broken\n'):
            path = self.root / 'bad.jsonl'
            path.write_text(text)
            with self.assertRaises(ValueError):
                aggregate.aggregate([('top', path)])
        path = self.root / 'bad.csv'
        path.write_text('run_id,run_id\nA,B\n')
        output = self.root / 'bad-report'
        result = subprocess.run([sys.executable, str(TOOL), '--input', 'top=' + str(path),
                                 '--output-dir', str(output)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(output.exists())

    def test_markdown_escapes_sample_labels(self):
        report = self.report(self.rows([{**self.sample(), 'scenario': '<b>|`injected`'}]))
        text = aggregate.markdown(report)
        self.assertIn('&lt;b&gt;\\|\\`injected\\`', text)
        self.assertNotIn('<b>', text)

    def test_cli_writes_both_formats_without_changing_inputs_or_overwriting(self):
        source = FIXTURES / 'synthetic-top.csv'
        before = source.read_bytes()
        output = self.root / 'report'
        command = [sys.executable, str(TOOL), '--input', 'top=' + str(source), '--output-dir', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads((output / 'report.json').read_text())
        markdown = (output / 'report.md').read_text()
        self.assertIn(report['inputs'][0]['sha256'], markdown)
        self.assertIn('unsupported', markdown)
        self.assertIn('after-close', markdown)
        self.assertEqual(source.read_bytes(), before)
        saved = (output / 'report.json').read_bytes()
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertEqual((output / 'report.json').read_bytes(), saved)


if __name__ == '__main__':
    unittest.main()
