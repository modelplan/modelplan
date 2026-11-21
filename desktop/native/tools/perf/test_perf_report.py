# SPDX-License-Identifier: MIT
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import perf_report  # noqa: E402


def cold(values):
    lines = []
    for handshake, data in values:
        lines += ["timing launch stage=main uptimeMs=0 sinceStartMs=0",
                  f"timing launch stage=engine-handshake uptimeMs=0 sinceStartMs={handshake}",
                  f"timing launch stage=first-rendered uptimeMs=0 sinceStartMs={data - 5}",
                  f"timing launch stage=first-rendered-with-data uptimeMs=0 sinceStartMs={data}"]
    return "\n".join(lines) + "\n"


def cycles(visible, animation, gone):
    lines = []
    for v, a, g in zip(visible, animation, gone):
        lines += ["timing open stage=request elapsedMs=0", f"timing open stage=window-visible elapsedMs={v}",
                  f"timing open stage=page-rendered elapsedMs={v + 20}", f"timing open stage=animation-complete elapsedMs={a}",
                  "timing close stage=request elapsedMs=0", f"timing close stage=gone elapsedMs={g}"]
    return "\n".join(lines) + "\n"


def cpu(seconds, per):
    return "".join(f"{s} {pid} {pct} {name}\n" for s in range(seconds) for pid, pct, name in per)


class PerfReportTests(unittest.TestCase):
    def directory(self, n=10, idle=60, drop=None):
        d = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(d, ignore_errors=True))
        files = {
            "cold-start.log": cold([(300 + i, 900 + 10 * i) for i in range(n)]),
            "attached.log": cycles([100 + i for i in range(n)], [300 + i for i in range(n)], [200 + i for i in range(n)]),
            "detached.log": cycles([150 + i for i in range(n)], [450 + i for i in range(n)], [250 + i for i in range(n)]),
            "idle-cpu.txt": cpu(idle, [(1, 3.0, "app"), (2, 1.5, "webcontent"), (3, 0.5, "gpu")]),
        }
        for name, text in files.items():
            if name != drop:
                with open(os.path.join(d, name), "w") as handle:
                    handle.write(text)
        return d

    def test_percentile_is_nearest_rank(self):
        self.assertEqual(perf_report.percentile([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 90), 9)
        self.assertEqual(perf_report.percentile([5], 90), 5)
        self.assertEqual(perf_report.percentile([10, 1], 50), 1)

    def test_summary_has_median_p90_and_n_per_section(self):
        result = perf_report.build(self.directory(), cores=10)
        self.assertEqual(result["problems"], [])
        attached = result["sections"]["attached"]["open"]["windowVisible"]
        self.assertEqual((attached["n"], attached["median"], attached["p90"]), (10, 104.5, 108))
        self.assertEqual(result["sections"]["detached"]["open"]["animationComplete"]["max"], 459)
        self.assertEqual(result["sections"]["attached"]["close"]["gone"]["n"], 10)
        data = result["sections"]["coldStart"]["firstRenderedWithData"]
        self.assertEqual((data["n"], data["min"], data["max"]), (10, 900, 990))
        idle = result["sections"]["idleCpu"]
        self.assertEqual((idle["samples"], idle["meanPercent"], idle["maxPercent"]), (60, 5.0, 5.0))

    def test_budgets_are_reported_not_enforced(self):
        result = perf_report.build(self.directory(), cores=10)
        rows = {(r["name"], r["statistic"]): r for r in result["budgetCheck"]}
        self.assertEqual(rows[("attached visible ms", "median")]["status"], "within")
        self.assertEqual(rows[("detached animation ms", "median")]["status"], "over")
        self.assertEqual(rows[("idle CPU %", "mean")]["status"], "within")
        self.assertEqual(result["problems"], [])

    def test_fewer_than_ten_samples_is_a_problem(self):
        result = perf_report.build(self.directory(n=9), cores=10)
        text = " ".join(result["problems"])
        self.assertIn("attached open window-visible: n=9 < 10", text)
        self.assertIn("coldStart first-rendered-with-data: n=9 < 10", text)

    def test_short_idle_and_missing_files_are_problems(self):
        self.assertIn("idle CPU: 30 samples < 60", " ".join(perf_report.build(self.directory(idle=30), cores=10)["problems"]))
        missing = perf_report.build(self.directory(drop="detached.log"), cores=10)
        self.assertIn("detached.log is missing", " ".join(missing["problems"]))

    def test_markdown_table_prints_budgets(self):
        text = perf_report.markdown(perf_report.build(self.directory(), cores=10))
        self.assertIn("| attached open: visible (ms) | 10 | 104.5 | 108 |", text)
        self.assertIn("budget 200", text)
        self.assertIn("report only", text)

    def test_command_line_writes_json_and_markdown_and_fails_on_a_problem(self):
        good = self.directory()
        run = subprocess.run([sys.executable, os.path.join(HERE, "perf_report.py"), "--dir", good, "--cores", "10"], capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stderr)
        with open(os.path.join(good, "perf-summary.json")) as handle:
            self.assertEqual(json.load(handle)["required"], 10)
        self.assertTrue(os.path.exists(os.path.join(good, "perf-summary.md")))
        bad = self.directory(n=3)
        self.assertEqual(subprocess.run([sys.executable, os.path.join(HERE, "perf_report.py"), "--dir", bad], capture_output=True, text=True).returncode, 1)
        self.assertTrue(os.path.exists(os.path.join(bad, "perf-summary.json")))


if __name__ == "__main__":
    unittest.main()
