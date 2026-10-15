import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import { createReader, filterDashboard } from "./data.mjs";
import { renderLineup, renderEffort, renderQuota } from "./render.mjs";
import { readQuota } from "./quota.mjs";

const version = JSON.parse(await readFile(new URL("./package.json", import.meta.url), "utf8")).version;
const UI_URI = "ui://modelplans/model-dashboard.html";
const reader = createReader();
const readHtml = async (preview = false) => {
  const [html, tokens, components, script, logo, comparison, lineup, presentation, curves, space] = await Promise.all([
    "ui/dashboard.html", "ui/kit/tokens.css", "ui/kit/components.css", "ui/dashboard.js", "ui/kit/logo.svg", "ui/comparison.js", "ui/lineup.js", "ui/presentation.js", "ui/curves.js", "ui/space.css",
  ].map(p => readFile(new URL("./" + p, import.meta.url), "utf8")));
  const fontFaces = await Promise.all([['Manrope',400,'manrope-400'],['Manrope',600,'manrope-600'],['JetBrains Mono',400,'jetbrains-mono-400'],['Share Tech Mono',400,'share-tech-mono-400']].map(async ([family,weight,file]) => {
    const bytes = await readFile(new URL('./ui/fonts/'+file+'.woff2', import.meta.url));
    return `@font-face{font-family:"${family}";font-weight:${weight};font-style:normal;font-display:swap;src:url(data:font/woff2;base64,${bytes.toString('base64')}) format('woff2')}`;
  }));
  return html.replace("<html lang=", preview ? "<html data-preview lang=" : "<html lang=")
    .replace("/*MODELPLAN_TOKENS*/", tokens).replace("/*MODELPLAN_COMPONENTS*/", components)
    .replace("/*MODELPLAN_SPACE*/", fontFaces.join("\n")+"\n"+space)
    .replace("/*MODELPLAN_SCRIPT*/", comparison+"\n"+lineup+"\n"+presentation+"\n"+curves+"\n"+script).replace("<!--MODELPLAN_LOGO-->", logo);
};
const annotations = { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false };
const inputSchema = { modelIds: z.array(z.string().max(180)).max(32).optional(), refresh: z.boolean().optional(),
  lang: z.enum(["zh", "en"]).optional(), view: z.enum(["lineup", "effort"]).optional(), modelId: z.string().max(180).optional() };
async function result(args) {
  try {
    const [published, quota] = await Promise.all([reader({ refresh: args.refresh }), readQuota()]);
    const data = filterDashboard(published, args.modelIds);
    const model = args.modelId ? data.models.find(m => m.id === args.modelId) : null;
    if (args.modelId && !model) throw Error("unknown_model_id");
    if (args.view === "effort" && !model) throw Error("effort_view_requires_modelId");
    return {
      structuredContent: { ...data, quota, focusModelId: model?.id ?? null, language: args.lang ?? "zh" },
      content: [{ type: "text", text: args.view === "effort" ? renderEffort(model, args.lang) : renderLineup(data, args.lang) },
        { type: "text", text: renderQuota(quota, args.lang) },
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
  s.registerResource("model-dashboard", UI_URI, { mimeType: "text/html;profile=mcp-app" }, async () => ({ contents: [{
    uri: UI_URI, mimeType: "text/html;profile=mcp-app", text: await readHtml(),
    _meta: { ui: { prefersBorder: false, csp: { connectDomains: [], resourceDomains: [] } }, "openai/ui": { availableDisplayModes: ["inline", "fullscreen"], preferredDisplayMode: "fullscreen" } },
  }] }));
  s.registerTool("get_model_dashboard", {
    title: "Read model capability, cost and recommended efforts", inputSchema, annotations,
    description: "Read the verified OpenAI lineup at recommended efforts (view=lineup), or one model's ladder relative to its recommendation (view=effort, modelId required). Text uses the modelplan CLI wording and order; structured values match the website. Includes public reset notices and the user's own Codex usage windows (used %, reset countdown, headroom), read locally from Codex's session logs and never sent anywhere. No host settings change.",
  }, result);
  s.registerTool("open_model_dashboard", {
    title: "Codex models & resets", inputSchema, annotations,
    description: "Open the visual ModelPlan model dashboard. Shows capability, reference-task cost ratios, recommended native reasoning efforts and effort comparisons. Accepts empty input to browse published OpenAI models, the user's own Codex quota (read locally) and Codex public reset announcements.",
    _meta: { ui: { resourceUri: UI_URI }, "openai/ui": { entrypoints: [{ type: "global" }, { type: "thread" }] } },
  }, result);
  return s;
}

if (!process.argv.includes("--http")) {
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
        const [data, quota] = await Promise.all([reader({ refresh: url.searchParams.get("refresh") === "1" }), readQuota()]);
        res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" }); return res.end(JSON.stringify({ ...data, quota }));
      }
      if (url.pathname === "/favicon.ico") { res.writeHead(204); return res.end(); }
      if (["/", "/dashboard"].includes(url.pathname)) {
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" }); return res.end(await readHtml(true));
      }
      res.writeHead(404); res.end("Not found");
    } catch (error) {
      if (!res.headersSent) res.writeHead(503, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(error.message) }));
    }
  });
  http.listen(port, "127.0.0.1", () => console.error(`ModelPlan demo: http://127.0.0.1:${port}`));
}
