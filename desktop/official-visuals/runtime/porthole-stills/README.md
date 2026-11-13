<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Porthole stills

Copyright (c) 2026 ModelPlan. All rights reserved.
ModelPlan and Model Plan are marks of ModelPlan. No trademark rights are granted.

This owner-approved pack contains 980 PNGs for the official edition: standalone
body/flame layers at 1x and 2x, static backgrounds, and projected body/flame/halo
layers. The PNG payload is below 4 MiB. The [reserved visuals licence](../../LICENSE.md)
applies; the root MIT licence does not cover these images. See BADGE-NOTICE.txt.

manifest.json lists every PNG's hash, size and dimensions. SHA256SUMS provides the
same PNG hashes for command-line verification. Sprite paths are relative to this
directory. Standalone size, anchor and flameAnchor are in PNG pixels; logicalSize is in logical points.
Projected layer rectangles and model anchors use their frame's logical coordinate
space. Each layer's pixelScale/pixelScale1x maps its logical rectangle to the PNG;
round up fractional image dimensions. Projected backgrounds have backgroundScale 2.
Flames and halos use the recorded plus-lighter blend; reduced motion is static.

The default projection is 4ff2bad27654 (night, layout 890, seven bodies). The default
record and every referenced layer are checked without executing a renderer. Model
identifiers label images and placement recipes; this pack contains no scoring or
model-selection logic. Display consumers choose their own current data and labels.

node desktop/build.mjs --official verifies and includes this pack at
runtime/porthole-stills/. The community edition uses its independent appearance.
Run node scripts/check-porthole-pack.mjs and node scripts/check-visual-pack.mjs.
