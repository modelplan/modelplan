# G3-46 and G3-48 evidence (hosted-runner synthetic images)

Run 42438843168 (workflow `Evidence G3-46 G3-48` on this branch). Synthetic data only, no accounts.

- G3-46: GitHub-hosted macos-15, 1024x768. Production entry (`EngineRowsEntry.make`), real public CLI as the bundled helper, official page; one click through `handleStatusClick`. The hosted runner never lays out the test process's status item, so the red square is a stand-in icon at a synthetic anchor (x = 380). Before = main f2497135 (cockpit centred on the icon, frame x = 73). After = #713 7f0496b6 (shell's left edge under the icon's left edge, frame x = 372 = 380 - 8). "Not enough window height to open" is main's height rule on a 768-pt screen (G3-39, #697), not part of this evidence.
- G3-48: GitHub-hosted ubuntu-24.04-arm, headless WebKit (Playwright 1.55.0), the canonical official page at the native compact canvas 636x661, three published models with long names. Before = main f2497135; after = #716 5a3e6980 (run 42440187322, re-shot after the CSS fix).
