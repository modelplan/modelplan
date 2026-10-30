<!-- SPDX-License-Identifier: MIT -->
# Cockpit prototype port

The owner authorized a public MIT port of the confirmed G/P6 web cockpit on
2026-10-29 and supplied its exact source on 2026-10-30:

- Source commit: `1d3f82429f1b853314ee120d4bd0007f84fc051d`.
- Source root: `design-handoffs/opus-r7/src/`, entry `rocket-r1.html`.
- Public destination: `desktop/cockpit/`.
- Source inventory and SHA-256 hashes: `desktop/cockpit/prototype/source.json`.

The source inventory records the selected CSS, `cockpit.js` static hierarchy,
`cockpit-fit.js` height calculation and `mfd-pages/fmt.js` display arithmetic.
The port keeps the plate, canopy, text tool keys, readings, deck and tape layout.
The entry page and renderer are adapted for a single local window, CSP and typed
Go `WireCockpitData`. Source comments about prototype-only work are removed;
original resource URLs/imports and font-face declarations are removed, with local
public OFL fonts substituted. The bridge and schema validator are new MIT code.
This release does not change existing artwork or third-party grants.

Only the already-public c01 raster pack is bound to the canopy. The official
builder copies the public A5/c01 runtime pack and OFL font notices. Artwork and
regression screenshots remain under `LicenseRef-ModelPlan-Visuals-1.0`; fonts keep
their OFL notices. The default community build excludes those reserved assets.
Vendor identity uses text names, without vendor logos, SVGs or images.

The audit of `workbench-data.js` found explicitly synthetic model pools, session
labels and display values, with no real account data, credentials, local paths or
network endpoints. Its hash and audit are recorded in the source inventory; it is
not copied or loaded. Public tests use the existing synthetic Go wire capture and
synthetic variations. No mock recommendation or subscription grouping is shipped.

The prototype's imported private study assets, private scene/render machinery,
porthole media, account-to-subscription inference, mock bootstrap and animation
loops are excluded. `compact-instrument.js`'s canvas/timer implementation is not
loaded. The public bundle has no runtime 3D, hidden prewarm or idle timers. Its
lamp is static at idle; a changed display triggers two finite 240 ms CSS opacity
pulses at 25 updates per second. Identical/timestamp-only updates do not restart
it. Hidden, occluded, non-key, clear and unload cancel it; reduced motion disables
it. Unused prototype animation declarations and keyframes are removed. Faders without a Go display value are decorative;
Settings, Choose setup and current tool history use fixed host intents.

Headless WebKit baselines record this implementation at full/compact size, both
themes and both languages. Final WKWebView fidelity and native lifecycle/CPU/RSS
acceptance are separate measurements; these images do not assert those outcomes.
