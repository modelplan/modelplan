<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Native T2 Dock work in progress

This package contains the native official visual implementation. It is covered
by the adjacent official visual license, independently of the generic Dock API.
Vendor marks retain their owners' rights and are not licensed by this package.

`Resources/artwork.json` binds the original P1 lossless layers and the A5
night button layers to byte counts and SHA-256 hashes. A5 resource copies must
remain identical to their canonical files in `runtime/ignition-a5`; no pixels
are recoloured or redrawn. This pack contains no vendor marks. The bundle
loader refuses unregistered names and altered bytes before decoding.

Current scope:

| Requirements | Implementation and evidence |
| --- | --- |
| DOCK-3.1-05, DOCK-3.1-07, DOCK-3.1-08 | Pure T2 geometry, 36/44/52 points, default 44, D/52 scaling |
| DOCK-3.1-12, DOCK-3.1-15, DOCK-3.1-16, DOCK-3.1-17 | Upright readout anchors, gap reduction before overflow, full-slice curvature |
| DOCK-3.1-22, DOCK-3.1-23, DOCK-3.1-29 | Button area search and opposite-end grip; bottom ignition defaults to the right end |
| DOCK-3.1-10, DOCK-3.1-11 | Isolated native gradient/grain face layer; pixel agreement remains unverified |
| DOCK-3.6-02 | Size-independent 20-point wake constant; runtime behavior remains separate |

`Tests/geometry-oracle.json` contains synthetic outputs of the supplied study
JavaScript. Its source SHA-256 is recorded in the file. Forty-five cases cover
three sizes, three edges and 0/1/4/7/30 subscriptions, including alias and overflow
cases. Tests compare every outline sample, station, readout anchor and button
position against those outputs, independently of the Swift implementation.

`T2FaceMaterial` draws the clipped face material, quadratic soot fans and ignition well. It does not claim the
complete layer stack, a product entry, interactions or visual acceptance.
It uses Core Graphics and Core Image, without a web view. The static noise follows
the non-stitched SVG fractal-noise algorithm with seed 23 and three octaves.
The exact browser/native compositing and sampling must be checked against the
approved visual baseline before this face layer can be accepted.

Run `swift test --package-path desktop/official-visuals/dock` on the hosted macOS
workflow. Native baseline images, content assertions, side-by-side comparisons
and owner visual sign-off are still required. SSIM alone is insufficient.
