import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { mkdtemp, cp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { renderLineup, renderEffort } from "../render.mjs";

const http = process.argv.includes("--http");
const fresh = process.argv.includes("--fresh");
let root = fileURLToPath(new URL("../", import.meta.url)), temporary;
if (fresh) {
  temporary = await mkdtemp(join(tmpdir(), "modelplan-fresh-plugin-"));
  for (const name of ["launch.cjs", "server.bundle.mjs", "cli-pin.json", "package.json", "mcp.json", "ui"])
    await cp(join(root, name), join(temporary, name), { recursive: true });
  root = temporary;
}
const config = Object.values(JSON.parse(await readFile(join(root, "mcp.json"), "utf8")).mcpServers)[0];
assert.equal(config.type, "stdio");
const transport = http ? new StreamableHTTPClientTransport(new URL("http://127.0.0.1:4318/mcp")) :
  new StdioClientTransport({ command: process.env.MODELPLAN_SMOKE_NODE || process.execPath, args: config.args, cwd: root,
    env: { ...process.env, MODELPLAN_CACHE: process.env.MODELPLAN_CACHE || join(tmpdir(), "modelplan-mcp-acceptance-cache") } });
const client = new Client({ name: "modelplans-demo-acceptance", version: "0.1.0" });
try {
  await client.connect(transport);
  const tools = await client.listTools();
  assert.deepEqual(tools.tools.map(t => t.name).sort(), ["get_model_dashboard", "install_modelplan_cli", "open_model_board", "open_model_dashboard", "open_model_panel"]);
  const view = tools.tools.find(t => t.name === "open_model_dashboard");
  assert.equal(view._meta.ui.resourceUri, "ui://modelplans/model-dashboard.html");
  assert.equal(view._meta["openai/ui"], undefined, "the model's card declares no entrypoint");
  const resource = await client.readResource({ uri: view._meta.ui.resourceUri });
  assert.deepEqual(resource.contents[0]._meta?.["openai/ui"], { availableDisplayModes: ["inline", "fullscreen"], preferredDisplayMode: "inline" });
  assert.match(resource.contents[0].text, /<html data-surface="widget"/);
  // One entrypoint per tool; entrypoints render fullscreen, which in the side panel means "fill the panel".
  for (const [name, type, surface] of [["open_model_panel", "thread", "thread"], ["open_model_board", "global", "global"]]) {
    const entry = tools.tools.find(t => t.name === name);
    assert.deepEqual(entry._meta["openai/ui"].entrypoints, [{ type }]);
    assert.deepEqual(entry._meta.ui.visibility, ["app"]);
    const page = (await client.readResource({ uri: entry._meta.ui.resourceUri })).contents[0];
    assert.deepEqual(page._meta["openai/ui"], { availableDisplayModes: ["fullscreen"], preferredDisplayMode: "fullscreen" });
    assert.match(page.text, new RegExp(`<html data-surface="${surface}"`));
    assert.equal((await client.callTool({ name, arguments: {} })).isError, undefined);
  }
  assert.match(resource.contents[0].text, /ui\/initialize/);
  const script=resource.contents[0].text.match(/<script type="module">([\s\S]*?)<\/script>/)[1];
  execFileSync(process.execPath,["--input-type=module","--check"],{input:script});
  assert.equal(resource.contents[0].mimeType, "text/html;profile=mcp-app");
  const result = await client.callTool({ name: "open_model_dashboard", arguments: {} });
  assert.equal(result.isError, undefined, result.content?.[0]?.text);
  assert.ok(result.structuredContent.models.length > 0);
  assert.ok(result.structuredContent.models.every(m => m.developerId === "openai"));
  assert.equal(result.structuredContent.clientScope, "codex-openai");
  assert.ok(result.structuredContent.setup.runtime.version, "launcher reports the runtime it chose");
  assert.equal(result.structuredContent.resetFeed.status, "published");
  assert.equal(result.structuredContent.resetFeed.publicationId, result.structuredContent.publicationId);
  const model = result.structuredContent.models[0];
  assert.equal(result.content[0].text, renderLineup(result.structuredContent));
  for (const name of ["get_model_dashboard", "open_model_dashboard"]) {
    const ladder = await client.callTool({ name, arguments: { view: "effort", modelId: model.id, lang: "en" } });
    assert.equal(ladder.isError, undefined);
    assert.equal(ladder.content[0].text, renderEffort(model, "en", result.structuredContent.speedTiers));
  }
  const exact = await client.callTool({ name: "get_model_dashboard", arguments: { modelIds: [model.id] } });
  assert.equal(exact.structuredContent.models.length, 1);
  assert.equal(exact.structuredContent.publicationId, result.structuredContent.publicationId);
  const invalid = await client.callTool({ name: "get_model_dashboard", arguments: { modelIds: ["invalid-test-id"] } });
  assert.equal(invalid.isError, true);
  console.log(JSON.stringify({ status: "pass", transport: http ? "streamable-http" : "stdio", freshCopiedPackage: fresh, tools: tools.tools.map(t=>t.name), modelCount: result.structuredContent.models.length, resetNotices: result.structuredContent.resetFeed.events.length, resetStatus: result.structuredContent.resetFeed.status, publicationId: result.structuredContent.publicationId, source: result.structuredContent.source, units: result.structuredContent.units, resourceBytes: resource.contents[0].text.length }, null, 2));
} finally { await client.close(); if (temporary) await rm(temporary, { recursive: true, force: true }); }
