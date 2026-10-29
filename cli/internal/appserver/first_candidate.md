<!-- SPDX-License-Identifier: MIT -->
# First-candidate method inventory

The frozen foundation Delivery list has thirteen methods. This is the complete
first-candidate surface; the directions distinguish requests from notifications.

| Method | Direction | Production owner |
|---|---|---|
| `initialize` | app → server | Core handshake, session and capabilities |
| `shutdown` | app → server | Core flush, cancellation and pipe closure |
| `rows/subscribe` | app → server | Core atomic snapshot/sequence subscription |
| `rows/changed` | server → app | Core full-snapshot/coalesced publication |
| `consent/get` | app → server | Shared U2 backend through core dispatch |
| `consent/grant` | app → server | Shared U2 transaction and durable receipt |
| `consent/changed` | server → app | Core notification after shared-store change |
| `credentials/request` | server → app | Core matching operation; explicit Settings action for foreground |
| `credentials/result` | app → server | Core one-use match, then shared admission/budget receiver |
| `refresh/request` | app → server | U3b bounded scheduler over shared provider refresh gates |
| `plugin/install` | app → server | U3b wrapper around `plugininstall.Install` |
| `diagnostics/get` | app → server | Core sanitized health/scope projection |
| `engine/health` | server → app | Core initial/change notification |

`$/cancel` is also served by the transport. History, cockpit and publication
queries are separate consumers and are not prerequisites for this list.

`refresh/request` queues at most one job per provider, using the shared scope
admission and persisted deadlines. Its execution callback is the existing
locked production dispatcher, which checks the budget again. A queue slot or a
projected time never authorizes an extra read. Offline, read-only, readers-off
and policy-disabled scopes return normal scheduled deferrals without dispatch.
A policy-disabled remote scope is read-only; its independent local-history
scope is evaluated separately. Known cooldowns retain a deferred job and are reconsidered at their due time;
they do not block another provider that is due now. The queue is bounded by the
compiled inventory.

`plugin/install` uses the exact standalone JSON result and fixed host command
list, including partial completion on failure. Offline/read-only requests plan
without looking up or launching a host. Host output is discarded and its stdin
is detached from JSON-RPC. The operation retains the standalone two-minute
bound. A public installation result remains available across a concurrent
consent change, and a completed attempt is not replaced by a cancellation error.

The constructor must register both U3b handlers alongside the core and shared
U2 backend. Production readiness is earned by the real-executable acceptance
suite after that wiring; test doubles alone do not prove the shared budget.
