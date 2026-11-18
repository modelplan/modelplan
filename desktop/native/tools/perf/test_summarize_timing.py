# SPDX-License-Identifier: MIT
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import summarize_timing  # noqa: E402

LOG = """\
2026-11-18T10:00:00.000-08:00 notice [lifecycle] timing launch stage=main uptimeMs=1000 sinceStartMs=120
2026-11-18T10:00:00.100-08:00 notice [lifecycle] timing launch stage=engine-spawn uptimeMs=1100 sinceStartMs=220
2026-11-18T10:00:00.200-08:00 notice [lifecycle] timing launch stage=bundle-verified uptimeMs=1200 sinceStartMs=320 ms=80 files=1046 bytes=9200000
2026-11-18T10:00:00.300-08:00 notice [lifecycle] timing launch stage=first-reading.codex uptimeMs=1300 sinceStartMs=420
2026-11-18T10:00:00.400-08:00 notice [cockpit] timing page stage=navigation-finish loadMs=150 files=40 verifyMs=30
2026-11-18T10:00:01.000-08:00 notice [cockpit] timing open stage=request elapsedMs=0
2026-11-18T10:00:01.010-08:00 notice [cockpit] timing open stage=window-start elapsedMs=10
2026-11-18T10:00:01.020-08:00 notice [cockpit] timing open page=warm-ready clickMs=12
2026-11-18T10:00:01.300-08:00 notice [cockpit] timing open stage=animation-complete elapsedMs=500
2026-11-18T10:00:02.000-08:00 notice [cockpit] timing close stage=request elapsedMs=0
2026-11-18T10:00:02.100-08:00 notice [cockpit] timing close stage=gone elapsedMs=540
2026-11-18T10:00:03.000-08:00 notice [cockpit] timing open stage=request elapsedMs=0
2026-11-18T10:00:03.010-08:00 notice [cockpit] timing open stage=window-start elapsedMs=4
2026-11-18T10:00:03.300-08:00 notice [cockpit] timing open stage=animation-complete elapsedMs=520
2026-11-18T10:00:03.400-08:00 notice [cockpit] timing open stage=animation-complete elapsedMs=900
2026-11-18T10:00:09.000-08:00 notice [lifecycle] timing launch stage=main uptimeMs=9000 sinceStartMs=100
2026-11-18T10:00:09.300-08:00 notice [lifecycle] timing launch stage=engine-spawn uptimeMs=9300 sinceStartMs=400
2026-11-18T10:00:09.400-08:00 notice [lifecycle] timing launch stage=engine-spawn uptimeMs=9400 sinceStartMs=999
2026-11-18T10:00:09.500-08:00 notice [lifecycle] timing launch stage=bundle-verified uptimeMs=9500 sinceStartMs=500 ms=90 files=1046 bytes=9200000
modelplan-cockpit some unrelated line
"""


class SummarizeTimingTests(unittest.TestCase):
    def setUp(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".log", delete=False)
        handle.write(LOG)
        handle.close()
        self.path = handle.name
        self.addCleanup(os.unlink, self.path)

    def rows(self, group):
        return {r["stage"]: r for r in summarize_timing.summarize([self.path])[group]}

    def test_cold_start_runs_split_at_main_and_keep_the_first_line(self):
        launch = self.rows("launch")
        self.assertEqual(launch["main"], {"stage": "main", "n": 2, "min": 100, "median": 110, "max": 120})
        self.assertEqual(launch["engine-spawn"]["max"], 400)
        self.assertEqual(launch["bundle-verified ms"]["median"], 85)
        self.assertEqual(launch["first-reading.codex"]["n"], 1)

    def test_open_and_close_cycles(self):
        opened = self.rows("open")
        self.assertEqual(opened["window-start"]["n"], 2)
        self.assertEqual(opened["animation-complete"]["max"], 520)
        self.assertEqual(opened["legacy page=warm-ready"]["min"], 12)
        self.assertEqual(self.rows("close")["gone"]["median"], 540)
        self.assertEqual(self.rows("page")["navigation-finish verifyMs"]["max"], 30)

    def test_render_and_cpu(self):
        text = summarize_timing.render(summarize_timing.summarize([self.path]))
        self.assertIn("## cold start (ms since process start)", text)
        samples = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
        samples.write("1 10 4.0 /Applications/ModelPlan.app/Contents/MacOS/ModelPlan\n"
                      "1 11 2.0 com.apple.WebKit.WebContent\n"
                      "2 10 6.0 /Applications/ModelPlan.app/Contents/MacOS/ModelPlan\n"
                      "2 11 0.0 com.apple.WebKit.WebContent\n")
        samples.close()
        self.addCleanup(os.unlink, samples.name)
        result = summarize_timing.cpu([samples.name], cores=10)
        self.assertEqual(result["samples"], 2)
        self.assertEqual(result["totalMeanPercent"], 6.0)
        self.assertEqual(result["processes"][0], {"command": "ModelPlan", "meanPercent": 5.0, "maxPercent": 6.0})


if __name__ == "__main__":
    unittest.main()
