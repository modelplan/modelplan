# Record strip view

`RecordStripView` consumes the existing `RecordStripPresentation` without changing its admission, sort, rate freshness, privacy or overflow rules. The resource-free neutral provider makes the community build complete. A trusted host may inject a `RecordStripRecipeProvider` for another appearance; no official geometry, fonts or artwork are bundled here.

The host supplies the nominal profile (`height: 890` or `640`) to P03, then passes the corresponding `.full` or `.compact` density to the view. Do not use the cropped shell's visible pixel height as the model's nominal height. Reproject when the session clock/scope/privacy changes; this view owns no refresh timer or rate cache. Identity inputs are display labels/ink only and are retained only for admitted visible IDs. Supply the original tool name when the model's tool label is shortened.

Connect `onNavigate` to `MainScreenNavigation.activate(_:from:)` and `onReturn` to the host's return action. Row actions use `.session(id)` / `.record(id)`; overflow forwards P03's timeline destination / `.recordOverflow`. The host owns the return stack and selected-row inputs. Mouse, Return, Space and accessibility press share the same guarded route. Stable row controls survive data refresh; removed targets reject subsequent actions.

`setPresentationAllowed(false)` pauses interactions and hides the cursor. Refresh never changes the caller's permission; hiding also suppresses actions without losing that permission. `stop()` clears all content and revokes admission until the host explicitly resumes. Providers must return exactly the admitted row IDs, contained field frames and a more target iff P03 supplies overflow; invalid recipes/resources leave the previous state intact.

Only tool/project name areas produce native tooltips. Working-row speed help is exposed through `helpTargets()` using the existing help definition; inject these anchors into the single host-owned Option-help system. No help timer, persistence or hint policy is created. Accessibility retains the complete supplied labels and unknown-rate distinction.

The cursor input is a static optional record-relative placement/visibility seam. There is no invented cadence or typing animation. A later approved cursor delta can drive it without altering P03. `rasterImage` draws recipe content only; layer cursor/focus/actual-window behavior still needs host acceptance.
