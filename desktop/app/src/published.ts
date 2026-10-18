// The published data the views use: a shape adapter over the verified client digest. Every figure
// is the producer's.

export const BASE = 'https://modelplan.ai';
const STALE = 48 * 3600 * 1000;

export interface Effort {
  effort: string;
  label: string;
  ability?: number | null;
  cost?: number | null;
  time?: number | null;
  timeEstimated?: boolean;
}

export interface Model {
  id: string;
  name: string;
  developerId: string;
  recommended: string;
  harnessIds: Record<string, string[]>;
  configurations: Effort[];
}

export interface SpeedTier {
  id: string;
  harness: string;
  tier: string;
  label: string;
  billing?: { billsTo: string; ratio: number }[];
  models: { vendorModelId: string; modelId: string | null; speed?: { ratio: number; qualifier: string } }[];
}

export interface Publication {
  publicationId: string;
  publishedAt: string;
  checkedAt: number | null;
  stale: boolean;
  error: string | null;
  models: Model[];
  speedTiers: SpeedTier[];
}

export interface Digest { manifest: { publicationId: string; publishedAt: string }; component: { data: Record<string, unknown> } }

// project: the shape the views use. A shape adapter only: every figure is the producer's.
export function project(d: Digest, checkedAt: number | null, error: string | null, now: number): Publication {
  const data = d.component.data as { models: (Omit<Model, 'configurations'> & { efforts: Effort[] })[]; speedTiers?: SpeedTier[] };
  return {
    publicationId: d.manifest.publicationId,
    publishedAt: d.manifest.publishedAt,
    checkedAt,
    error,
    stale: !!error || checkedAt == null || now - checkedAt > STALE,
    models: data.models.map(({ efforts, ...m }) => ({ ...m, configurations: efforts })),
    speedTiers: data.speedTiers ?? [],
  };
}

// The model a harness reports, by its harness ids.
export function modelFor(p: Publication | null, harness: string, harnessId: string | undefined): Model | undefined {
  if (!p || !harnessId) return undefined;
  return p.models.find(m => m.id === harnessId) ?? p.models.find(m => m.harnessIds?.[harness]?.includes(harnessId));
}
