# Shared nine-frame image seam for the dock

B05's triangle is a neutral calibration mask, not the official pressure jet. B06 can use EffectFrameProvider, EffectFrameRequest and SteppedImageEffect to supply untinted RGBA frames through the same EffectResourcePool. No official image, font, geometry or frame provider is shipped here.

The app composition root owns **one** pool and injects it into both mask and RGBA consumers. Keys include provider identifier/revision, variant, full RenderProfile, logical points and magnification. Provider identity/revision/variant must identify immutable bytes; change revision when art changes. Alpha-mask and RGBA entries have separate key namespaces but share the same 4,000,000-byte admission budget.

## Provider and consumer contract

MainActor EffectFrameProvider exposes identifier/revision and draw(pose:request:in:) throws. Pose is 0...8. The pool supplies a cleared, 64-byte-row-aligned RGBA8/sRGB CGContext in pixel coordinates, reserves the entire atlas **before** drawing, and counts each returned image's actual rowBytes x height. A failed draw rolls back the reservation. Reentrant requests cannot over-admit or recursively build the same key.

Providers retain only verified **encoded** resources or paths. They must not retain contexts, decoded frame arrays or CA image copies. If using ImageIO, decode at the requested pixel bound without a retained image-source cache, draw one temporary frame, then release it. Do not use a separate artwork store's decoded-image cache for jet frames. Temporary bounded codec scratch and Core Animation/GPU/server storage are not a second atlas cache; their cost still belongs in whole-process/helper resource measurements. The 4 MB counter is the pool's conservative cache/reservation bound, not a claim that all graphics process memory is 4 MB.

EffectFrameRequest(profile:points:magnification:variant:) uses ceil(points x profile.scale x magnification) source pixels. Native scales are 1/2; magnification is finite 1...4 and affects sampling only. The host still owns the actual geometry transform. L64 at 2x and 1.5 sampling uses 192x192 frames, not an upscaled 52-point source. Three such RGBA variants occupy 3,981,312 bytes in total and can serve six distinct consumers by shared counted leases.

SteppedImageEffect(pool:) owns a CALayer. configure(request:provider:working:) first stops the old sequence and lease. Successful working sequences use nine discrete CA contents steps per second, with ten key-time boundaries. There is no application redraw timer. RGBA is displayed unchanged, with no gradient/triangle mask. Reduce Motion keeps frame zero static; seekForCapture selects a static phase without cloning an atlas. The consumer exposes isAvailable/isAnimating/frameCount; it does not export a decoded image array.

On refusal, isAvailable is false and the layer stays empty/hidden; the host may retain its existing native glyph/vector UI but must not fake the official jet with the calibration triangle or allocate an uncounted fallback bitmap. Stop effects on hide/disposal. Before a whole-profile transaction, stop all affected consumers, purge unused entries, then configure the new profile; old live entries cannot be evicted. Deinitialization conservatively retains its counted lease until MainActor clears CA references. Core Animation transaction/server retention is measured separately, not treated as zero.

## Native target

The ModelPlanDock target now covers the module directory, depends on Core/Primitives, and excludes independent proof/check/script paths. This includes future Native Swift source without copying it into another module. Register each standalone instrument probe separately after its entry is publicly committed; a library must not accidentally compile a proof's main.swift.

## Checks

Use full Xcode only for the command and an owned scratch path:

    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path desktop/native --scratch-path <owned-build> ModelPlanPrimitiveChecks
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run --package-path desktop/native --scratch-path <owned-build> ModelPlanPrimitiveChecks --live-image-cadence --output <owned-receipt.json>

The default suite now has eight grouped primitive/provider checks: shared mask/RGBA budget, six IDs/three variants, complete S/M/L x 1x/2x x 1/1.15/1.5 sampling, immutable revision/profile keys, preallocation refusal, reduced motion, invalid requests, partial draw rollback, reentrancy and surviving-layer teardown. Existing native CI and transferred macOS 14 primitive-check execution run this same default suite. The live mode observes actual RGBA presentation contents in an owned window; its diagnostic polling is excluded from CPU acceptance. Synthetic neutral sources are not official pixel, CPU/GPU or physical input acceptance. M1 must still test the actual private frames and enabled feature envelope.
