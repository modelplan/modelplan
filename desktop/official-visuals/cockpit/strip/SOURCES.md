<!-- SPDX-License-Identifier: LicenseRef-ModelPlan-Visuals-1.0 -->
# Cockpit header strip sources

Copyright (c) 2026 ModelPlan. The owner approved these exact synthetic-design header resources on 2026-11-03. The strip rules derive from the approved prototype design snapshot `e7d29f84c5d55c0bdcdfa37fdb750ecc90befc33`. Image-loading declarations were later rewritten to use direct CSS image layers, retaining the approved assets, states and geometry while avoiding blocked reload requests. Asset bytes match individually the source manifest, which records asset source commit `994283b71321ab1d0fc9ecf8e7c2d3b033c4e21c`. They remain subject to the official visual license and do not enter the community build.

| File | SHA-256 |
| --- | --- |
| close-hover@3x.png | `26b831ff4bf6ca443cfb5df9a5bd8576ecf31b944820ed88f5710312f3de21cc` |
| close-normal@3x.png | `149845b577925796ce036a6d226ddd1f3d670407f27e5b88979e7374d66ed5c3` |
| close-pressed@3x.png | `80ee6af5c81db59fda40562cdafbe68dbcdd8129a119b3fd79a3484698ecc37a` |
| detach-hover@3x.png | `6e2f4dc75cabce972cd7cb9f43bb489017620718bb20eb1fa1217f8109ee7013` |
| detach-normal@3x.png | `906a8b38fe91ec6066d1330d981d87879a9070b9797f176f1dfcf3936354557e` |
| detach-pressed@3x.png | `e31af16aca83db058628bb89b68c6159e973c9b8dca143c040ef6c1de20f4e52` |
| detach.svg | `df57ebd5e403be29df13d9ec33115d86bd8909fb02b83d84c4849379117599c9` |
| gear-hover@3x.png | `3f40c24a226bdf4c0b1c8b221e9bc0353ade79ca7727632700b2a09ddbe47232` |
| gear-normal@3x.png | `495e742abc5d3eca91e8322c374dd9b653f932c3144f537e938b5f93a51eeac2` |
| gear-pressed@3x.png | `a37c05a78b16be6765cd75c53610a9e6bc1fcdb8862df04d32ed8d433e40327c` |
| lamp-amber-body@3x.png | `97994d7f7f7290e222d2d63887e61ddb4e4bfd0b524a8d8565b3de324d776b38` |
| lamp-amber-glow@3x.png | `1cf0c88dbe1832d03843f9be94590077b7d367362bae1ee5a94825e4dc326973` |
| lamp-amber-pressed-body@3x.png | `5942502df40519e3fc400e0d530c7a02f8a256587bea6651dda948a67c72349c` |
| lamp-amber-pressed-glow@3x.png | `3e82fe16883eedcbccede3b614a055795d80e5950cf5be449190b2e124b54805` |
| lamp-off-body@3x.png | `113408fda5c53637bec5237bc9b2b70357bd018180a1327e092edc1e2224fa66` |
| lamp-off-glow@3x.png | `561ee2ea3b725a55fff4d3947a641f744628c028c632ddb6b931c1ab7f84c70d` |
| lamp-off-pressed-body@3x.png | `a4d2870316b3ecd9eaa2b450db005f6479ac45578c4ce5d226f5ae28efdcabc6` |
| lamp-off-pressed-glow@3x.png | `561ee2ea3b725a55fff4d3947a641f744628c028c632ddb6b931c1ab7f84c70d` |
| lamp-red-body@3x.png | `c27c0710d5a5c136eab78dd34bc855a2c225eecb4ddcb7a153c37cfbb3e37712` |
| lamp-red-glow@3x.png | `1cbdac0cd8b497f2d5834e321c5524af4de533402df1f0909e5b95f5be3d2180` |
| lamp-red-pressed-body@3x.png | `60fe3564e7e81fc2e09e36b293efb7e0b820174cb1fa96324751478a9f10e6d7` |
| lamp-red-pressed-glow@3x.png | `ece14174fc429578bed7f6605d7fa6e7d7874c5354daf4b74bbc36c029c8b41c` |
| put-back.svg | `6cec91c5039cd346f3038b953fbbb8cf199597c27d34a591f2154ccc290b90c2` |
| shutter-material@3x.png | `d752dbc5ef3782198041d7719e9d1898d5976a20ec632faebb17b87fe9a7b987` |
| slider-track@3x.png | `69405697ccbd4f55ab2e826f7ffe3b319e674ab0d1665e48f4087a775dcb4c8a` |
| strip-panel@3x.png | `523c8540c62af231d58ffac3e4b7eb6a35690398d5dfd56f0242e9d1cecb26dc` |
| thumb-closed@3x.png | `1bce26962db2726943f9c029c662f4ea61da790b2078e1d990e5488510b52b92` |
| thumb-open@3x.png | `dd251df0c39618c82f0e6bab350b1320eb34230190d539a3c969afd32623d17c` |
| wordmark@3x.png | `d8271e66f5c80cb2e857fa4941175f1164b584f6cde09a04093618b90d319cd6` |

`detach.svg` and `put-back.svg` were redrawn for the menu-bar launch rack (owner D181/D187, 2026-11-12): icon option 3, a launch tower with a swing arm, showing the key's action (attached: the arm swung down, press to detach; detached: the arm holding the rocket, press to put back). The paths are copied unchanged from the accepted demo `menubar-rack-v8.html` (confirm folder 2026-11-12).

## WP-10 header assets (2026-11-18)

The owner approved the round 3 header layout on 2026-11-18 (confirm folder `08-header-layout-WP-10-0`, `SPEC.md` R3). These four assets are cropped from the owner's transparent source images and area-averaged to @3x with colour premultiplied by alpha (spec R3.1 and R3.3). Crop boxes are in source pixels (left, top, right, bottom): the open switch from `exec-af2b38c8-5664-4091-a4ae-ebb6672f9f73.png` (145, 55, 2025, 671), the closed switch from `exec-acb733d3-d482-4042-9480-a098b6940be7.png` (97, 95, 1892, 703, stretched 3.4 % wider into the open frame so both states share one frame), the unselected key from the left key and the selected key from the middle key of `exec-850ac0eb-3ea6-48ac-af26-100cb61f6cca.png` ((72, 326, 740, 656) and (753, 326, 1421, 656)). The sources live in the private handoff store; the hashes below bind the exact bytes. `header.css` is the rules file and carries the reserved-licence comment. The later direct-image rewrite changed `strip.css` and its build pin; it retained the approved strip assets and layout. The old slider art (`slider-track`, `shutter-material`, `thumb-open`, `thumb-closed`) is no longer drawn by the header and stays listed until a clean-up.

| File | SHA-256 |
| --- | --- |
| porthole-switch-open@3x.png | `5628e2f7f97da2dbb06e15266e524969c9f958e1befe616319ce3d3756930db4` |
| porthole-switch-closed@3x.png | `8798983b0c62bf4cc1e84b99a8bcb4cda4ef98e3ff63ce52de47b27bac76ded8` |
| date-key-normal@3x.png | `a096e46cd80f36fac698da91770c520e0efacda07a050984ccb84bc7be8f06f1` |
| date-key-selected@3x.png | `3a20ae9edc6c41fe343fdcb8ebab268c83da093fc6d80a82523485e75f78d1e9` |
