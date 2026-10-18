// Builds the front end into app/dist: the TypeScript app (with the open Codex dashboard curves),
// the shared hangar kit and its fonts. No network, no generated code checked in.
import { build } from 'esbuild';
import { copyFile, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';

const here = p => new URL(p, import.meta.url).pathname;
const kit = p => here('../codex/ui/' + p);
const dist = here('app/dist/');

await rm(dist, { recursive: true, force: true });
await mkdir(dist + 'fonts', { recursive: true });
await build({
  entryPoints: [here('app/src/main.ts')], outfile: dist + 'main.js', bundle: true, format: 'esm',
  target: ['safari16'], minify: true, nodePaths: [here('node_modules')], loader: { '.svg': 'text' }, legalComments: 'eof', logLevel: 'warning',
});
const fonts = [['Manrope', 400, 'manrope-400'], ['Manrope', 600, 'manrope-600'], ['JetBrains Mono', 400, 'jetbrains-mono-400'], ['Share Tech Mono', 400, 'share-tech-mono-400']];
for (const f of await readdir(kit('fonts'))) if (/\.(woff2|txt)$/.test(f)) await copyFile(kit('fonts/' + f), dist + 'fonts/' + f);
const faces = fonts.map(([family, weight, file]) => `@font-face{font-family:"${family}";font-weight:${weight};font-style:normal;font-display:swap;src:url(fonts/${file}.woff2) format("woff2")}`);
const css = await Promise.all([kit('kit/tokens.css'), kit('kit/components.css'), here('app/style.css')].map(p => readFile(p, 'utf8')));
await writeFile(dist + 'app.css', [...faces, ...css].join('\n'));
await copyFile(here('app/index.html'), dist + 'index.html');
