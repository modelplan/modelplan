// The app: one refresh loop that reads the snapshot, updates the menu bar, sends the notifications
// that are due and renders the open view. The popover's page keeps running while hidden, so the
// loop also runs with the popover closed. The expanded window refreshes when shown.
import type { Platform } from "./platform.ts";
import { parseSnapshot, type Lang, type Snapshot } from "./snapshot.ts";
import { createPublication } from "./publication.ts";
import type { Publication } from "./published.ts";
import { menuBar } from "./menubar.ts";
import { defaults, due, type Category, type Notified } from "./notify.ts";
import { fill, pickLang, words } from "./i18n.ts";
import { esc } from "./views/html.ts";
import { renderNow } from "./views/now.ts";
import { renderQuota } from "./views/quota.ts";
import { renderEffort, type EffortChoice } from "./views/effort.ts";
import { renderSettings, type Settings } from "./views/settings.ts";

export const REFRESH = 3 * 60 * 1000;
type Tab = "now" | "quota" | "effort" | "settings";

export interface AppState {
  tab: Tab;
  snapshot: Snapshot | null;
  publication: Publication | null;
  error: string;
  settings: Settings;
  effort: EffortChoice | null;
  notifyNote: string;
  busy: boolean;
}

export function startApp(
  root: HTMLElement,
  platform: Platform,
  logo: string,
  brandName = "ModelPlan Community",
) {
  const state: AppState = {
    tab: "now",
    snapshot: null,
    publication: null,
    error: "",
    effort: null,
    notifyNote: "",
    busy: false,
    settings: { lang: "auto", menuBar: "auto", notify: { ...defaults } },
  };
  const readPublication = createPublication(platform);
  const lang = (): Lang => pickLang(state.settings.lang, navigator.language);
  // The popover's page owns the menu bar and the notifications; the expanded window only shows.
  const leader = platform.surface === "popover";

  function render() {
    const l = lang(),
      t = words(l),
      now = Date.now();
    document.documentElement.lang = l === "zh" ? "zh-CN" : "en";
    const s = state.snapshot;
    let body = "";
    if (state.tab === "settings")
      body = renderSettings(s, state.settings, l, state.notifyNote);
    else if (!s) body = `<p class="empty">${esc(state.error || "…")}</p>`;
    else if (state.tab === "now") body = renderNow(s, l, now);
    else if (state.tab === "quota") body = renderQuota(s, l, now);
    else body = renderEffort(s, state.publication, l, state.effort);
    const tabs = (["now", "quota", "effort"] as const)
      .map(
        (k) =>
          `<button type="button" role="tab" class="tab" data-tab="${k}" aria-selected="${state.tab === k}">${esc(t.tabs[k])}</button>`,
      )
      .join("");
    const p = state.publication;
    const pub = p
      ? fill(t.publication, p.publicationId.slice(0, 8)) +
        (p.stale ? " · " + t.pubStale : "")
      : t.noPublication;
    root.innerHTML = `<div class="shell mp-panel" data-surface="${platform.surface}">
<header class="top"><span class="logo" aria-hidden="true">${logo}</span><b class="brand">${esc(brandName)}</b><nav role="tablist">${tabs}</nav>
<span class="actions"><button type="button" class="utility${state.busy ? " busy" : ""}" data-action="refresh" title="${esc(t.refresh)}" aria-label="${esc(t.refresh)}">↻</button>
<button type="button" class="utility" data-tab="settings" aria-pressed="${state.tab === "settings"}" title="${esc(t.settings)}" aria-label="${esc(t.settings)}">⚙</button>
${platform.surface === "popover" ? `<button type="button" class="utility" data-action="expand" title="${esc(t.expand)}" aria-label="${esc(t.expand)}">⤢</button>` : ""}</span></header>
${state.error && s ? `<p class="error">${esc(state.error)}</p>` : ""}
<main class="body">${body}</main>
<footer class="foot"><span>${esc(pub)}</span><span>${esc(s ? "CLI " + s.cliVersion : "")}</span>
<button type="button" class="link" data-action="quit">${esc(t.quit)}</button></footer></div>`;
  }

  async function notifyDue(s: Snapshot) {
    const notified = (await platform.settings.get<Notified>("notified")) ?? {};
    const r = due(
      s.events,
      state.settings.notify,
      notified,
      Date.now(),
      lang(),
    );
    for (const n of r.send)
      await platform.notify({ title: n.title, body: n.body });
    if (
      r.send.length ||
      Object.keys(r.notified).length !== Object.keys(notified).length
    )
      await platform.settings.set("notified", r.notified);
  }

  // Settings are read again on each refresh: the other surface may have changed them.
  async function loadSettings() {
    const saved = await platform.settings
      .get<Partial<Settings>>("settings")
      .catch(() => undefined);
    if (saved)
      state.settings = {
        ...state.settings,
        ...saved,
        notify: { ...defaults, ...saved.notify },
      };
  }

  let running: Promise<void> | null = null;
  async function refresh(forcePublication = false) {
    if (running) return running;
    running = (async () => {
      state.busy = true;
      render();
      let pub: Promise<void> | undefined;
      try {
        await loadSettings();
        // The published data only feeds the Effort view; the snapshot does not wait for it.
        pub = readPublication(forcePublication).then((p) => {
          if (p) state.publication = p;
          render();
        });
        state.snapshot = parseSnapshot(await platform.snapshot());
        state.error = "";
        render();
        if (leader) {
          const m = menuBar(state.snapshot, lang(), state.settings.menuBar);
          await platform.setMenuBar(m.title, m.tooltip).catch(() => {});
          await notifyDue(state.snapshot).catch(() => {});
        }
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        state.error =
          msg === "cli_missing"
            ? words(lang()).cliMissing
            : fill(words(lang()).cliFailed, msg);
      } finally {
        await pub?.catch(() => {});
        state.busy = false;
        render();
      }
    })().finally(() => {
      running = null;
    });
    return running;
  }

  root.addEventListener("click", async (ev) => {
    const el = (ev.target as HTMLElement).closest<HTMLElement>(
      "[data-tab],[data-action],[data-effort-source],tr[data-effort]",
    );
    if (!el) return;
    if (el.dataset.tab) {
      state.tab = (
        el.dataset.tab === "settings" && state.tab === "settings"
          ? "now"
          : el.dataset.tab
      ) as Tab;
      render();
    } else if (el.dataset.effortSource) {
      state.effort = { source: el.dataset.effortSource };
      render();
    } else if (el.dataset.effort) {
      state.effort = {
        source:
          state.effort?.source ??
          root.querySelector<HTMLElement>(
            "[data-effort-source][aria-selected=true]",
          )?.dataset.effortSource ??
          state.snapshot?.sessions[0]?.source ??
          "",
        effort: el.dataset.effort,
      };
      render();
    } else if (el.dataset.action === "refresh") await refresh(true);
    else if (el.dataset.action === "expand") await platform.expand();
    else if (el.dataset.action === "quit") await platform.quit();
    else if (el.dataset.action === "test-notify") {
      const t = words(lang());
      const ok = await platform.notify({
        title: "ModelPlan",
        body: t.notify.testBody,
      });
      state.notifyNote = ok ? "" : t.notify.denied;
      render();
    }
  });
  root.addEventListener("change", async (ev) => {
    const el = ev.target as HTMLInputElement | HTMLSelectElement;
    if (el.dataset.notify)
      state.settings.notify[el.dataset.notify as Category] = (
        el as HTMLInputElement
      ).checked;
    else if (el.dataset.setting === "lang")
      state.settings.lang = el.value as Settings["lang"];
    else if (el.dataset.setting === "menuBar")
      state.settings.menuBar = el.value;
    else return;
    await platform.settings.set("settings", state.settings);
    if (state.snapshot && leader) {
      const m = menuBar(state.snapshot, lang(), state.settings.menuBar);
      await platform.setMenuBar(m.title, m.tooltip).catch(() => {});
    }
    render();
  });

  (async () => {
    await loadSettings();
    render();
    platform.onShown(() => void refresh());
    await refresh();
    if (leader) setInterval(() => void refresh(), REFRESH);
  })();
  return { state, refresh, render };
}
