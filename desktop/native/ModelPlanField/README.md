# ModelPlanField: public picker and protocol

This MIT target retains the public-ID picker, host binding and public data types used by the legacy native composition. It contains no renderer, official assets or cockpit layout.

## Public-ID picker

`FieldPickerCatalogue` accepts the existing public projection and caller-supplied scope/site/roster IDs. Published tag facts require their matching projection revision; no tags, ranking or frontier are inferred from metrics. `FieldFleetPicker` is field-local UI state with a ten-model cap, explicit empty selection, presets, filters, focus and a public-ID/preset-only saved value. It creates no store and never changes the supplied normal scope.

`FieldFleetPickerView` provides neutral controls inside caller-supplied bounds and accepts an existing comparison view. Its change callback returns a public-only selected projection, focus/expanded state and an optional saved value for the existing persistence owner. Hidden/disposed views emit no actions. Construction and updates create no WebKit/WebGL runtime. Actual focus transport, floating A surface, close/desktop hit routing and scope-owned normal-still restoration remain with the upper composition; the picker does not alter those interfaces or the frozen HUD. Keep field-local projections separate from normal scope/still inputs.

`FieldPickerProductionBinding` connects those controls to required `FieldPickerProductionHost` ports for current input, atomic projection/focus, expansion layout, persistence and close/current-scope still restoration. Missing/disconnected ports throw and withhold the controls; there are no no-op defaults. Normal-entry factory wiring must be verified separately with injected effects. Component/reducer checks do not establish that the application factory supplies these ports or that the official A renderer and physical journeys pass.

## Retained bridge resource

`Web/field-bridge.mjs` and its standalone protocol test remain packaged while the existing CI job still exercises them. They are independent of the shipping Web cockpit host. No native Field transport or enlarged-field runtime is installed by this target.
