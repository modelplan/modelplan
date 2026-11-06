# Reset-card Provider facts

`EngineDockContentProvider.makeContentAndDeadline` returns `resetCards` keyed by the
same verified member keys as its content. The dictionary, content and deadline are
one projection: discard all three on a delivery replacement, consent clear, or
connection invalidation. Reproject at the returned deadline and after lifecycle or
clock changes; do not reuse a prior pass as evidence for a new delivery.

For `.complete`, `countText` is `↺N`, including `↺0` for an admitted complete zero.
`expiryText` is the localized remaining duration when the earliest expiry is
known. `warning == true` means at least one known active card expires within
48 hours, matching `ReservePresentation`; render the count in the warn style.
An unknown expiry leaves the date and, absent a known near-expiry, warning unset.
`.partial` never supplies a total or earliest expiry; it may supply a positive
warning for a known near-expiry. `.unknown` supplies neither. Missing, stale,
unauthorized, unbound or inconsistent input never becomes zero. Item expiry and
warning/countdown changes contribute to the paired deadline.

The Host/card consumer belongs to #429. This contract does not claim that the
card has been wired or that a physical presentation has been verified.
