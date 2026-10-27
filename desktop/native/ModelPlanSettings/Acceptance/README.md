<!-- SPDX-License-Identifier: MIT -->
# Settings short-scenario adapter

`settings-short-scenarios.json` is a **leaf catalog**, not the global B25 schema or a new runner. The existing XCTest target executes its offscreen subset through real retained Settings controls. M0 owns global run/pair identity, provenance, host registration, actual input timing, resume storage and final acceptance.

## Run the offscreen subset

Use the existing test runner when native execution is authorized:

```sh
swift test --package-path desktop/native/ModelPlanSettings --filter SettingsAcceptanceScenarioTests
```

The fixture adapter creates one temporary `SettingsStore` shared by the editor and both controllers. Service capabilities remain unavailable, host intents are recorded, clipboard is fake, and no window is ordered on screen. No login, notification, reader, link, cache or global-key service is performed. These test results establish wiring/observation behavior, not physical input.

| Scene | Expected gate | Execution boundary |
|---|---|---|
| `settings.panes` | Eight canonical panes and their displayed row membership | Offscreen controller visits/checkpoints |
| `settings.search` | English/Chinese query and cleared-query membership | Programmatic field/delegate wiring; not typed keyboard proof |
| `settings.popups` | Local theme/motion/size commits and current popup state | Safe popup selections; not native-menu tracking proof |
| `settings.alias-cancel` | Draft cancelled without a preference revision/alias change | Native field-editor command path with synthetic text; not real IME |
| `first-run.structure` | Ready one-page controls, default choices and initial key-chain metadata | Separate bound 0/1/6 fixture variants; no presentation/completion effect |
| `settings.command-comma.human` | Actual reserved shortcut opens owned Settings/search focus | M0 host plus real keyboard input; calling a target is insufficient |
| `settings.popup-escape.human` | Actual popup/menu tracking, Escape, unchanged choice and focus return | Real keyboard/pointer plus caller-owned menu/input observation |
| `settings.ime-cancel.human` | Actual marked input then IME/edit cancellation without save | Already configured Chinese IME and human input; locale/model/setMarkedText are insufficient |
| `first-run.focus.human` | Actual initial focus and Tab traversal, including disabled controls | Real host first-run route and keyboard |
| `settings.voiceover.human` | Actual speech/focus/value behavior | Owner-configured VoiceOver and human observations; no OS-feature enablement |

## Read checkpoints from the same controllers

```swift
@_spi(SettingsAcceptance) import ModelPlanSettings

let catalog = try SettingsAcceptanceScenarios.decode(catalogBytes)
let scene = catalog.scenarios[0]
try catalog.validateRuntimeBindings(bindings, for: scene.id)
let identity = try catalog.inputIdentity(bindings, for: scene.id)
let observation = await settingsController.acceptanceCheckpoint()
// The first-run controller exposes the same read-only method.
```

The SPI observes the retained UI and its existing store. It does not reload, save, show, activate, focus, capture or synthesize events. A store read that crosses an editor revision change, or disagrees with the UI revision, returns `consistentRevision == false`. The caller should use its own save barrier and acquire a fresh checkpoint.

Output contains static pane/key/role names, popup indices/counts, revision/readiness facts and aggregate edit state. Raw query/alias/account/subscription labels, paths and diagnostic payloads are omitted. Context login state is explicitly named as host-supplied context, not an OS query. Missing native marked-text observation is `unobserved`, not an invented `false`.

Every checkpoint is labelled `observation-only` with immutable `physicalInputEstablished == false`, including observations of an actual native field editor. The global caller combines observations with independently recorded actual input; this SPI never emits a physical pass.

## Input and checkpoint identity

Definitions retain fixture/hash, source base, logical profile, scene revision, action, expected gate and named checkpoint fields. Runtime source/app/CLI/visual revisions, toolchain, OS/hardware and profile bindings are required before an input identity is produced. Each execution binds one fixture variant by its exact hash. Logical catalog scale/topology never claims observed physical hardware.

Validation rejects unknown fields/actions, duplicate/missing scene IDs, wrong evidence/gate combinations, unsafe popup/service actions, malformed pane/profile/path/hash values and missing/mismatched bindings. Fixture bytes are hash checked and limited to a closed synthetic shape with disabled service effects. The caller still owns symlink-aware fixture-root/file access.

`inputIdentity` changes with definition bytes, case revision, fixture, runtime revision or profile bindings. It is a matching token only: no checkpoint is persisted/resumed here, and format-valid bindings do not prove actual provenance. M0's global contract decides whether unchanged matching receipts may resume and whether interrupted/unmatched receipts are invalid.

Register this leaf SPI in the upper host that already depends on Settings. Core/root Shell need no reverse Settings dependency. The catalog's human steps remain pending until M0 supplies the actual host/input runner; the current repository has contract, measurement and XCTest runners, not an implemented global B25 scenario engine.
