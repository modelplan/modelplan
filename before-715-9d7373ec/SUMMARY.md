# Test build walkthrough

Source `9d7373ec4373e6596e8d76517566c37bacde7cd0`, synthetic profile.

| Step | Status | Reason |
|---|---|---|
| first-run-window | pass |  |
| first-run-done | pass |  |
| widget-rest | pass |  |
| widget-hover | pass |  |
| ring-card-map | pass |  |
| drag-carry | pass |  |
| drag-snap | pass |  |
| status-menu-right | pass |  |
| first-use-hint | fail | no new window within 12s |
| widget-shown-again | pass |  |
| help-map | fail | missing ax:help.map.header; off screen: nothing found for ax^:help.map. |
| help-map-dismissed | not-run | needs help-map |
| widget-collapse | pass |  |
| widget-reveal | pass |  |
| widget-collapse-off | pass |  |
| popup-card | pass |  |
| card-third-ring | pass |  |
| card-pointer-away | pass |  |
| card-empty-quota | pass |  |
| card-empty-closed | pass |  |
| cockpit-open | pass |  |
| cockpit-widget-visible | fail | missing ax:dock.grip.0 |
| shutter-closed | pass |  |
| porthole-open | pass |  |
| faders | pass |  |
| porthole-enlarged | pass |  |
| porthole-enlarged-closed | pass |  |
| hud-select | pass |  |
| cockpit-toggle-close | fail | still on screen: label:ModelPlan Cockpit; missing ax:dock.grip.0 |
| cockpit-reopen | pass |  |
| cockpit-detach | pass |  |
| cockpit-drag-title | fail | did not move: window-of:label:ModelPlan Cockpit |
| cockpit-put-back | pass |  |
| cockpit-close | pass |  |
| air-1440x900 | pass |  |
| air-1470x956 | skipped | display 1470x956 not offered here; offered: 1920x1080, 1600x1200, 1600x900, 1344x1008, 1344x756, 1280x960, 1280x720, 1024x768, 1024x576, 960x540, 800x600, 640x480 |
| display-restored | pass |  |

| Check | Status | Detail |
|---|---|---|
| publication-fresh-profile | info | `{"cockpit": true, "fetchedAfterSeconds": 0.0, "firstReadingSeconds": 8.11, "hud": false, "stateKeys": ["base", "checkedAt", "component", "componentHash", "etag", "lastAttemptAt", "manifestHash", "nextCheckAt", "publicationId", "publishedAt", "verifiedAt"], "unavailableAlert": false, "waitedSeconds":` |
| publication-sync | pass | `{"exit": 0}` |
| launch | pass | `{"firstWindowSeconds": 0.4}` |
| reader-first-reading | pass | `{"seconds": 5.51}` |
| alive-after-walk | pass | `{"exit": null}` |
| widget-ax-frames | pass | `{"cards": [{"cardAtPainted": "Codex", "cardAtReported": "Codex", "paintedFrame": [1864.1538461538462, 348.5272291491117, 44, 44], "reportedFrame": [1864.1538461538462, 348.5272291491117, 44, 44], "ring": "Codex"}, {"cardAtPainted": "synthetic-critical", "cardAtReported": "synthetic-critical", "paint` |
| doctor-readers | pass | `{"exit": 0, "readers": 21, "seconds": 0.07}` |
| reader-refresh-timing | pass | `{"codex": {"admitted": "yes", "beta": false, "consent": "granted", "detected": "yes", "last": "33s", "provider": "codex", "state": "unavailable:reader_error", "windows": 0}, "exit": 0, "seconds": 0.07}` |
| quit | pass | `{"exit": 0, "forced": false}` |
| restart-launch | pass | `{"firstReadingSeconds": 5.43, "firstWindowSeconds": 3.19}` |
| restart-first-use-hint | info | `{"newWindowWithin": 15, "seen": true}` |
| restart-no-first-run | pass | `{}` |
| restart-widget-place | pass | `{"after": [0, 174, 90, 347], "before": [0, 174, 90, 347]}` |
| restart-readings | pass | `{"readings": ["0%", "12%", "50%", "80%"]}` |
| restart-quit | pass | `{"exit": 0, "forced": false}` |
| no-crash-report | pass | `{"reports": []}` |
