<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# T2 flame frames

The PNG frames in `Resources/Flame/` are captured from the unmodified Canvas in `design-handoffs/opus-r7/src/compact-instrument.js` at prototype commit `69f1b639201f0b9cedd1ad9f109d26423e67e75f`. The capture used Playwright 1.55.1 and Chromium 154.0.8037.92. The source archive SHA-256 is `e197b60805988fb601ae56b6fdafabd45a9e6a2d6d34cec654e6e3ae138c3c06`; the capture script SHA-256 is `3be28322fb4129ed5b5041bee6f44d8e44980c82b626e505261bf84464b6b311`; the original capture manifest SHA-256 is `1fd092709a320dbcfb2bd7009796d6a923cc96b7bbc06d05e3f8b9d1ce88e759`.

Capture command (supply the local executable and module paths in the variables):

```sh
PLAYWRIGHT_MODULE="$PLAYWRIGHT_MODULE" CHROME_PATH="$CHROME_PATH" node design-handoffs/dock-aftview-integration/capture-flame.cjs
```

The capture used phases 0/9 through 8/9 seconds for each of three quota-status colours, 36/44/52 points, 1x/2x and 1/1.15/1.5 sampling. `Resources/Flame/flame-manifest.json` is the runtime subset of the original manifest: it records every shipped PNG name, byte count and SHA-256 without capture-host paths. These images remain subject to owner visual sign-off.

The recorded Canvas video does not include the prototype CSS rotation; it is a flame-canvas reference, not a complete animation comparison.
