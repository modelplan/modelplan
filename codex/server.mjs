import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import { createReader, filterDashboard } from "./data.mjs";
import { renderLineup, renderEffort, renderQuota } from "./render.mjs";
import { readAdvice, readQuota } from "./quota.mjs";
import { fetchCli, fetchInBackground, supported } from "./install.mjs";
import { pluginUpdate, setupStatus } from "./setup.mjs";

const version = JSON.parse(await readFile(new URL("./package.json", import.meta.url), "utf8")).version;
// One UI resource per surface (OpenAI MCP extensions: at most one entrypoint per tool). The model's
// tool call renders the inline card; the thread and global entries are opened by the user and the
// host always shows entrypoints in `fullscreen`, which there means "fill the panel", not "go wide".
const SURFACES = {
  widget: { uri: "ui://modelplans/model-dashboard.html", modes: ["inline", "fullscreen"], preferred: "inline" },
  thread: { uri: "ui://modelplans/model-panel.html", modes: ["fullscreen"], preferred: "fullscreen" },
  global: { uri: "ui://modelplans/model-board.html", modes: ["fullscreen"], preferred: "fullscreen" },
};
const reader = createReader();
// Which Node runs this server and how launch.cjs chose it; set by the launcher, absent when run directly.
const runtime = (() => { try { return JSON.parse(process.env.MODELPLAN_RUNTIME); } catch { return null; } })() ??
  { path: process.execPath, version: process.versions.node, source: 'direct' };
const setup = (quota, advice, state) => ({ pluginVersion: version, runtime, quotaReader: quota.reader ?? null, quotaStatus: quota.status,
  advice: { status: advice.status, reason: advice.reason ?? null, error: advice.error ?? null }, adviceEvents: advice.status === "ok" ? advice.events.length : null,
  cli: { ...state.cli, retryable: supported() }, hook: state.hook, codexbar: state.codexbar ?? null, pluginUpdate: state.pluginUpdate ?? null });
const readHtml = async (preview = false, surface = "widget") => {
  const [html, tokens, components, script, logo, comparison, lineup, presentation, curves, space] = await Promise.all([
    "ui/dashboard.html", "ui/kit/tokens.css", "ui/kit/components.css", "ui/dashboard.js", "ui/kit/logo.svg", "ui/comparison.js", "ui/lineup.js", "ui/presentation.js", "ui/curves.js", "ui/space.css",
  ].map(p => readFile(new URL("./" + p, import.meta.url), "utf8")));
  const fontFaces = await Promise.all([['Manrope',400,'manrope-400'],['Manrope',600,'manrope-600'],['JetBrains Mono',400,'jetbrains-mono-400'],['Share Tech Mono',400,'share-tech-mono-400']].map(async ([family,weight,file]) => {
    const bytes = await readFile(new URL('./ui/fonts/'+file+'.woff2', import.meta.url));
    return `@font-face{font-family:"${family}";font-weight:${weight};font-style:normal;font-display:swap;src:url(data:font/woff2;base64,${bytes.toString('base64')}) format('woff2')}`;
  }));
  return html.replace("<html lang=", `<html data-surface="${surface}"${preview ? " data-preview" : ""} lang=`)
    .replace("/*MODELPLAN_TOKENS*/", tokens).replace("/*MODELPLAN_COMPONENTS*/", components)
    .replace("/*MODELPLAN_SPACE*/", fontFaces.join("\n")+"\n"+space)
    .replace("/*MODELPLAN_SCRIPT*/", comparison+"\n"+lineup+"\n"+presentation+"\n"+curves+"\n"+script).replace("<!--MODELPLAN_LOGO-->", logo);
};
const annotations = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };
const inputSchema = { modelIds: z.array(z.string().max(180)).max(32).optional(), refresh: z.boolean().optional(),
  lang: z.enum(["zh", "en"]).optional(), view: z.enum(["lineup", "effort"]).optional(), modelId: z.string().max(180).optional() };
