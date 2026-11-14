<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Official rocket for the native entrance

The brand rocket used by the native hold-to-ignite entrance (v1.1). It ships in the public repository under the
reserved visuals licence, the same way as the Dock art (owner D109, 2026-11-09). Community and self-builds do
not link this package and draw the neutral stand-in from `ModelPlanEntrance` (`RocketModelSource.communityDefault`).

| File | What |
| --- | --- |
| `Resources/modelplan-rocket-night-lod1.usdz` | Shared pass-5 model, LOD1, night finish (graphite gunmetal) |
| `Resources/modelplan-rocket-day-lod1.usdz` | The same model, day finish (satin aluminium) |
| `Resources/rocket-geometry.json` | Canopy glass vertices, window anchor height, height and skirt radius, used by the entrance camera |

The geometry, node names and anchors (`anchor_window`, `anchor_top`, `anchor_base`, `anchor_cockpit_*`,
`curved_canopy_glass`, `engine_0` …) are identical in both files; only the material textures differ (one model,
two approved finishes, owner 2026-10-24). `OfficialRocket.source()` verifies every file's SHA-256 before use.

Run `swift test --package-path desktop/official-visuals/rocket-3d` on macOS (workflow `official-rocket.yml`).
Provenance: [SOURCES.md](SOURCES.md).
