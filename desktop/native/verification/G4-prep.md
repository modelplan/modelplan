# G4 steps 11, 12 and 14: synthetic preparation

These checks exercise synthetic inputs and never perform an install, register a
login item, query a user's login database, reboot, or inspect displays. They are
preparation for the owner-approved G4 steps, not evidence those steps occurred.

- `python3 desktop/native/tools/app-smoke/check-install-receipt.py --fixture`
  emits a text JSON receipt for a freshly created synthetic bundle. Its
  quarantine field comes from that bundle's xattrs. The bundle path examples
  and login/reboot observations are synthetic or unknown; the outcome is
  always `NOT_RUN`. The CI artifact is explicitly labeled synthetic. Without
  `--fixture`, the command accepts bounded synthetic observations on stdin;
  it refuses real filesystem paths and does not obtain system login state.
- `python3 -m unittest discover -s desktop/native/tools/distribution -p
  'test_upgrade_identity.py'` checks the actual package identifiers and helper
  version pin against synthetic install/coexistence observations, checks that
  duplicate counts are rejected and exercises a disposable U14 HOME. The
  normal-entry Swift journey uses fake clients and login services; neither
  establishes a real installed process or login-item count. The existing
  normal-entry migration test verifies legacy settings/Core migration.
- Pipe a synthetic G4-14 JSON receipt to
  `python3 desktop/native/verification/validate_display_receipt.py
  --approved-display internal --approved-display external`. The separately
  supplied labels must be task-approved, and receipt events must be in the
  order sleep, wake, unplug, replug, with strictly increasing elapsed seconds and the
  same preference SHA-256. Validation does not observe a display, prove label
  approval or establish sleep/clamshell/reboot success.

Real install, reboot, live registration, two-display and device observations
remain subject to the separate owner, guardian and G4 runbook approvals.
