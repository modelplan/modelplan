import { readFileSync } from 'node:fs';
import { parseSnapshot, type Snapshot } from '../app/src/snapshot.ts';
import type { Publication } from '../app/src/published.ts';

// The CLI's golden snapshot (cli/internal/snapshot/testdata/snapshot.json): the shell reads exactly
// what `modelplan desktop --json` prints.
export const goldenPath = new URL('../../cli/internal/snapshot/testdata/snapshot.json', import.meta.url);
export const golden = (): Snapshot => parseSnapshot(JSON.parse(readFileSync(goldenPath, 'utf8')));
export const at = Date.parse('2026-10-18T09:00:00Z');

const e = (effort: string, label: string, ability: number, cost: number, time: number) => ({ effort, label, ability, cost, time, timeEstimated: false });

export const publication: Publication = {
  publicationId: '0d726f2402d395a043fb170e', publishedAt: '2026-10-18T01:50:38Z', checkedAt: at, stale: false, error: null,
  models: [
    { id: 'opus', name: 'Claude Opus 5.5', developerId: 'anthropic', recommended: 'medium', harnessIds: { 'claude-code': ['claude-opus-5-5'] },
      configurations: [e('low', 'Low', 48.1, 1.62, 0.55), e('medium', 'Med', 55.4, 2.91, 0.8), e('high', 'High', 60.2, 3.98, 1), e('max', 'Max', 61, 6.4, 1.6)] },
    { id: 'astra', name: 'GPT-6 Astra', developerId: 'openai', recommended: 'medium', harnessIds: { codex: ['gpt-6-astra'] },
      configurations: [e('low', 'Low', 45, 2.21, 0.4), e('medium', 'Med', 51.4, 3.4, 0.45), e('high', 'High', 53.9, 3.97, 0.6)] },
  ],
  speedTiers: [{ id: 'codex-fast', harness: 'codex', tier: 'fast', label: 'Fast', billing: [{ billsTo: 'plan-quota', ratio: 2 }],
    models: [{ vendorModelId: 'gpt-6-astra', modelId: 'astra', speed: { ratio: 1.5, qualifier: 'approximate' } }] }],
};
