<!-- SPDX-License-Identifier: MIT -->
# Desktop third-party fonts

These four approved font families are third-party OFL-1.1 material, separate from
`desktop/official-visuals/`. Each family keeps the unmodified Fontsource 5.3.0
licence/copyright text in its own `OFL.txt`; see [NOTICE.md](NOTICE.md).

Only normal-style static Latin faces are included: Manrope 500/600/700/800,
DM Sans 400/500/600/700, JetBrains Mono 400/500/600 and Share Tech Mono 400.
These cover the official theme typography declarations and the cockpit's
JetBrains Mono 600 numeric headings. No italics, full variable-weight ranges,
Latin Extended duplicates or CJK font binaries are included. CJK uses system
fallbacks. Existing plugin font files and their grants are unchanged.

`fonts.css` exposes these local faces without changing the app's typography or
loading them automatically. Consumers copy the directory intact and opt into the
stylesheet; they must keep the NOTICE and four OFL files with redistributed
fonts. Native registration and final package appearance are separate integration
work, not demonstrated by this asset-only pack.

The font binaries are unmodified upstream files; no subsetting or renaming was
performed. Fontsource's supplied copyright text is preserved verbatim, including
its references to other family styles. Share's Reserved Font Name is preserved.
The CSS/manifest/documentation are MIT software metadata; this does not relicense
the OFL font software, grant endorsement or change ModelPlan trademark rights.

`manifest.json` records every file's licence, bytes and SHA-256, plus the upstream
package/version and selected weights. `source-policy.json` binds that manifest's
SHA-256. CI checks completeness, licence separation, local stylesheet bindings,
no extra files/symlinks/private provenance and unchanged bytes:

```sh
node scripts/check-font-pack.mjs
node --test scripts/tests/font-pack.test.mjs
node scripts/check-source-policy.mjs
```
