# #476 layout renders (evidence only)

Synthetic fixtures, rendered on a hosted macOS runner. This branch holds images only and never merges.

- `before/`: run 42395714515, from the commit before the layout fix (d21b17e2), on a temporary branch.
  That branch added the G3 layout test file, a render helper and `-DMODELPLAN_TEST_ONLY_SPI`, and removed
  `P1ExactPlacementTests.swift` so the test target would compile. Its green run proves nothing about tests.
- `after/`: run 42391112375, from #476's merged head a5f02bfe plus the same render helper.
