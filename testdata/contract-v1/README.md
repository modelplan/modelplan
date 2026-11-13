# Independent synthetic desktop contract fixtures

Every document here is produced by `cli/internal/contracttest` from independently authored synthetic inputs. No real accounts, credentials, user logs, private benchmark fixtures or private implementation are copied. The public publication numbers/tags are fictional test metadata, not model recommendations.

`cases.json` pairs each desktop output with its flattened publication output. It maps all F01–F20 IDs, with additional account-count, rate, effort, recording and DST variants. `coverage: data-prerequisites` explicitly means a UI-owned scenario: the payload freezes the inputs needed by geometry/capture/settings/caution/entrance/accessibility tests, and does not claim to validate those surfaces or physical OS events.

The cases include known zero versus unknown, monthly MCP and reported Fable labels, 0/1/2/6/unknown card counts, observed credits, six distinct working subscriptions, ambiguous attribution, weighted generation sums, short and 371-day coverage, ten quota cycles with ambiguous drops, project labels off, exact/mismatched publication IDs, null publication times and offset-distinct DST/quarter-hour rows. Unsupported source capabilities remain explicitly unavailable. Negative schema and unsupported-version cases are tested as mutations of these valid outputs, not represented as valid CLI output goldens.

Go validates schemas and compares every output byte. Swift Core decodes every pair and tests known values, source attribution, legacy/additive compatibility and rejection of incompatible declared versions. Offline unavailable publication remains exit 3 with empty stdout; an unavailable feed is not a fabricated successful JSON document.
