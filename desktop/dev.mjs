// Browser dev server for the shell's UI (npm run dev): http://127.0.0.1:5174/.
// /dev/snapshot runs `modelplan desktop --json` (MODELPLAN_CLI, else modelplan on PATH); with
// ?fixture=1, or when the CLI fails, it serves the CLI's golden snapshot with its times moved to
// now. /dev/fetch proxies the published data only. Loopback only.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { extname, join, normalize } from 'node:path';

const port = Number(process.env.PORT || 5174);
const dist = new URL('./app/dist/', import.meta.url).pathname;
const fixture = new URL('../cli/internal/snapshot/testdata/snapshot.json', import.meta.url).pathname;
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.css': 'text/css', '.woff2': 'font/woff2', '.txt': 'text/plain' };
const csp = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self'; img-src 'self' data:; connect-src 'self'";

const iso = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$/;
// shifted: every timestamp moved by the same amount, so ages and countdowns read as live.
export function shifted(v, by) {
  if (typeof v === 'string' && iso.test(v)) return new Date(Date.parse(v) + by).toISOString();
  if (Array.isArray(v)) return v.map(x => shifted(x, by));
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, shifted(x, by)]));
  return v;
}
async function golden() {
  const s = JSON.parse(await readFile(fixture, 'utf8'));
  return shifted(s, Date.now() - Date.parse(s.generatedAt));
}
const cli = () => new Promise((ok, fail) => execFile(process.env.MODELPLAN_CLI || 'modelplan', ['desktop', '--json'], { timeout: 60000, maxBuffer: 8 << 20 },
  (e, out) => (e ? fail(e) : ok(JSON.parse(out)))));

createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  try {
    if (url.pathname === '/dev/snapshot') {
      let body;
      if (url.searchParams.has('fixture')) body = await golden();
      else body = await cli().catch(async e => { console.warn('CLI failed, serving the fixture:', e.message); return golden(); });
      res.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify(body));
    } else if (url.pathname === '/dev/fetch') {
      const target = url.searchParams.get('u') ?? '';
      if (!target.startsWith('https://modelplan.ai/publications/')) return void res.writeHead(403).end('publication URLs only');
      const r = await fetch(target, { headers: req.headers['if-none-match'] ? { 'if-none-match': req.headers['if-none-match'] } : {}, redirect: 'error' });
      const h = { 'content-type': r.headers.get('content-type') ?? 'application/octet-stream' };
      if (r.headers.get('etag')) h.etag = r.headers.get('etag');
      res.writeHead(r.status, h).end(Buffer.from(await r.arrayBuffer()));
    } else {
      const path = normalize(join(dist, url.pathname === '/' ? 'index.html' : url.pathname));
      if (!path.startsWith(dist)) return void res.writeHead(403).end();
      const bytes = await readFile(path).catch(() => null);
      if (!bytes) return void res.writeHead(404).end();
      res.writeHead(200, { 'content-type': types[extname(path)] ?? 'application/octet-stream', 'content-security-policy': csp, 'cache-control': 'no-store' }).end(bytes);
    }
  } catch (e) {
    res.writeHead(500).end(String(e?.message ?? e));
  }
}).listen(port, '127.0.0.1', () => console.log(`ModelPlan desktop UI: http://127.0.0.1:${port}/ (?fixture=1 for the golden snapshot)`));