async function result(args) {
  try {
    const [published, quota, advice, state] = await Promise.all([reader({ refresh: args.refresh }), readQuota(), readAdvice(), setupStatus().then(async st => ({ ...st, pluginUpdate: await pluginUpdate({ version }) }))]);
    const data = filterDashboard(published, args.modelIds);
    const model = args.modelId ? data.models.find(m => m.id === args.modelId) : null;
    if (args.modelId && !model) throw Error("unknown_model_id");
    if (args.view === "effort" && !model) throw Error("effort_view_requires_modelId");
    return {
      structuredContent: { ...data, quota, advice, setup: setup(quota, advice, state), focusModelId: model?.id ?? null, language: args.lang ?? "zh" },
      content: [{ type: "text", text: args.view === "effort" ? renderEffort(model, args.lang, data.speedTiers) : renderLineup(data, args.lang) },
        { type: "text", text: renderQuota(quota, args.lang, advice, setup(quota, advice, state)) },
        { type: "text", text: `Publication ${data.publicationId}${data.stale ? " (last-good: " + data.error + ")" : ""}.\n` +
          "Codex public reset notices · not your own meter\n" + (data.resetFeed.events.slice(0,3).map(e =>
            `${e.publishedAt} · ${e.scope ?? "scope unknown"} · ${e.status} · ${e.url}`).join("\n") || data.resetFeed.status) }],
    };
  } catch (error) {
    return { isError: true, content: [{ type: "text", text: `ModelPlan data unavailable: ${error.message}. No value was invented.` }] };
  }
}
export function makeServer() {
  const s = new McpServer({ name: "modelplans-dashboard", version });
  for (const [surface, { uri, modes, preferred }] of Object.entries(SURFACES))
    s.registerResource(`model-${surface}`, uri, { mimeType: "text/html;profile=mcp-app" }, async () => ({ contents: [{
      uri, mimeType: "text/html;profile=mcp-app", text: await readHtml(false, surface),
      _meta: { ui: { prefersBorder: false, csp: { connectDomains: [], resourceDomains: [] } }, "openai/ui": { availableDisplayModes: modes, preferredDisplayMode: preferred } },
    }] }));
  s.registerTool("get_model_dashboard", {
    title: "Read model capability, cost and recommended efforts", inputSchema, annotations,
    description: "Read the verified OpenAI lineup at recommended efforts (view=lineup), or one model's ladder relative to its recommendation (view=effort, modelId required). Text uses the modelplan CLI wording and order; structured values match the website. Includes public reset notices and the user's own Codex usage windows (used %, reset countdown, headroom), read locally from Codex's session logs and never sent anywhere. No host settings change.",
  }, result);
  s.registerTool("open_model_dashboard", {
    title: "Codex models & resets", inputSchema, annotations,
    description: "Show the compact ModelPlan card in the conversation: the thread's model, effort and speed against the recommendation, the user's own Codex quota (read locally), effort comparisons and public reset notices. Accepts empty input. To keep it beside the conversation instead, the user opens the \"Effort & quota\" panel from the conversation's side panel; a tool call cannot open that panel.",
    _meta: { ui: { resourceUri: SURFACES.widget.uri } },
  }, result);
  // User-opened entrypoints. Hidden from the model: called by the model they would render in the thread.
  const entry = (name, title, description, surface, type) => s.registerTool(name, {
    title, description, inputSchema, annotations,
    _meta: { ui: { resourceUri: SURFACES[surface].uri, visibility: ["app"] }, "openai/ui": { entrypoints: [{ type }] } },
  }, result);
  // The dashboard's Retry button for the plugin's own CLI (the pinned release, checked against the
  // pinned SHA-256). App-only; the server already fetches it in the background when it starts.
  s.registerTool("install_modelplan_cli", {
    title: "Fetch the plugin's modelplan CLI", inputSchema: {},
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true },
    description: "Fetch the modelplan CLI release this plugin is pinned to (checked against the SHA-256 pinned in the plugin) into ~/.cache/modelplan-cli. Only the dashboard's Retry button calls this.",
    _meta: { ui: { visibility: ["app"] } },
  }, async () => {
    const install = await fetchCli();
    const ok = install.status === "ready";
    return { isError: !ok, structuredContent: { install, advice: ok ? await readAdvice() : null },
      content: [{ type: "text", text: ok ? `modelplan CLI ${install.version} ready: ${install.path}` : `modelplan CLI not fetched (${install.status}${install.reason ? ": " + install.reason : ""}).` }] };
  });
  entry("open_model_panel", "Effort & quota", "Open the ModelPlan effort and quota panel beside this conversation.", "thread", "thread");
  entry("open_model_board", "Model Plan", "Open the ModelPlan board from the sidebar.", "global", "global");
  return s;
}

if (!process.argv.includes("--http")) {
  // Codex starts this server with each session: fetch the plugin's pinned CLI in the background
  // when it is missing (after an install or a plugin update), so hints need no separate install.
  fetchInBackground();
  await makeServer().connect(new StdioServerTransport());
} else {
  const port = Number(process.env.MODELPLANS_DEMO_PORT ?? 4318);
  const http = createServer(async (req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    // Loopback only, strict Host/Origin. This demo is not a public MCP deployment.
    if (![ `127.0.0.1:${port}`, `localhost:${port}` ].includes(req.headers.host) ||
      (req.headers.origin && ![`http://127.0.0.1:${port}`, `http://localhost:${port}`].includes(req.headers.origin))) {
      res.writeHead(403); return res.end("Forbidden");
    }
    try {
      if (url.pathname === "/mcp") {
        if (req.method !== "POST") { res.writeHead(405); return res.end("POST required"); }
        const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
        const s = makeServer();
        res.on("close", () => { void transport.close(); void s.close(); });
        await s.connect(transport); await transport.handleRequest(req, res); return;
      }
      if (req.method !== "GET") { res.writeHead(405); return res.end(); }
      if (url.pathname === "/api/dashboard") {
        const [data, quota, advice, state] = await Promise.all([reader({ refresh: url.searchParams.get("refresh") === "1" }), readQuota(), readAdvice(), setupStatus().then(async st => ({ ...st, pluginUpdate: await pluginUpdate({ version }) }))]);
        res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" }); return res.end(JSON.stringify({ ...data, quota, advice, setup: setup(quota, advice, state) }));
      }
      if (url.pathname === "/favicon.ico") { res.writeHead(204); return res.end(); }
      if (["/", "/dashboard"].includes(url.pathname)) {
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" }); return res.end(await readHtml(true, ["widget", "thread", "global"].includes(url.searchParams.get("surface")) ? url.searchParams.get("surface") : "widget"));
      }
      res.writeHead(404); res.end("Not found");
    } catch (error) {
      if (!res.headersSent) res.writeHead(503, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(error.message) }));
    }
  });
  http.listen(port, "127.0.0.1", () => console.error(`ModelPlan demo: http://127.0.0.1:${port}`));
}
