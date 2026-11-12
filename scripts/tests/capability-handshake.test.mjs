// SPDX-License-Identifier: MIT
// The app-server only honours a capability the client declares in `initialize`; the server attaches opt-in
// fields (rows.Account.Today for "accountTodayV1", and so on) to clients that listed it. A capability the server
// advertises but the Swift client neither declares nor explains here leaves a feature silently off: the
// "-- · -- t/s" today row of build 14c. Add the capability to ProcessEngineClient.declaredCapabilities, or to the
// allowlist below with the reason the app does not need it.
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
const appserver = join(root, "cli/internal/appserver");
const swiftPath = join(root, "clients/swift/ModelPlanEngineClient/Sources/ModelPlanEngineClient/ProcessEngineClient.swift");

// Advertised by the server, deliberately not declared by the Swift client.
const NOT_DECLARED = new Map([
  ["refreshDecisionsV1", "opt-in refresh decisions payload; no app surface consumes it yet"],
  ["forecastProducerV1", "server-side fact read by the app through supportsCapability; not a client opt-in"],
]);

// Declared by the Swift client, not advertised by SharedBackend.Capabilities(): the plain names gate the client's
// own request methods (ProcessEngineClient checks them against the server's answer) and memberRefreshV1 is a
// client opt-in the server reads from clientCapabilities.
const CLIENT_ONLY = new Map([
  ["refresh", "plain capability name gating refresh/request on the client side"],
  ["history", "plain capability name gating history/query on the client side"],
  ["cockpit", "plain capability name gating cockpit/query on the client side"],
  ["publication", "plain capability name gating publication/get on the client side"],
  ["plugin_install", "plain capability name gating plugin/install on the client side"],
  ["history_import_v1", "plain capability name gating the history/import_* methods on the client side"],
  ["memberRefreshV1", "client opt-in the server reads from clientCapabilities, not an advertised feature"],
]);

function goConstants() {
  const map = new Map();
  for (const f of readdirSync(appserver).filter((n) => n.endsWith(".go") && !n.endsWith("_test.go"))) {
    for (const m of readFileSync(join(appserver, f), "utf8").matchAll(/\bconst\s+(Capability\w+)\s*=\s*"([^"]+)"/g)) map.set(m[1], m[2]);
  }
  return map;
}

function advertised() {
  const src = readFileSync(join(appserver, "shared_backend.go"), "utf8");
  const start = src.indexOf("func (b *SharedBackend) Capabilities()");
  assert.ok(start >= 0, "SharedBackend.Capabilities not found");
  const body = src.slice(start, src.indexOf("\n}\n", start));
  // The scan below includes the signature line. Its method name "Capabilities" is not picked up as a constant:
  // the pattern needs the literal stem "Capability" and "Capabilities" has "ies" where that has "y", and it is
  // not a quoted string either (checked for glm-846-1).
  const consts = goConstants();
  const out = new Set();
  for (const m of body.matchAll(/"([A-Za-z0-9_]+)"|\b(Capability\w+)\b/g)) {
    if (m[1]) out.add(m[1]);
    else {
      assert.ok(consts.has(m[2]), `unknown Go capability constant ${m[2]}`);
      out.add(consts.get(m[2]));
    }
  }
  return out;
}

function declared() {
  const src = readFileSync(swiftPath, "utf8");
  const start = src.indexOf("static func declaredCapabilities(");
  assert.ok(start >= 0, "declaredCapabilities not found in ProcessEngineClient.swift");
  const body = src.slice(start, src.indexOf("\n    }\n", start));
  return new Set([...body.matchAll(/"([A-Za-z0-9_]+)"/g)].map((m) => m[1]));
}

test("every capability the server advertises is declared by the Swift client or allowlisted with a reason", () => {
  const server = advertised();
  const client = declared();
  assert.ok(server.has("accountTodayV1"), "parser sanity: server advertises accountTodayV1");
  const missing = [...server].filter((c) => !client.has(c) && !NOT_DECLARED.has(c));
  assert.deepEqual(missing, [], `Swift handshake lacks: ${missing.join(", ")}`);
});

test("the Swift client declares accountTodayV1 for the today row", () => {
  assert.ok(declared().has("accountTodayV1"));
});

test("the allowlist holds only capabilities the server still advertises, and none the client declares", () => {
  const server = advertised();
  const client = declared();
  for (const [name, reason] of NOT_DECLARED) {
    assert.ok(reason.length > 10, name);
    assert.ok(server.has(name), `${name} is no longer advertised: drop it from the allowlist`);
    assert.ok(!client.has(name), `${name} is declared: drop it from the allowlist`);
  }
});

test("every capability the Swift client declares is advertised by the server or in the client-only allowlist", () => {
  const server = advertised();
  const extra = [...declared()].filter((c) => !server.has(c) && !CLIENT_ONLY.has(c));
  assert.deepEqual(extra, [], `Swift declares capabilities the server does not advertise: ${extra.join(", ")}`);
  for (const [name, reason] of CLIENT_ONLY) {
    assert.ok(reason.length > 10, name);
    assert.ok(declared().has(name), `${name} is no longer declared: drop it from CLIENT_ONLY`);
    assert.ok(!server.has(name), `${name} is now advertised: drop it from CLIENT_ONLY`);
  }
});
