# Test build walkthrough

Source `f8f022b3beba706cf7a4de1feeef4a9a78d121ae`, synthetic profile.

| Step | Status | Reason |
|---|---|---|
| first-run-window | pass |  |
| first-run-done-spotlight | pass |  |
| first-run-after | pass |  |
| status-menu-find | fail | not on screen: ax:status.findQuotaWidget |
| find-spotlight | not-run | needs status-menu-find |
| find-after | not-run | needs find-spotlight |

| Check | Status | Detail |
|---|---|---|
| publication-fresh-profile | info | `{"cockpit": false, "fetchedAfterSeconds": 0.0, "firstReadingSeconds": 7.15, "hud": false, "stateKeys": ["base", "checkedAt", "component", "componentHash", "etag", "lastAttemptAt", "manifestHash", "nextCheckAt", "publicationId", "publishedAt", "verifiedAt"], "unavailableAlert": false, "waitedSeconds"` |
| publication-sync | pass | `{"exit": 0}` |
| launch | pass | `{"firstWindowSeconds": 0.39}` |
| reader-first-reading | pass | `{"seconds": 4.07}` |
| alive-after-walk | pass | `{"exit": null}` |
| widget-ax-frames | pass | `{"mirrored": false}` |
| doctor-readers | pass | `{"exit": 0, "readers": 21, "seconds": 0.06}` |
| reader-refresh-timing | pass | `{"codex": {"admitted": "yes", "beta": false, "consent": "granted", "detected": "yes", "last": "37s", "provider": "codex", "state": "ok", "windows": 2}, "exit": 0, "seconds": 0.07}` |
| quit | pass | `{"exit": 0, "forced": false}` |
| restart-launch | pass | `{"firstReadingSeconds": 5.07, "firstWindowSeconds": 0.4}` |
| restart-first-use-hint | info | `{"newWindowWithin": 15, "seen": false}` |
| restart-no-first-run | pass | `{}` |
| restart-widget-place | pass | `{"after": [1830, 336, 90, 347], "before": [1830, 336, 90, 347]}` |
| restart-readings | pass | `{"readings": ["12%", "41%", "50%", "80%"]}` |
| restart-quit | pass | `{"exit": 0, "forced": false}` |
| no-crash-report | pass | `{"reports": []}` |
