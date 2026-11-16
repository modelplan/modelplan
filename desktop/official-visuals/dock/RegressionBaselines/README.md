<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# S1 accepted native regression baselines

The 36 synthetic Dock captures and 27 flame poses are frozen byte-for-byte from the owner-accepted batch-013, rendered from commit `fc87088f2c3e67d9ab0aefc2f9f90d6c315b6657`. Owner acceptance is recorded in PR #397 comment 6557081264; the regression scope revision is comment 6557410743. The scenes are synthetic. Vendor marks in these images remain trademarks of their respective owners; see THIRD-PARTY-TRADEMARKS.md. These images are regression references, not a new artwork licence.

D48 (owner, 2026-11-07) moved the quota ring to the middle of the face. The 36 Dock captures changed only where rendering the code before and after that move differs, so everything else is still the accepted batch-013 pixels. The empty station and the 27 flame poses stay within the tolerance and are unchanged. The owner's approval of these images is recorded on the PR.

## Regression contract

CI re-renders all 36 Dock scenes and 27 flame poses through `ProductionDockFactory.community` with synthetic inputs. It checks scenario inventory, station identities, hull bounds and the A5 control, then compares every premultiplied sRGB/alpha pixel to the frozen PNG. The mean absolute channel error must be at most 3/255, and the mean error in every 16×16 tile at most 32/255. The first allows small platform rasterization noise; the local-tile bound prevents a missing small control, mark or material feature from disappearing into the background average. Both thresholds are conservative initial cross-macOS allowances, not SSIM or a new visual acceptance criterion.

Run from the repository root:

```sh
MODELPLAN_S1_REGRESSION_BASELINES="$PWD/desktop/official-visuals/dock/RegressionBaselines" \
  swift run --package-path desktop/native/ModelPlanAppIntegration --jobs 2 S1Gallery
```

Negative control: replacing the community factory's official appearance with `nil` locally caused the check to exit 1 at `appearance: native-00.png`; the factory was then restored byte-for-byte and rebuilt. The complete local baseline run passed 36 Dock images and 27 flame poses with zero observed channel error. Hosted CI remains the cross-machine verification.

The additional `native-empty-44-right.png` records the requested zero-readings scenario at the default 44pt right edge, rendered without a window from the pinned study's `?` placeholder. It is a new regression case rather than one of the original 36 owner-accepted captures. The normal-entry XCTest separately checks its accessible Settings action.

G3-74 (owner, 2026-11-09) made the percentage digits 13×D/52 instead of 11×D/52. The 30 Dock captures that show digits were re-rendered from the CI actuals of the official-dock workflow (macos-15) at the G3-74 head; the six without digits (native-00, -01, -24, -25, -30, -31) stay the accepted pixels. The ledger row is the recorded approval D48 asks for.
