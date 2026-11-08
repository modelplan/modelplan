# G3-40 and G3-41 walkthrough (hosted-runner synthetic images)

Run 42434217275, workflow `Evidence walkthrough` on this branch, GitHub-hosted macos-15, 1024x768, synthetic profile (no accounts, no readings).
Each column runs the production entry (`EngineRowsEntry.make`, real public CLI as the bundled helper, official page) and clicks the menu bar icon through `handleStatusClick` twice:
1-closed, 2-after-first-click, 3-after-second-click.

- before-main: main at f8f022b3 (without #695 and #696)
- after-696: cockpit/tray-toggle at 95c2e818
- after-695: cockpit/widget-stays-open at 2223d54c

The hosted runner never lays the test process's status item out in the menu bar (its frame stays at y = -23), so the page gets a synthetic placement near the left of the screen. These images show the click path, the toggle and the widget, not the cockpit's position. "Not enough window height to open" is main's height rule on a 768-pt screen (G3-39, #697), not part of this evidence.
