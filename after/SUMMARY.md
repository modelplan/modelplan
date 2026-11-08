# Test build walkthrough

Source `5ca186259c473d984fd87cfe546cc258ccdcd595`, synthetic profile.

| Step | Status | Reason |
|---|---|---|
| first-run-window | pass |  |
| first-run-done-spotlight | pass |  |
| first-run-after | pass |  |
| status-menu-find | pass |  |
| find-spotlight | pass |  |
| find-after | pass |  |

| Check | Status | Detail |
|---|---|---|
| publication-fresh-profile | info | `{"cockpit": true, "fetchedAfterSeconds": 0.0, "firstReadingSeconds": null, "hud": false, "stateKeys": ["base", "checkedAt", "component", "componentHash", "etag", "lastAttemptAt", "manifestHash", "nextCheckAt", "publicationId", "publishedAt", "verifiedAt"], "unavailableAlert": false, "waitedSeconds":` |
| publication-sync | pass | `{"exit": 0}` |
| launch | pass | `{"firstWindowSeconds": 0.33}` |
| reader-first-reading | fail | `{"seconds": null}` |
| alive-after-walk | pass | `{"exit": null}` |
| widget-ax-frames | pass | `{"mirrored": false}` |
| doctor-readers | pass | `{"exit": 0, "readers": 21, "seconds": 0.04}` |
| reader-refresh-timing | pass | `{"codex": {"admitted": "yes", "beta": false, "consent": "granted", "detected": "yes", "last": "85s", "provider": "codex", "state": "ok", "windows": 2}, "exit": 0, "seconds": 0.05}` |
| quit | pass | `{"exit": 0, "forced": false}` |
| restart-launch | fail | `{"firstReadingSeconds": null, "firstWindowSeconds": 0.34}` |
| restart-first-use-hint | info | `{"newWindowWithin": 15, "seen": false}` |
| restart-no-first-run | pass | `{}` |
| restart-widget-place | fail | `{"after": null, "before": null}` |
| restart-readings | fail | `{"readings": []}` |
| restart-quit | pass | `{"exit": 0, "forced": false}` |
| no-crash-report | pass | `{"reports": []}` |
