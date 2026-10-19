export type Observation = {
  source: string;
  model: string;
  effort: string;
  ability: number | null;
  cost: number | null;
  seconds: number | null;
  reliability: number;
  cohort: string;
  url: string;
  note: string;
  evidenceWindow?: string;
  sourceSnapshotId?: string;
  recordId?: string;
  repeats?: number | null;
  timingPopulation?: string;
  fallbackEvents?: unknown;
  isUnavailable?: boolean;
  boundary?: string;
  harness?: string;
  harnessVersions?: unknown;
  datasets?: string[];
  referenceSeconds?: number | null;
  referenceCost?: number | null;
};
export type UnifiedInput = {
  methodId: string;
  builtAt: string;
  versions: Record<string, unknown>;
  sources: Record<
    string,
    {
      label: string;
      publisher: string;
      ability: number;
      cost: number;
      time: number;
    }
  >;
  references: Record<
    string,
    Record<
      string,
      {
        status: string;
        mu?: number;
        sd?: number;
        geometricReference?: number | null;
      }
    >
  >;
  models: {
    id: string;
    name: string;
    developer: string;
    recommended: string | null;
    rows: { effort: string; observations: Observation[] }[];
  }[];
};
export type UnifiedProfile = {
  id: string;
  name: string;
  recommended: string | null;
  rows: {
    effort: string;
    status: string;
    ability: {
      value: number | null;
      completeness: number;
      independentPublishers: number;
      used: { source: string; cohort: string; weight: number; kind: string }[];
    };
    expense: {
      value: number | null;
      completeness: number;
      used: { source: string; cohort: string }[];
    };
    time: {
      value: number | null;
      absoluteSeconds: number | null;
      selectedSource: string | null;
      selectedBoundary: string | null;
      completeness: number;
      used: {
        source: string;
        cohort: string;
        note: string;
        absolute: number;
        boundary: string;
      }[];
    };
    observations: Observation[];
  }[];
};
export function calculateMetrics(
  data: UnifiedInput,
  state?: Record<string, unknown>,
): UnifiedProfile[];
