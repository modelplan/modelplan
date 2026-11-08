# Evidence for #715: cockpit prewarm (G3-42, CKP-SHELL-20, owner D50) (never merge)

Owner report: "驾驶舱打开要两三秒才能加载显示数据 严重问题 需要解决" (the cockpit takes two to three seconds to load and show data; serious, must be fixed).

All runs: `test-build-walkthrough.yml` (PR #683 tool), hosted macos-15, packaged with `--owner-test` (cockpit entry on, normal entry), synthetic profile only.

`secondsTo` is the walkthrough's measure: menu bar click until the page's root (`label:ModelPlan Cockpit`) is found in the accessibility tree, polled every 0.5 s with a full tree dump per poll. It is an upper bound, not click-to-data. `clickMs` is the app's own `modelplan-cockpit timing` line in `app.log`: click (console `show()`) to the page's first render receipt with data.

| Run | Source | First open secondsTo | Reopen secondsTo | First open click-to-data | Reopens click-to-data |
|---|---|---|---|---|---|
| main 42435037360 | cf6c8329 | 4.49 s | 4.29 s | (no log) | (no log) |
| main 42442997103 | ff1b1264 | 6.02 s | 3.00 s | (no log) | (no log) |
| #715 before 42436532158 | 9d7373ec | 3.05 s | 6.47 s | (no log) | (no log) |
| #715 after 42440154294 | 26237d1e | 1.26 s | 1.57 s | 285 ms | 302, 315 ms |
| #715 after 42441303290 | a9f3e290 (main merged) | 2.11 s | 1.70 s | 482 ms | 332, 360 ms |

Intermediate run 42439058778 (47444f01, before every hidden page was warm-painted): 537 ms first open, 1317 and 1330 ms reopens.

Folders hold the cockpit crops at the first open (21) and the reopen (30), the walkthrough SUMMARY.md and app.log. The before-#715 first-use-hint and help-map failures came from that branch predating #702; they pass after merging main. `cockpit-drag-title` fails on main too; `restart-widget-place` fails on current main too.
