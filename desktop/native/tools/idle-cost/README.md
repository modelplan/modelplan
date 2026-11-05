# G4 idle-cost measurement — in progress

The current draft implements only a three-minute **synthetic harness smoke**. It
launches an owned `/bin/sleep` child with a fresh synthetic HOME and samples its
CPU time and resident memory at 0, 60, 120 and 180 seconds. It terminates only
that child and writes a new owner-readable JSON file. The smoke is not an app
measurement or G4 evidence: its status is `NOT_RUN`, including when the smoke
itself succeeds. Run it on macOS or Linux with:

```sh
python3 desktop/native/tools/idle-cost/idle_cost.py --synthetic-smoke --output /tmp/modelplan-idle-smoke.json
```

The G4 runbook requires M0 and owner approval for the measurement method and
numeric thresholds. The installed-app launch/guardian and synthetic-profile
isolation, descendant accounting across sample gaps, wakeup collection, and
an app-owned network-request diagnostics source are not yet implemented.
Missing information must never be interpreted as zero. Do not use this smoke
as a one-hour candidate result. No GUI booking is implied.

Proposed line for G4 step 15 after the actual monitor and its admission are
reviewed: “Run the approved idle-cost monitor against the admitted synthetic
candidate; attach its sanitized JSON receipt, and treat unavailable metrics or
thresholds as NOT RUN.” The authoritative G4 runbook is maintained separately.
