<!-- SPDX-License-Identifier: MIT -->
# ≈cost from public API prices

≈cost is the counted tokens of [response accounting](token-accounting.md) × each
model's public API list price. It estimates what the same use would cost at API
list prices; it is not what a subscription charges. It is computed on this
device from the verified publication; nothing is sent anywhere.

## Prices (client-v1.6)

`cli/internal/digest/price.go` is the only reader of the price fields: top-level
`priceUnit` (`usd-per-1m-tokens`), `models[].price` (`input`, `output`, optional
`cacheRead`, `cacheWrite`, `source`, `asOf`, optional `longContext` with
`aboveInputTokens`), `speedTiers[].apiPriceMultiplier` and
`models[].evaluation: "pending"`. Prices are read only from `client-v1.6` on.
Unknown fields are ignored. A price that fails a check (non-positive input or
output, a null or negative cache rate, a bad date, an invalid long-context
block) is dropped for that model only. A model without a price has no ≈cost:
its tokens count, its estimate does not. No rate is ever borrowed from another.

## Rules

`cli/internal/cost` follows ccusage@58866ba6
`rust/crates/ccusage-core/src/cost.rs` (two-stage branch):

- input, cache read, cache write and output × their rates; reasoning is billed
  as output;
- long context is chosen per request: when that request's input (uncached +
  cache read + cache write) exceeds `aboveInputTokens`, every bucket of the
  request uses the long-context rates;
- a fast-mode request (Claude `usage.speed: "fast"`, Codex `service_tier`
  `fast`/`priority`, `ultrafast`) is multiplied by the published
  `apiPriceMultiplier` for that harness, tier and model; without one it is
  unpriced, never a subscription ratio;
- a bucket with tokens but no published rate leaves the request unpriced.

Codex and Claude Code are priced per response. Tools whose logs hold only day
totals are priced by those totals; when the model has a long-context price the
figure is marked `approximate`, and the page keeps "≈" with a tooltip line.
Their hours come from the ledger's hourly view (the last two local days) and
feed only the hourly figures, so a day never counts the same use twice.

A response recorded before the speed tier was kept (an accounting cache from an
earlier build) is rescanned when its log is still there. When the log is gone,
its tokens still count, but as unpriced: a fast response is never priced at the
standard rate.

## Wire

`cockpitHistoryV1` carries `history.cost` only when the publication has prices:
per source, the last 30 local days and the last 48 local hours (`estimatedUsd`,
`pricedTokens`, `unpricedTokens`, `approximate`), and per model for today, 7
and 30 days. The page sums these for every range in one delivery
(`desktop/cockpit/src/prototype-cost.ts`); the unpriced share is unpriced ÷ all
tokens of the range.

The per-model lists are ranked by a model's ≈cost over all its sources and hold
at most 64 rows; a model is listed whole or not at all. A model's share is of
the range total from the day buckets, never of the listed rows. A positive
estimate never reaches the wire as zero (it is at least $0.000001, shown as
"<$0.01"). The usage row shows no ≈cost yet: that waits for the "Show estimated
cost" setting to reach the page (SET-9-50 follow-up).
