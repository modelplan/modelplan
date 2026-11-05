# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import tempfile
import json
import unittest
from unittest.mock import patch, MagicMock

spec = importlib.util.spec_from_file_location('idle_cost', Path(__file__).with_name('idle_cost.py'))
idle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(idle)


class IdleCostTests(unittest.TestCase):
    def test_cpu_time_parser_supports_minutes_hours_and_days(self):
        self.assertEqual(idle.cpu_seconds('02:03.50'), 123.5)
        self.assertEqual(idle.cpu_seconds('1:02:03'), 3723)
        self.assertEqual(idle.cpu_seconds('2-01:02:03'), 176523)
        for value in ('', 'nan', '1:60', '-1:20', '1:2:99'):
            with self.subTest(value=value), self.assertRaises(ValueError): idle.cpu_seconds(value)

    def test_compare_known_values_with_explicit_thresholds(self):
        report = idle.assess({'cpu_seconds': 5.0, 'memory_growth_bytes': 100},
                             {'cpu_seconds': 6.0, 'memory_growth_bytes': 100})
        self.assertEqual(report['cpu_seconds']['status'], 'PASS')
        self.assertEqual(report['memory_growth_bytes']['status'], 'PASS')
        self.assertEqual(idle.assess({'cpu_seconds': 7}, {'cpu_seconds': 6})['cpu_seconds']['status'], 'FAIL')

    def test_unknown_missing_and_invalid_metrics_never_pass(self):
        for metric, threshold in [(None, 10), (0, None), (-1, 10), (float('nan'), 10), (0, -1)]:
            self.assertEqual(idle.assess({'cpu_seconds': metric}, {'cpu_seconds': threshold})['cpu_seconds']['status'], 'NOT_RUN')
        self.assertEqual(idle.overall({'cpu_seconds': {'status': 'PASS'}, 'network': {'status': 'NOT_RUN'}}), 'NOT_RUN')
        self.assertEqual(idle.overall({'cpu_seconds': {'status': 'FAIL'}, 'network': {'status': 'NOT_RUN'}}), 'FAIL')

    def test_sample_identity_and_counter_regression_fail_closed(self):
        first = {'pid': 42, 'start': 'synthetic-a', 'cpu_seconds': 10, 'rss_bytes': 100}
        later = {'pid': 42, 'start': 'synthetic-a', 'cpu_seconds': 12, 'rss_bytes': 150}
        self.assertEqual(idle.delta(first, later), {'cpu_seconds': 2, 'memory_growth_bytes': 50})
        for change in ({'start': 'synthetic-b'}, {'pid': 43}, {'cpu_seconds': 9}):
            with self.subTest(change=change), self.assertRaises(ValueError): idle.delta(first, {**later, **change})

    def test_smoke_never_claims_candidate_or_a_pass(self):
        worker = MagicMock(pid=42); worker.poll.return_value = None
        samples = [{'pid': 42, 'start': 'synthetic', 'cpu_seconds': n, 'rss_bytes': 1024 + n} for n in range(4)]
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(idle.subprocess, 'Popen', return_value=worker), \
             patch.object(idle, 'ps_sample', side_effect=samples), \
             patch.object(idle.time, 'sleep'), \
             patch.object(idle.time, 'monotonic', side_effect=[0, 0, 60, 120, 180, 180]):
            output = Path(directory) / 'receipt.json'
            report = idle.synthetic_smoke(output)
            self.assertEqual(report, json.loads(output.read_text()))
            self.assertEqual(report['sample_count'], 4)
            self.assertFalse(report['acceptance'])
            self.assertEqual(report['status'], 'NOT_RUN')
            self.assertIsNone(report['measurements']['network_requests']['value'])
            worker.terminate.assert_called_once()

    def test_existing_report_is_not_overwritten(self):
        worker = MagicMock(pid=42); worker.poll.return_value = 0
        sample = {'pid': 42, 'start': 'synthetic', 'cpu_seconds': 0, 'rss_bytes': 1024}
        with tempfile.TemporaryDirectory() as directory, \
             patch.object(idle.subprocess, 'Popen', return_value=worker), \
             patch.object(idle, 'ps_sample', return_value=sample), \
             patch.object(idle.time, 'sleep'), \
             patch.object(idle.time, 'monotonic', side_effect=[0, 0, 60, 120, 180, 180]):
            output = Path(directory) / 'receipt.json'; output.write_text('preserve')
            with self.assertRaises(FileExistsError): idle.synthetic_smoke(output)
            self.assertEqual(output.read_text(), 'preserve')

    def test_unavailable_wakeups_are_unknown(self):
        with patch.object(idle.platform, 'system', return_value='Linux'):
            self.assertIsNone(idle.wakeups_for(42))
        with patch.object(idle.platform, 'system', return_value='Darwin'), patch.object(idle.ctypes, 'CDLL', side_effect=OSError):
            self.assertIsNone(idle.wakeups_for(42))
