# Named status-menu actions and native arrival

Use this API when a synthetic verification driver must select a named item in the subject app's status menu and prove native dispatch. M4 owns U6 integration; this package and `pointer_drive --status-menu-plan` supply the locator/receipt seam. Admission, booking, release and the U6 driver stay with their existing owners.

## Attach to the admitted synthetic app

Add the `StatusMenu` package's `ModelPlanMenuVerification` product to the verification build. Compile both it and the consumer with `MODELPLAN_TEST_ONLY_SPI` (or the existing U6 verification flag `MODELPLAN_U6_DRIVE`); without either flag the library contains no instrumentation.

On the main actor, retain a `StatusMenuArrivalObserver` for the admitted run. Supply:

- `runID`, `epoch`: the existing admission identities.
- `ownsStatusMenu`: exact identity comparison with the app's own status menu, e.g. `{ $0 === statusItem.menu }`.
- `actionForItem`: map the app's existing Refresh selector/item to `.refresh`; return nil for unrelated actions. Other fixed IDs are `settings`, `console`, `quit`.
- `pendingRequest`: the current approved `StatusMenuActionRequest`, staged before driving the menu. It must be the same request object serialized into the pointer plan. This is correlation metadata, never an instruction to invoke the action directly.
- `isLive`: the existing synthetic guard's current lease/stop check.
- `emit`: append `receipt.object` through the existing native observation JSONL writer. A writer that already adds run/epoch/timestamp can append `receipt.event` and `receipt.fields`, preserving the numeric Unix timestamp and all identities.

Keep one pending request at a time, create a new UUID for each attempt, and clear it after success/failure. Call `stop()` during normal cleanup and release the observer. The observer performs no file loading, input, admission or permission request. It subscribes to [AppKit's post-dispatch notification](https://developer.apple.com/documentation/appkit/nsmenu/didsendactionnotification), checks the exact menu/item, live guard and request, then emits one sanitized receipt per pending UUID.

## Drive the named item

Build the helper as in `bin/pointer_drive.swift` (all `StatusMenu/Sources/ModelPlanMenuVerification/*.swift`, `bin/status_menu_drive.swift` and `bin/pointer_drive.swift` in the same test-only compilation). Run:

```sh
bin/pointer_drive --binary OWNED_BUILD/pointer_drive --status-menu-plan RUN/menu-plan.json
```

The plan extends the existing pointer plan with `statusMenu`. Example shape; replace the subject PID/bundle, identities, times and run-local file names with the admitted run values:

```json
{
  "profile": "synthetic", "runID": "u6-r2", "epoch": "granted-epoch",
  "lease": "RUN/lease.json", "stop": "RUN/STOP", "output": "RUN/menu-drive.jsonl",
  "subjectPID": 123, "subjectBundle": "RUN/Synthetic.app",
  "allowedRectangles": [], "steps": [],
  "statusMenu": {
    "itemName": "Refresh / 刷新", "openMenu": true, "timeoutSeconds": 5,
    "arrivals": "RUN/native-observations.jsonl",
    "request": {
      "profile": "synthetic", "runID": "u6-r2", "epoch": "granted-epoch",
      "subjectPID": 123, "requestID": "5027989F-846A-40AC-9320-CF47B73CF7CB",
      "action": "refresh", "notBefore": 1000, "expiresAt": 1100
    }
  }
}
```

Use the exact localized item name. If the app exposes multiple status items, also provide `statusItemIdentifier` with the exact accessibility identifier. Without it, exactly one own status item must exist. `openMenu: false` requires an already open menu. `arrivals` must be an existing regular observation file; output must be a new file. The helper reads only newly appended arrival rows.

The locator starts at `AXExtrasMenuBar` on the supplied PID and checks every traversed element's PID. It visits only menu roles, up to 256 elements/eight levels, and accepts one exact enabled item. Missing permission, unsupported accessibility structure, duplicate item/status item, foreign PID, stale lease, stop or timeout fails closed. There is no window, system-wide menu, coordinate or pixel fallback, and no TCC prompt. Accessibility `AXPress` is recorded as such; it is not a physical pointer click.

## Interpret the evidence

`status-menu-item-located` proves bounded lookup. `status-menu-press-requested` records accessibility dispatch request/transport return only. The helper reports `status-menu-result/outcome=arrived` only after a fresh native `status-menu-action-arrived` row matches run, epoch, subject PID, UUID, fixed action ID, request lifetime and monotonic attempt time. The native source is `NSMenu.didSendAction`, scope `owned-status-menu`. Prior rows and AX success alone cannot pass.

Arrival proves that AppKit dispatched the owned item's action to its target. U6 must still wait for its existing post-action provider/refresh completion receipt to prove refreshed product state. This package does not assert that asynchronous refresh succeeded.

Receipts contain fixed codes/IDs and timing only: no menu title, readings, selector, URL, argv or other-app inventory. Tests cover own-menu dispatch, duplicate suppression, stale/wrong correlation, disabled/ambiguous/foreign targets and bounds. Hosted checks compile the actual pointer entry and run the package tests without a menu popup, AX query or posted input. A live U6 run remains M4's separate admitted scenario after merge.

## What arrival evidence proves (threat model)

An `arrived` result means a row matching the exact run, epoch, subject PID, request UUID and action appeared in the subject's native observation file after the press. It is evidence against **self-certifying tooling**: the driver and every other verification tool open that file read-only, and `tests/test_arrival_writers.py` fails the build if any tool under `bin/` gains a code path that writes to it. Only the in-app `StatusMenuArrivalObserver`, through the subject's own JSONL writer, produces arrival rows.

It is not a defence against a hostile process running as the same user that appends a forged row. Without an OS-attested identity (an audit token or a signed peer), no file-based receipt can tell those writers apart, and verification runs use synthetic profiles on a dedicated machine. If an observer is missing or disabled, no row appears and the driver reports `not-run` after its timeout. It never reports `arrived`.
