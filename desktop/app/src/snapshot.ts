// The personal snapshot, schema v1, as `modelplan desktop --json` prints it (docs/personal-snapshot.md).
// The CLI builds it on this machine; the shell only renders it. Later versions only add fields.

export const KIND = 'modelplan.personal-snapshot';

export type Lang = 'zh' | 'en';
export type Text = Partial<Record<Lang, string>>;

export interface QuotaWindow {
  kind: string; // five_hour | weekly | monthly | spend | unknown
  limit?: string; // an allowance kept apart from the main one (Codex: reserve)
  usedPercent: number | null;
  windowMinutes?: number;
  resetsAt: string | null;
  observedAt: string;
  remainingPercent: number | null;
  resetsInMinutes: number | null;
  ageMinutes: number | null;
  runsOutInMinutes: number | null;
  pace: string; // exhausted | tight | on_track | surplus | reset_passed | unknown
  usedUsd?: number;
  limitUsd?: number;
}

export interface Harness {
  model?: string;
  effort?: string;
  fastMode?: boolean;
  serviceTier?: string;
  observedAt?: string;
  attribution?: string;
  origin?: string;
}

export interface Account {
  source: string; // claude-code | codex | user | codexbar:<provider>
  plan?: string;
  observedAt: string;
  stale: boolean;
  harness?: Harness;
  windows: QuotaWindow[];
  via?: string;
  headroom: string; // spend | normal | conserve | exhausted | unknown
  deciding?: string;
  pool?: string;
}

export interface EffortRef { key: string; label: string; star: boolean }

export interface Session {
  source: string;
  observedAt?: string;
  attribution?: string;
  origin?: string;
  stale: boolean;
  model: { harnessId: string; id?: string; name?: string; developerId?: string };
  effort: EffortRef | null;
  recommended: EffortRef | null;
  vsRecommended: { abilityDelta: number | null; costRatio: number | null } | null;
  speed?: string;
  headroom: string;
  deciding?: string;
  pool?: string;
}

export interface Step {
  action: string;
  model?: string;
  modelName?: string;
  effort?: string;
  label?: string;
  recommended?: boolean;
  kind?: string;
  abilityDelta?: number;
  costRatio?: number;
}

export interface AdviceEvent {
  type: string;
  key: string;
  severity: string; // warn | info
  source: string;
  window?: string;
  limit?: string;
  at?: string;
  remainingPercent?: number;
  runsOutInMinutes?: number;
  model?: string;
  effort?: string;
  suggest?: Step;
  alternative?: Step;
  current?: Step;
  stale?: boolean;
  text: Text;
  short?: Text;
  inMenuBar: boolean;
}

export interface Measured {
  source: string;
  model: string;
  effort?: string;
  speed?: string;
  days: number;
  requests: number;
  turns: number;
  outputTokensPerSecond: number | null;
  ttftSeconds: number | null;
  turnSeconds: number | null;
  turnOutputTokens: number | null;
}

export interface SourceStatus { source: string; status: string; reason?: string }

// One local day of one model: what the CLI saw in the logs it reads, across efforts and speed
// modes (daily[], dailyLong[]). A day without a row is not a day without use: it is left out.
export interface TokenKinds {
  inputTokens?: number | null; // uncached input; null means not recorded for every request
  cacheReadTokens?: number | null;
  cacheWriteTokens?: number | null;
}
export interface GenerationRate {
  window: string; value: number | null; n: number; min: number; status: string;
  reason?: string; source?: string; scope?: string; lastAt?: string | null;
}
export interface LiveSession {
  ref: string; source: string; model: string; effort: string; effortStatus: string; speed: string;
  projectRef: string | null; subscriptionRef: string | null;
  startedAt: string; lastAt: string; status: 'running' | 'idle'; rate: GenerationRate;
}
export interface PerfSums extends TokenKinds {
  observedRequests: number; observedOutputTokens: number; eligibleRequests: number;
  eligibleOutputTokens: number; genMs: number;
}
export interface PerfWindow { sums: PerfSums; metrics: Record<string, { value: number | null; status: string; n: number; min: number; reason?: string }> }
export interface PerfStat { source: string; model: string; windows: { today?: PerfWindow; recent7d: PerfWindow; recent30d: PerfWindow } }
export interface TodayTotal { source: string; sums: PerfSums }
export interface HourlyTotal extends TokenKinds {
  hour: string; source: string; model: string; observedOutputTokens: number; observedRequests: number;
}
export interface DailyTotal extends TokenKinds {
  day: string; // local date, YYYY-MM-DD
  source: string;
  model: string;
  observedOutputTokens: number;
  observedRequests: number;
}

// The first day a daily list covers (null before any ledger) and whether recording is on.
export interface DailyCoverage { from: string | null; recording: boolean }

export interface Snapshot {
  schemaVersion: number;
  kind: string;
  generatedAt: string;
  cliVersion: string;
  publication: {
    publicationId: string;
    publishedAt?: string;
    checkedAt?: string;
    verifiedAt?: string;
    stale: boolean;
    lastError?: string;
  } | null;
  sessions: Session[];
  accounts: Account[];
  sources: SourceStatus[];
  events: AdviceEvent[];
  measured: Measured[];
  liveSessions?: LiveSession[];
  todayTotals?: TodayTotal[];
  hourly?: HourlyTotal[];
  perfStats?: PerfStat[];
  daily: DailyTotal[]; // the last 30 days (CLI 0.5.27+; [] before)
  dailyCoverage?: DailyCoverage;
  dailyLong: DailyTotal[]; // the last 371 days, for a year-long heatmap (CLI 0.5.32+; [] before)
  dailyLongCoverage?: DailyCoverage;
  projectLabels?: boolean; // project folder names are on (the default since CLI 0.5.32)
  recording: boolean;
  note: string;
}

// parseSnapshot accepts schema v1 and anything later of the same kind (later versions only add
// fields). It fills missing lists so the views never see null.
export function parseSnapshot(raw: unknown): Snapshot {
  const v = typeof raw === 'string' ? JSON.parse(raw) : raw;
  if (!v || typeof v !== 'object') throw Error('snapshot_invalid');
  const s = v as Snapshot;
  if (s.kind !== KIND) throw Error('snapshot_kind');
  if (!Number.isInteger(s.schemaVersion) || s.schemaVersion < 1) throw Error('snapshot_version');
  for (const k of ['sessions', 'accounts', 'sources', 'events', 'measured', 'daily', 'dailyLong', 'liveSessions', 'todayTotals', 'hourly', 'perfStats'] as const) {
    if (!Array.isArray(s[k])) (s as unknown as Record<string, unknown>)[k] = [];
  }
  for (const a of s.accounts) if (!Array.isArray(a.windows)) a.windows = [];
  return s;
}

// inPool: the window meters the allowance the account draws from now (Codex Reserve or the main
// one), as the CLI decides headroom. An account without a window of its pool keeps every window.
export function inPool(a: Account, w: QuotaWindow): boolean {
  const pool = a.pool ?? '';
  return (w.limit ?? '') === pool || !a.windows.some(x => (x.limit ?? '') === pool);
}

export const accountOf = (s: Snapshot, x: Session): Account | undefined => s.accounts.find(a => a.source === x.source);
