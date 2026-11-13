import { invoke } from '@tauri-apps/api/core';
import { getCurrentWindow } from '@tauri-apps/api/window';
import { fetch as httpFetch } from '@tauri-apps/plugin-http';
import { isPermissionGranted, requestPermission, sendNotification } from '@tauri-apps/plugin-notification';
import { openUrl } from '@tauri-apps/plugin-opener';
import { LazyStore } from '@tauri-apps/plugin-store';
import type { Platform, Store } from './platform.ts';
import { BASE } from './published.ts';

const store = (file: string): Store => {
  const s = new LazyStore(file, { defaults: {}, autoSave: 200 });
  return { get: k => s.get(k), set: (k, v) => s.set(k, v) };
};

export function tauriPlatform(): Platform {
  const win = getCurrentWindow();
  return {
    kind: 'tauri',
    surface: win.label === 'popover' ? 'popover' : 'window',
    // The bundled CLI runs `modelplan desktop --json` (src-tauri/src/lib.rs).
    snapshot: () => invoke<string>('snapshot'),
    fetch(url, init) {
      if (!url.startsWith(BASE + '/publications/')) return Promise.reject(Error('publication_url_not_allowed'));
      return httpFetch(url, { headers: init?.headers, signal: init?.signal, maxRedirections: 0, connectTimeout: 15000 });
    },
    async notify({ title, body }) {
      let ok = await isPermissionGranted();
      if (!ok) ok = (await requestPermission()) === 'granted';
      if (ok) sendNotification({ title, body });
      return ok;
    },
    openURL: url => openUrl(url),
    settings: store('settings.json'),
    cache: store('publication.json'),
    setMenuBar: (title, tooltip) => invoke('set_menu_bar', { title, tooltip }),
    expand: () => invoke('expand'),
    quit: () => invoke('quit'),
    onShown(cb) {
      void win.onFocusChanged(({ payload }) => { if (payload) cb(); });
    },
  };
}
