---
name: native-verification
description: Verify native Mac observation and lifecycle scenarios, beginning with U11a cockpit measurement. Use for a synthetic measurement attempt or to qualify its evidence before a performance verdict.
---

# Native verification

Scenario 1 is U11a: an existing local cockpit with a still porthole and its indicator, session and HUD animations enabled. Inputs remain caller-supplied; this skill contains no unreleased designs or real profiles.

Run commands from the checkout root. For observer qualification use the neutral [animation controls](fixtures/animation-controls.html); this checks the observation mechanism, while the actual cockpit still needs its own admitted scenario.

## Prepare and qualify observations

1. Pin the subject, actual used assets, driver and verification source. Start from current public main; `scripts/u11a-aggregate.py` supports `native-self-counters`. Preserve previous attempts as immutable evidence.
2. Capture each own-window condition with `WindowObservation.capture`: App active, key window, visible, unoccluded. Emit `fields` **before** applying the activation gate on every observation tick. Record the explicit gate policy and elapsed time separately. A conjunction failure must retain which conditions failed. Never infer owner input from failure to become active or repeatedly steal focus.
3. Inject `animation-observer.js` after the page's setup, then call `installVerificationAnimationObserver` with selectors for `indicator`, `session`, `HUD`. Retain the observer and emit `snapshot()` at least twice during each measured active phase. Attach the same `viewID` and `generation` from the native attribution instance to window and animation receipts. A requestAnimationFrame count alone is not animation proof: the per-group count advances only for visible running animations whose timelines advance. Stop the observer at view teardown. If the subject uses canvas/video/JS rather than Web Animations, supply its own advancing-frame receipt and a reviewed adapter; DOM presence is insufficient.
4. Bind a `WebContentAttribution` instance to each measured WKWebView. Its optional scoped SPI is verification-only, capability checked, and paired with the returned PID's start identity. Enable it only for this explicit observation task. Emit attribution before targeted sampling; call `retire()` on close, replacement and `webViewWebContentProcessDidTerminate`. A changed PID/start identity retires the previous generation. Missing capability is unsupported. GPU attribution is independent; never infer it from a process name or scan unrelated PIDs.
5. Run `python3 -m unittest discover -s desktop/native/verification -p 'test_*.py'` and syntax/build checks for the changed sources. These qualify code only, not an active cockpit or performance budget.

## Execute and report

Use the actual per-run exclusive lease, epoch, fresh external guardian heartbeat, stop signal, notBefore and absolute expiry. The remaining interval must cover declared phases plus cleanup; there is no additional 5/20-second start cutoff. Each GUI run includes cleanup within 1200 seconds. Use a synthetic profile; owner takeover stops it. M1 owns guardian and release; M0 announces the matching window. This skill creates neither leases nor scheduling authority. Non-GUI checks do not require a GUI lease; avoid concurrent heavy jobs during an announced measurement.

Collect baseline, open/idle, close recovery and repeated cycles, with complete same-timestamp batches for attributable roles. Export true source/units according to `docs/u11a-aggregation.md`. Native self counters currently identify App only; keep attributed WebContent evidence separate until its measuring source is supported. Run the existing reducer, not a second statistics implementation:

```
python3 scripts/u11a-aggregate.py --input native-self-counters=<export.csv> --output-dir <new-report-dir>
python3 desktop/native/verification/verify_u11a.py <observation.jsonl> --output <new-observation-result.json>
```

The approved open CPU budget is average App + associated WebContent + attributable GPU <=10% of one core. Missing roles/active-animation proof leave the combined verdict unproven. Report canonical close RSS differences and repeat endpoints/trend; no numeric memory tolerance is implied. Energy may remain unsupported. Record phase outcomes and cleanup; an interrupted actual attempt must not be rewritten as an unlaunched run or a complete A pass. Use only project evidence in comments and preserve private inputs outside public commits.
