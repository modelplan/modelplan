# Native window/input proof (synthetic, macOS 14+)

This is an isolated engineering probe, not dock UI or approved appearance. It reads no CLI, accounts, logs or private assets. All native controls and labels are neutral fixtures. It neither requests TCC permissions nor posts/replays another application's events. Intel is compile-only, untested.

Build using an installed full Xcode, without changing the system toolchain selection:

```sh
bash desktop/native/ModelPlanDock/WindowInputProof/build.sh "$HOME/mp/build/M1/B05b"
"$HOME/mp/bin/heavy" "$HOME/mp/build/M1/B05b/ModelPlanWindowProbe.app/Contents/MacOS/ModelPlanWindowProbe" --checks --receipt "$HOME/mp/evidence/M1/contracts.json"
```

`build.sh` produces ad-hoc signed arm64+x86_64 probe and input-receiver apps, with a macOS 14 deployment target. No install, signing identity, login item, preference or permission change is required. Pass an owned build directory; module caches stay there. Run disk checks and the lane's heavy-job guard before each UI run.

Run the pair for manual input checks (Ctrl-C or the timeout exits both owned processes):

```sh
"$HOME/mp/bin/heavy" python3 desktop/native/ModelPlanDock/WindowInputProof/run-pair.py \
  --build "$HOME/mp/build/M1/B05b" --evidence "$HOME/mp/evidence/M1/manual" --seconds 600 --reveal-after 30
```

Use `--measure` for a separate 30-second warmup + 60-second, 1 Hz CPU/physical-footprint sample of only those two PIDs. The sampler binds process birth times. It excludes WindowServer/GPU; zero sampled CPU does not mean zero work. The resource run does not activate either app, but still creates native windows. Retain receipts privately; raw inventories contain display UUIDs. Settings receipts store character counts/CJK presence/marked state, never the entered text. Do not type personal data in a test field.

## What this proves, and what it does not

`--checks` covers 864 edge/count/size/density fixture cells, left/above origins, safe-area intersection, deterministic stable/missing/ambiguous display selection, generic 600/520 uniform-fit transforms, and stale-release cancellation. Native contracts cover nonkey panels, explicit key eligibility, ordinary visible Settings main/key eligibility, local-only AX slider actions, stable object/responder identity, backed cell hit routing and the AppKit field editor. These method-level checks **do not prove real pointer dispatch, IME composition, VoiceOver speech, physical density or display unplugging**.

The input strategy under test is **separate, fully backed rectangular native windows**, including alias and overflow fixture cells. There is no large transparent event-catching parent window and no pointer-driven mouse transparency switch. This can only be accepted for geometry whose entire input rectangle has visible backing. It does **not** solve a circular or irregular transparent silhouette: real original-click tests or an approved backed shape are required before production reuse.

The probe dashboard's `Over receiver` places three backed cells above the independent receiver window. `Edge L/R/T/B` place them on the usable display containing the pointer, with deterministic fallback. A topology change cancels a hold and closes the transient calibration panel before reflow; an unchanged notification preserves it. `Space pref` explicitly opts in/out of all-Spaces/fullscreen-auxiliary behavior. Default is off. These are fixture operations, not persistent user preferences or final dock timing.

`Cockpit / AX` explicitly activates a key/nonmain panel with stable native controls and first responder. The fader changes trial only; current and recommendation stay fixed. `Settings / IME` opens an ordinary key/main window with a native editor. A global mouse monitor only dismisses transient UI; it neither swallows nor forwards the underlying event. The harness does not register global keyboard shortcuts.

## Physical acceptance checklist

1. Focus the receiver's synthetic editor and type `before`. Leave the pointer stationary and wait for timed reveal. Type `after`; it must remain in that editor, and `passiveReveal` must record no key dock and no activation.
2. Click a blank receiver location once as baseline. Show the backed cells. Click the gaps, all four outside corners, alias/overflow gaps, then enter rapidly and click with no earlier hover. Each gap must add exactly one `originalMouseDown` to the receiver and no dock action. A backed control must add one dock action and no receiver click; it must never become key. This is a **manual original-event test**, not an AX press test. Repeat with menus open and after a stationary-pointer reveal.
3. Press/drag the HOLD cell beyond the named movement slack, release outside, change apps/Space mid-hold, and press Escape after explicit keyboard entry. There must be no delayed action. Reopen an explicit panel; Tab/Shift-Tab, arrows, Escape and the close button must not trap focus. Outside dismissal must leave the receiver's original click intact.
4. Open Settings. Select a Chinese IME using the user's existing input sources; compose `测试`, change candidates, commit, undo and type Latin text. Confirm marked text stays in the editor and selection survives. Typing/pasting a CJK string through automation is not this test.
5. With the user's existing VoiceOver/Full Keyboard Access settings, traverse Subscription, Effort, ALERT, Close and the chart alternative. Confirm names/current/trial/recommendation, help access without hover, one action per press, focus survival and correct return focus. Enabling these settings is an owner action.
6. Test four edges and exposed/seam edges, S/M/L, aliases/overflow on actual 1×/2× screens, a screen left/above primary, primary changes, auto-hidden menu/Dock, a notch, and small usable areas in both locales. The generic fixture transforms are not physical-screen proof. Do not change system display settings automatically.
7. While HOLD is down, physically unplug its display; check cancellation/no delayed action and exactly one fallback dock. Field and in-flight capture removal require the integration owner's real field harness; this standalone probe deliberately has neither a web scene nor a capture placeholder that could masquerade as that proof. Repeat Space/fullscreen/Mission Control/Stage Manager cases in integrated acceptance.

The proof is standalone to avoid editing the shared app target or package manifest from a dock lane. Integration into shared CI/targets is a separate coordinator change. Future dock UI should consume shared production primitives rather than copying these test-only controls.
