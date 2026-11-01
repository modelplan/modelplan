# Verification Dock scenarios

These synthetic app-server snapshots are inputs for the separately compiled verification application. Copy one JSON file into the synthetic HOME as `.modelplan-verification-rows.json` and create `.modelplan-verification-home` containing exactly `MODELPLAN VERIFICATION HOME`. Set `HOME` and `CFFIXED_USER_HOME` to that same synthetic directory; the application verifies its Application Support location is inside it before reading Settings. Refresh in the app after replacing the snapshot. Do not use a real account or profile.

The scenarios cover mixed quota levels and overflow, single weekly windows, announced and confirmed public resets, and retained stale readings. The 16 button interaction states require the T2 appearance and its actual interaction driver; row snapshots alone do not set button state. Reset signals and ring-role projection require #401; the T2 appearance requires #397.
