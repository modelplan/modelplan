// The platform adapter: everything the UI needs from the host. The desktop implements it with the
// bundled CLI and Tauri plugins (platform-tauri.ts), the browser dev server with HTTP
// (platform-dev.ts), and a mobile app later with sync and push.

export interface Store {
  get<T>(key: string): Promise<T | undefined>;
  set(key: string, value: unknown): Promise<void>;
}

export interface Platform {
  kind: 'tauri' | 'dev';
  // The personal snapshot as the CLI prints it (unparsed).
  snapshot(): Promise<unknown>;
  // fetch for the published data only (https://modelplan.ai/publications/…).
  fetch(url: string, init?: { headers?: Record<string, string>; signal?: AbortSignal }): Promise<Response>;
  notify(n: { title: string; body: string }): Promise<boolean>;
  openURL(url: string): Promise<void>;
  settings: Store;
  // The verified publication cache (large; kept apart from settings).
  cache: Store;
  setMenuBar(title: string, tooltip: string): Promise<void>;
  expand(): Promise<void>;
  quit(): Promise<void>;
  // Called when the popover or window is shown, to refresh at once.
  onShown(cb: () => void): void;
  // The surface this page runs in.
  surface: 'popover' | 'window';
}

export const isTauri = (): boolean => typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
