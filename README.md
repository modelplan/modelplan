# #690 first-run front evidence (evidence only, never merge)

Hosted macOS 15 runner (GitHub-hosted, 1920x1080 at 1x), synthetic profile, fresh HOME. System Settings is
opened and frontmost first, then the packaged owner-test app is started by direct exec (no LaunchServices
activation), as after "Open Anyway". Shot 2 s after the first-run page appears. Branch c/690-front-probe,
script desktop/native/verification/walkthrough/front_probe.py there.

- before/: main base 1ae94db5 (run 42445292663): the first-run window opens behind System Settings.
- after-activate-only/: #690 at 9182c594 (run 42445281056): identical; activate() is ignored while another app is active.
- after/: #690 at 5a2519fc (run 42446281442): the window is ordered above System Settings; System Settings stays the active app (no focus taken).

Limits: hosted runner, not the owner's Mac; app started by exec, not by Finder or "Open Anyway"; no Gatekeeper prompt.
