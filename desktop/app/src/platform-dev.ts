// The browser platform for `npm run dev` (dev.mjs): the snapshot and the published data come
// through the local dev server, settings live in localStorage, notifications in the page.
import type { Platform, Store } from './platform.ts';

const local = (prefix: string): Store => {
  const mem = new Map<string, unknown>();
  return {
    async get<T>(k: string) {
      try {
        const v = localStorage.getItem(prefix + k);
        return v == null ? undefined : (JSON.parse(v) as T);
      } catch {
        return mem.get(k) as T | undefined;
      }
    },
    async set(k, v) {
      mem.set(k, v);
      try { localStorage.setItem(prefix + k, JSON.stringify(v)); } catch { /* private mode or full */ }
    },
  };
};

export function devPlatform(): Platform {
  const q = new URLSearchParams(location.search);
  // What the menu bar and the notifications would show.
  const bar = document.createElement('div');
  bar.className = 'dev-bar';
  bar.innerHTML = '<span id="dev-notify" class="dim"></span><b id="dev-menubar">◆</b>';
  document.body.prepend(bar);
  document.body.style.paddingTop = '24px';
  return {
    kind: 'dev',
    surface: q.get('surface') === 'window' ? 'window' : 'popover',
    async snapshot() {
      const r = await fetch('/dev/snapshot' + (q.has('fixture') ? '?fixture=1' : ''));
      if (!r.ok) throw Error((await r.text()) || 'snapshot_http_' + r.status);
      return r.json();
    },
    fetch: (url, init) => fetch('/dev/fetch?u=' + encodeURIComponent(url), { headers: init?.headers, signal: init?.signal }),
    async notify({ title, body }) {
      console.info('[notify]', title, body);
      const log = document.getElementById('dev-notify');
      if (log) log.textContent = title + ' — ' + body;
      return true;
    },
    openURL: async url => { window.open(url, '_blank', 'noopener'); },
    settings: local('mp.settings.'),
    // The digest is too large for localStorage; the dev page keeps it in memory.
    cache: (() => { const m = new Map<string, unknown>(); return { get: async k => m.get(k) as never, set: async (k, v) => { m.set(k, v); } }; })(),
    setMenuBar: async (title, tooltip) => {
      const el = document.getElementById('dev-menubar');
      if (el) { el.textContent = title || '◆'; el.title = tooltip; }
    },
    expand: async () => { window.open('?surface=window' + (q.has('fixture') ? '&fixture=1' : ''), '_blank'); },
    quit: async () => {},
    onShown(cb) { addEventListener('focus', cb); },
  };
}
