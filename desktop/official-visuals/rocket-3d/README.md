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
| `Resources/rocket-brushed-steel-detail.png` | Optional (owner D142, not shipped yet): tileable brushed-steel detail for the hull; the entrance draws code grain without it |
| `Resources/rocket-cockpit-interior-{night,day}.png` | Optional (owner D142, not shipped yet): the dim cockpit behind the front window; the entrance draws a code console without it |
| `Resources/rocket-hull-metal-{night,day,roughness}.png` | CKP-ENT-13 (owner D179): the tileable base metal (about 1 m square; day is the same texture lightened) and its roughness; no normal map |
| `Resources/rocket-hull-decal-<kind>-{albedo,normal,roughness}.png` | CKP-ENT-13: the hull decal kit (door, hatch, vent, plate, slot, panel): greyscale + alpha albedo (128 = the base colour, multiplied), OpenGL normal (+Y up), roughness; one set for both themes, placed from `HullDecals.placements`. With the kit the hull's brushed detail tile is not used |

The geometry, node names and anchors (`anchor_window`, `anchor_top`, `anchor_base`, `anchor_cockpit_*`,
`curved_canopy_glass`, `engine_0` …) are identical in both files; only the material textures differ (one model,
two approved finishes, owner 2026-10-24). `OfficialRocket.source()` verifies every file's SHA-256 before use.

Run `swift test --package-path desktop/official-visuals/rocket-3d` on macOS (workflow `official-rocket.yml`).
Provenance: [SOURCES.md](SOURCES.md).
