// shared/public-storage-codec.ts
var MAGIC = [77, 80, 71, 90, 49, 0];
var HEADER = 10;
async function decodePublicationStorage(bytes, max = 5e7) {
  if (!MAGIC.every((v, i) => bytes[i] === v)) return bytes;
  try {
    if (bytes.length <= HEADER) throw Error();
    const length = new DataView(
      bytes.buffer,
      bytes.byteOffset,
      bytes.byteLength
    ).getUint32(6);
    if (length < 4096 || length > max) throw Error();
    const reader = new Blob([new Uint8Array(bytes.slice(HEADER))]).stream().pipeThrough(new DecompressionStream("gzip")).getReader();
    const chunks = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.length;
        if (size > length) throw Error();
        chunks.push(value);
      }
    } finally {
      await reader.cancel().catch(() => {
      });
    }
    if (size !== length) throw Error();
    const plain = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      plain.set(chunk, offset);
      offset += chunk.length;
    }
    return plain;
  } catch {
    throw Error("publication_storage_codec_corrupt");
  }
}

// shared/client-multipliers.ts
import { z } from "zod";
var text = z.string().min(1);
var instant = z.iso.datetime({ offset: true });
var ids = z.array(text);
var clientMultiplierSchema = z.object({
  ruleId: text,
  provider: text,
  kind: z.enum(["base", "peak", "holiday", "night"]),
  models: ids,
  clients: ids,
  planIds: ids,
  generations: ids,
  region: text,
  timezone: text,
  multiplier: z.number().finite().nonnegative().nullable(),
  startsAt: instant,
  endsAt: instant,
  priority: z.number().int(),
  status: z.enum(["CONFIRMED", "TENTATIVE"]),
  minClientVersions: z.record(z.string(), text),
  requiresQuotaAvailable: z.boolean(),
  conditions: z.array(z.string()),
  url: z.url()
}).strict().refine(
  (v) => Date.parse(v.endsAt) > Date.parse(v.startsAt),
  "invalid_multiplier_window"
);
var clientMultiplierPackSchema = z.object({
  version: z.literal("client-multipliers-v1"),
  from: instant,
  to: instant,
  selection: z.literal("highest-priority-no-stacking"),
  windows: z.array(clientMultiplierSchema)
}).strict().refine(
  (v) => Date.parse(v.to) > Date.parse(v.from),
  "invalid_multiplier_horizon"
);

// shared/client-digest.ts
import { z as z2 } from "zod";

// data/client-harness-aliases.json
var client_harness_aliases_default = {
  revision: "2026-10-11.2",
  checkedAt: "2026-10-11",
  records: [
    {
      modelId: "opus",
      sourceModelId: "anthropic/claude-opus-5-5",
      harnessIds: {
        api: [
          "claude-opus-5-5"
        ],
        "claude-code": [
          "claude-opus-5-5"
        ],
        codex: []
      },
      sourceUrls: [
        "https://platform.claude.com/docs/en/models/overview",
        "https://code.claude.com/docs/en/model-config"
      ],
      qualification: "Anthropic provider; compatible client and managed allowlists still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "sonnet-5.5",
      sourceModelId: "anthropic/claude-sonnet-5-5",
      harnessIds: {
        api: [
          "claude-sonnet-5-5"
        ],
        "claude-code": [
          "claude-sonnet-5-5"
        ],
        codex: []
      },
      sourceUrls: [
        "https://platform.claude.com/docs/en/models/overview",
        "https://code.claude.com/docs/en/model-config"
      ],
      qualification: "Anthropic provider; compatible client and managed allowlists still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "auto:anthropic:ccb37fec2677f068",
      sourceModelId: "anthropic/claude-haiku-5-5",
      harnessIds: {
        api: [
          "claude-haiku-5-5"
        ],
        "claude-code": [
          "claude-haiku-5-5"
        ],
        codex: []
      },
      sourceUrls: [
        "https://platform.claude.com/docs/en/models/overview",
        "https://code.claude.com/docs/en/model-config"
      ],
      qualification: "Anthropic provider; compatible client and managed allowlists still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "astra",
      sourceModelId: "openai/gpt-6-astra",
      harnessIds: {
        api: [
          "gpt-6-astra"
        ],
        "claude-code": [],
        codex: [
          "gpt-6-astra"
        ]
      },
      sourceUrls: [
        "https://developers.openai.com/api/docs/models/gpt-6-astra",
        "https://learn.chatgpt.com/docs/models"
      ],
      qualification: "Codex sign-in, rollout, client and workspace restrictions still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "sol-6.1",
      sourceModelId: "openai/gpt-6.1-sol",
      harnessIds: {
        api: [
          "gpt-6.1-sol"
        ],
        "claude-code": [],
        codex: [
          "gpt-6.1-sol"
        ]
      },
      sourceUrls: [
        "https://developers.openai.com/api/docs/models",
        "https://learn.chatgpt.com/docs/models"
      ],
      qualification: "Codex sign-in, rollout, client and workspace restrictions still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "luna",
      sourceModelId: "openai/gpt-6-luna",
      harnessIds: {
        api: [
          "gpt-6-luna"
        ],
        "claude-code": [],
        codex: [
          "gpt-6-luna"
        ]
      },
      sourceUrls: [
        "https://developers.openai.com/api/docs/models",
        "https://learn.chatgpt.com/docs/models"
      ],
      qualification: "Codex sign-in, rollout, client and workspace restrictions still apply.",
      requiredEndpoints: {}
    },
    {
      modelId: "glm",
      sourceModelId: "zhipuai/glm-5.3",
      harnessIds: {
        api: [
          "glm-5.3"
        ],
        "claude-code": [
          "glm-5.3[1m]"
        ],
        codex: []
      },
      sourceUrls: [
        "https://docs.z.ai/guides/llm/glm-5.3",
        "https://docs.z.ai/devpack/tool/claude"
      ],
      qualification: "Claude Code identifier requires custom Z.ai endpoint https://api.z.ai/api/anthropic and explicit family-model configuration; never resolve global opus/sonnet aliases to GLM.",
      requiredEndpoints: {
        "claude-code": "https://api.z.ai/api/anthropic"
      }
    },
    {
      modelId: "fable",
      sourceModelId: "anthropic/claude-fable-5-1",
      harnessIds: {
        api: [
          "claude-fable-5-1"
        ],
        "claude-code": [
          "claude-fable-5-1"
        ],
        codex: []
      },
      sourceUrls: [
        "https://platform.claude.com/docs/en/models/fable-5-1/overview",
        "https://code.claude.com/docs/en/model-config#available-models",
        "https://code.claude.com/docs/en/model-config#work-with-fable"
      ],
      qualification: "Anthropic provider; Claude Code v2.1.257+; managed and account restrictions still apply. No account entitlement or inference verified.",
      requiredEndpoints: {}
    },
    {
      modelId: "auto:anthropic:2a365f1cb3bef456",
      sourceModelId: "anthropic/claude-opus-5",
      harnessIds: {
        api: [
          "claude-opus-5"
        ],
        "claude-code": [
          "claude-opus-5"
        ],
        codex: []
      },
      sourceUrls: [
        "https://platform.claude.com/docs/en/models/opus-5/overview",
        "https://code.claude.com/docs/en/model-config#available-models"
      ],
      qualification: "Anthropic provider; active legacy Opus 5, distinct from Opus 5.5; compatible client, managed and account restrictions still apply. No account entitlement or inference verified.",
      requiredEndpoints: {}
    }
  ]
};

// data/coding-tool-models.json
var coding_tool_models_default = {
  revision: "2026-10-09.1",
  scope: "Coding tool selectable versions, not API catalog or account entitlement guarantee",
  archiveDays: 30,
  records: [
    {
      modelId: "sol-6.1",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "astra",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "sol",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "luna",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "sol-5.6",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "terra-5.6",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "luna-5.6",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access."
    },
    {
      modelId: "gpt-5.5",
      tool: "chatgpt-codex",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://learn.chatgpt.com/docs/models",
      qualification: "Paid-plan/client/workspace rollout and the account picker determine actual access.",
      announcedRetirement: {
        date: "2026-10-14",
        precision: "date-only",
        exactCutoverAt: null,
        sourceUrl: "https://learn.chatgpt.com/docs/models"
      }
    },
    {
      modelId: "opus",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Account/organization allowlist, client version and included allowance versus usage credits vary by plan."
    },
    {
      modelId: "sonnet-5.5",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Account/organization allowlist, client version and included allowance versus usage credits vary by plan."
    },
    {
      modelId: "fable",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Pro access requires extra usage credits; Max includes Fable within a weekly cap. Verify account/client."
    },
    {
      modelId: "haiku-4.5",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Account/organization allowlist, client version and included allowance versus usage credits vary by plan."
    },
    {
      modelId: "sonnet",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Account/organization allowlist, client version and included allowance versus usage credits vary by plan."
    },
    {
      modelId: "glm",
      tool: "glm-coding-plan",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://docs.bigmodel.cn/cn/coding-plan/overview",
      qualification: "Mainland and Z.ai international products remain separate; native effort exposure is unverified."
    },
    {
      modelId: "glm-5.3-flash",
      tool: "glm-coding-plan",
      status: "current",
      verifiedAt: "2026-09-30",
      sourceUrl: "https://docs.bigmodel.cn/cn/coding-plan/overview",
      qualification: "Mainland and Z.ai international products remain separate; native effort exposure is unverified."
    },
    {
      modelId: "auto:anthropic:ccb37fec2677f068",
      tool: "claude-code",
      status: "current",
      verifiedAt: "2026-10-09",
      sourceUrl: "https://code.claude.com/docs/en/model-config",
      qualification: "Haiku5.5 requires Claude Code2.1.293+. Native Low/Medium/High/XHigh/Max are supported, default Medium; organization/account restrictions and the official subscription/API channel remain separate."
    }
  ],
  sources: [
    {
      id: "openai-coding-models",
      url: "https://learn.chatgpt.com/docs/models.md",
      provider: "openai"
    },
    {
      id: "claude-code-models",
      url: "https://code.claude.com/docs/en/model-config.md",
      provider: "anthropic"
    },
    {
      id: "zhipu-coding-models",
      url: "https://docs.bigmodel.cn/cn/coding-plan/overview.md",
      provider: "zhipuai"
    },
    {
      id: "zai-coding-models",
      url: "https://docs.z.ai/devpack/overview.md",
      provider: "zhipuai"
    }
  ]
};

// shared/coding-roster.ts
var CODING_ROSTER_REVISION = coding_tool_models_default.revision;
var CODING_MODEL_RECORDS = coding_tool_models_default.records;
var archiveDays = coding_tool_models_default.archiveDays;
var CODING_DOCUMENT_SOURCES = coding_tool_models_default.sources;

// shared/lineup.ts
var LINEUP_METHOD = "lineup-v1";
var LINEUP_TIE = 1;

// shared/client-digest.ts
var CLIENT_RAW_LIMIT = 15e4;
var text2 = z2.string().min(1);
var scalar = z2.number().finite();
var nullable = scalar.nullable();
var date = z2.string().refine((v) => Number.isFinite(Date.parse(v)));
var ids2 = z2.array(text2);
var tags = z2.array(
  z2.enum([
    "cheapest",
    "strongest",
    "best_value",
    "equivalent_costlier",
    "dominated"
  ])
);
var clientAliasRegistrySchema = z2.object({
  revision: text2,
  checkedAt: text2,
  records: z2.array(
    z2.object({
      modelId: text2,
      sourceModelId: text2,
      harnessIds: z2.object({ api: ids2, "claude-code": ids2, codex: ids2 }).strict(),
      sourceUrls: z2.array(z2.url()),
      qualification: text2,
      requiredEndpoints: z2.record(z2.string(), z2.url())
    }).strict()
  )
}).strict();
var REVIEWED_CLIENT_ALIASES = clientAliasRegistrySchema.parse(client_harness_aliases_default);
var member = z2.object({
  id: text2,
  ability: scalar.optional(),
  cost: scalar.positive().optional(),
  costRelative: scalar.positive().optional(),
  status: z2.literal("incomplete").optional(),
  tags,
  dominatedBy: z2.object({ id: text2, kind: z2.enum(["equivalent", "weaker"]) }).strict().nullable()
}).strict();
var clientDigestSchema = z2.object({
  projectionVersion: z2.literal("client-v1.1").optional(),
  multipliers: z2.array(clientMultiplierSchema).optional(),
  multiplierHorizon: z2.object({
    from: date,
    to: date,
    selection: z2.literal("highest-priority-no-stacking")
  }).strict().optional(),
  units: z2.object({
    ability: z2.literal("websiteAbility"),
    cost: z2.literal("usdPerReferenceTask"),
    time: z2.literal("taskTimeCrossModel")
  }).strict(),
  builtAt: date,
  aliasRevision: text2,
  developers: z2.array(
    z2.object({ id: text2, name: text2, color: text2, region: text2.nullable() }).strict()
  ),
  models: z2.array(
    z2.object({
      id: text2,
      name: text2,
      developerId: text2,
      current: z2.boolean(),
      recommended: text2.nullable(),
      harnessIds: z2.object({ api: ids2, "claude-code": ids2, codex: ids2 }).strict(),
      harnessEvidence: z2.object({
        checkedAt: text2,
        sourceUrls: z2.array(z2.url()),
        qualification: text2,
        requiredEndpoints: z2.record(z2.string(), z2.url())
      }).strict().nullable(),
      efforts: z2.array(
        z2.object({
          effort: text2,
          label: text2,
          available: z2.boolean(),
          ability: nullable,
          abilityBasis: z2.enum(["abilityWithinModel", "capability"]),
          cost: scalar.nonnegative().nullable(),
          costBasisId: text2.nullable(),
          time: scalar.nonnegative().nullable(),
          timeEstimated: z2.boolean(),
          timeBasis: z2.object({
            source: text2,
            cohort: text2,
            boundary: text2,
            referenceSeconds: scalar.positive()
          }).strict().nullable()
        }).strict()
      )
    }).strict()
  ),
  lineups: z2.array(
    z2.object({
      developerId: text2,
      costBasisId: text2,
      method: z2.literal(LINEUP_METHOD),
      tie: z2.literal(LINEUP_TIE),
      baseline: text2,
      frontier: ids2,
      steps: z2.array(
        z2.object({
          from: text2,
          to: text2,
          abilityDelta: scalar,
          costRatio: scalar.positive()
        }).strict()
      ),
      members: z2.array(member)
    }).strict()
  ),
  resets: z2.array(
    z2.object({
      id: text2,
      provider: text2,
      eventType: z2.enum([
        "reset_credit_issued",
        "direct_reset_announced",
        "direct_reset_reported_complete"
      ]).optional(),
      schedule: z2.object({
        precision: z2.enum(["window", "date", "approximate", "deadline"]),
        from: date,
        through: date,
        label: z2.string()
      }).strict().nullable().optional(),
      observationUrl: z2.url().optional(),
      scope: text2.nullable(),
      status: text2,
      at: date.nullable(),
      precision: text2,
      publishedAt: date,
      url: z2.url()
    }).strict()
  ),
  windows: z2.array(
    z2.object({
      id: text2,
      provider: text2,
      title: z2.object({ zh: text2, en: text2 }).strict(),
      startsAt: date,
      endsAt: date,
      status: text2,
      eligibility: text2,
      url: z2.url()
    }).strict()
  )
}).strict().superRefine((d, ctx) => {
  const fail = (message) => ctx.addIssue({ code: "custom", message });
  const unique = (items) => new Set(items).size === items.length;
  if (!unique(d.models.map((m) => m.id)) || !unique(d.developers.map((m) => m.id)) || !unique(d.lineups.map((l) => l.developerId)))
    fail("duplicate_client_identity");
  if (d.projectionVersion !== void 0 !== (d.multipliers !== void 0) || d.projectionVersion !== void 0 !== (d.multiplierHorizon !== void 0))
    fail("incomplete_multiplier_projection");
  const models = new Map(d.models.map((m) => [m.id, m]));
  for (const m of d.models) {
    if (!d.developers.some((v) => v.id === m.developerId) || !unique(m.efforts.map((e) => e.effort)) || m.recommended !== null && !m.efforts.some((e) => e.effort === m.recommended))
      fail("invalid_client_configuration");
    for (const e of m.efforts)
      if (e.time === null !== (e.timeBasis === null) || e.time === null && e.timeEstimated)
        fail("invalid_client_time");
  }
  for (const l of d.lineups) {
    const members = new Map(l.members.map((r) => [r.id, r]));
    if (!unique(l.members.map((r) => r.id)) || !unique(l.frontier) || !members.has(l.baseline) || l.frontier.some((id3) => !members.has(id3)))
      fail("invalid_client_lineup_reference");
    for (const r of l.members) {
      if (models.get(r.id)?.developerId !== l.developerId || r.dominatedBy && !members.has(r.dominatedBy.id))
        fail("invalid_client_lineup_model");
      if (r.status === "incomplete" ? r.tags.length > 0 || r.dominatedBy !== null || r.ability !== void 0 || r.cost !== void 0 || r.costRelative !== void 0 : r.ability === void 0 || r.cost === void 0 || r.costRelative === void 0)
        fail("invalid_client_lineup_status");
    }
  }
});

// shared/reference-expense-usd.ts
import { z as z3 } from "zod";

// data/reference-expense-usd.json
var reference_expense_usd_default = {
  id: "aa-agent-v1.5-api-reference-task-2026-09-30",
  sourceId: "aa-agent",
  sourceUrl: "https://artificialanalysis.ai/agents/coding-agents",
  protocolVersion: "1.5",
  currency: "USD",
  referenceCostUsd: 4.463527946409263,
  frozenAt: "2026-09-30T14:28:16.806908+00:00",
  statistic: "maker-family-version-balanced-geometric-mean-of-source-reported-mean-cost",
  referenceModels: 9,
  referenceMakers: 2,
  taskDefinition: "AA Coding Agent v1.5 reported mean pay-per-token API cost per task across its three benchmark datasets; not cost per successful task. Exact retained-attempt denominator is not published.",
  datasets: [
    "datacurve/deep-swe-1-1@1",
    "datasets/swe-atlas-qna",
    "terminal-bench/terminal-bench@sha256:39d9f44b40420cde8fdcc087579c0d72a7e14fa3656d603c3f0d22fb35e27732"
  ],
  limitation: "Rebasing the multisource expense index is not a validated forecast of actual cost on this workload or a real development bill.",
  pricingDefinition: "Published per-token API tariffs, including cache read/write categories where accounted for by the source; frozen source snapshot, not current subscription pricing."
};

// shared/reference-expense-usd.ts
var positive = z3.number().finite().positive();
var date2 = z3.iso.datetime({ offset: true });
var referenceExpenseWorkloadSchema = z3.object({
  id: z3.literal(reference_expense_usd_default.id),
  sourceId: z3.literal("aa-agent"),
  sourceUrl: z3.url(),
  protocolVersion: z3.literal("1.5"),
  currency: z3.literal("USD"),
  referenceCostUsd: z3.literal(reference_expense_usd_default.referenceCostUsd),
  frozenAt: z3.literal(reference_expense_usd_default.frozenAt),
  statistic: z3.string().min(1),
  referenceModels: positive.int(),
  referenceMakers: positive.int(),
  taskDefinition: z3.string().min(1),
  datasets: z3.array(z3.string().min(1)).length(3),
  pricingDefinition: z3.string().min(1),
  limitation: z3.string().min(1)
}).strict();
var parsedReference = referenceExpenseWorkloadSchema.parse(reference_expense_usd_default);
Object.freeze(parsedReference.datasets);
var REFERENCE_EXPENSE_WORKLOAD = Object.freeze(parsedReference);
var expenseUsdEvidenceSchema = z3.object({
  policyId: z3.literal("reference-task-usd-v1"),
  basis: z3.literal("api-list-price"),
  priceBasisScope: z3.literal("reference-anchor"),
  status: z3.enum(["converted", "estimated", "unavailable"]),
  conversion: z3.enum(["same-source-denormalization", "index-reference-rebase"]).nullable(),
  reason: z3.string().min(1).nullable(),
  referenceWorkload: referenceExpenseWorkloadSchema,
  observedAt: date2.nullable(),
  observedAtMeaning: z3.literal("oldest-contributing-cost-evidence-window"),
  sources: z3.array(
    z3.object({
      id: z3.string().min(1),
      url: z3.url(),
      cohort: z3.string().min(1),
      observedAt: date2,
      windowBasis: z3.enum(["source-evidence-window", "input-capture"])
    }).strict()
  ),
  measured: z3.literal(false),
  empiricalWorkloadCalibration: z3.literal(false),
  isSubscriptionConsumption: z3.literal(false),
  isRealBill: z3.literal(false)
}).strict().superRefine((v, ctx) => {
  if (v.status === "unavailable" !== (v.reason !== null) || v.status === "unavailable" && v.conversion !== null || v.status !== "unavailable" && (!v.observedAt || !v.conversion || !v.sources.length))
    ctx.addIssue({
      code: "custom",
      message: "inconsistent_expense_usd_evidence"
    });
});

// shared/plan-value-contract.ts
import { z as z4 } from "zod";
var PLAN_VALUE_VERSION = "plan-value-v0.2";
var planValuePublicationSchema = z4.object({
  formulaVersion: z4.enum(["plan-value-v0.1", PLAN_VALUE_VERSION]),
  inputHash: z4.string(),
  computedAt: z4.string(),
  calibration: z4.object({
    status: z4.literal("scenario-not-calibrated"),
    fitError: z4.null(),
    reason: z4.string()
  }),
  policy: z4.record(z4.string(), z4.unknown()),
  history: z4.record(z4.string(), z4.unknown()).optional(),
  rows: z4.array(z4.record(z4.string(), z4.unknown())).max(5e3)
}).strict();

// shared/plan-metering.ts
import { z as z5 } from "zod";
var number = z5.number().finite().nonnegative();
var meteringEvidenceSchema = z5.object({
  sourceId: z5.string(),
  sourceUrl: z5.url(),
  sourceHash: z5.string(),
  verifiedAt: z5.iso.datetime({ offset: true }),
  note: z5.string()
}).strict();
var planMeteringSchema = z5.object({
  schemaVersion: z5.literal(1),
  revision: z5.string(),
  priceBasis: z5.object({
    kind: z5.enum([
      "monthly-list",
      "annual",
      "promotion",
      "usage",
      "unknown"
    ]),
    tax: z5.enum(["excluded", "included", "unknown"]),
    currency: z5.string(),
    evidence: meteringEvidenceSchema.nullable()
  }).strict(),
  gates: z5.array(
    z5.object({
      id: z5.string(),
      poolId: z5.string(),
      modelAliases: z5.array(z5.string()).nullable(),
      unit: z5.enum(["USD", "credits", "requests", "tokens", "unknown"]),
      amount: number.nullable(),
      window: z5.enum(["rolling", "fixed", "unknown"]),
      hours: z5.number().positive().nullable(),
      anchor: z5.iso.datetime({ offset: true }).nullable(),
      timezone: z5.string().nullable(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(500),
  rates: z5.array(
    z5.object({
      modelAlias: z5.string(),
      poolId: z5.string(),
      unit: z5.enum(["USD", "credits", "requests", "tokens"]),
      perTokens: z5.number().positive(),
      input: number,
      output: number,
      cacheRead: number.nullable(),
      cacheWrite: number.nullable(),
      minContextTokens: number.nullable(),
      maxContextTokens: number.nullable(),
      condition: z5.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(500),
  timeBands: z5.array(
    z5.object({
      weekdays: z5.array(z5.number().int().min(1).max(7)),
      startHour: z5.number().min(0).max(23),
      endHour: z5.number().min(1).max(24),
      outsideMultiplier: z5.number().positive(),
      timezone: z5.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(4).optional(),
  relativeAllowances: z5.array(
    z5.object({
      basePlanId: z5.string(),
      factor: z5.number().positive(),
      window: z5.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(20),
  overflow: z5.object({
    policy: z5.enum(["wait", "optional-paid", "unknown"]),
    automatic: z5.boolean().nullable(),
    priceKnown: z5.boolean(),
    evidence: meteringEvidenceSchema.nullable()
  }).strict(),
  limitations: z5.array(z5.string()).max(30)
}).strict();

// shared/public-publication.ts
import { z as z9 } from "zod";

// shared/speed-evidence.ts
import { z as z6 } from "zod";
var SPEED_CHANNELS = [
  "api",
  "subscription-default",
  "fast-mode",
  "ultrafast",
  "unknown"
];
var speedChannelSchema = z6.enum(SPEED_CHANNELS);
var speedDateSchema = z6.string().refine((v) => v === "unknown" || Number.isFinite(Date.parse(v)));
var date3 = z6.string().refine((v) => Number.isFinite(Date.parse(v)));
var id = z6.string().min(1).max(200);
var text3 = z6.string().min(1).max(4e3);
var number2 = z6.number().finite().nonnegative();
var url = z6.string().url().refine((v) => v.startsWith("https://"));
var SPEED_POLICY = {
  version: "channel-speed-evidence-v1",
  maximumChangesPerConfiguration: 32,
  measurementField: "median_output_tokens_per_second",
  diagnosticChannel: "api",
  quantile: "empirical midrank: (count strictly below + 0.5 * count equal) / population size",
  population: "native recommended configurations with both observed cross-model task coordinates and measured API throughput; before request filters",
  clientRule: "taskTimeQuantile <= 0.25 and throughputQuantile >= 2/3; clients decide eligibility using provenance and uncertainty flags"
};
var aaThroughputRecordSchema = z6.object({
  channel: z6.literal("api"),
  source: z6.literal("artificial-analysis"),
  unit: z6.literal("output_tokens_per_second"),
  claim: z6.literal(false),
  configurationId: id,
  value: number2.nullable(),
  status: z6.enum(["available", "missing", "invalid"]),
  field: z6.literal("median_output_tokens_per_second"),
  observedAt: date3,
  firstObservedAt: date3,
  sourceSnapshotHash: z6.string().regex(/^[a-f0-9]{64}$/)
}).strict().refine(
  (r) => r.status === "available" === (r.value !== null) && Date.parse(r.firstObservedAt) <= Date.parse(r.observedAt)
);
var aaThroughputHistorySchema = z6.record(
  id,
  z6.array(aaThroughputRecordSchema).min(1).max(SPEED_POLICY.maximumChangesPerConfiguration)
).refine(
  (v) => Object.keys(v).length <= 1e4 && Object.entries(v).every(
    ([key, rows]) => rows.every((r) => r.configurationId === key)
  )
);
var outputThroughputSchema = z6.object({
  value: number2.nullable(),
  unit: z6.literal("output_tokens_per_second"),
  channel: speedChannelSchema,
  observedAt: speedDateSchema,
  firstObservedAt: speedDateSchema,
  source: text3.nullable(),
  sourceUrl: url.nullable(),
  sourceSnapshotId: id.nullable(),
  configurationId: id.nullable(),
  claim: z6.literal(false),
  statistic: z6.literal("source-reported-median"),
  tokenBasis: z6.literal("source-defined-output"),
  sourceField: z6.literal("median_output_tokens_per_second"),
  status: z6.enum(["available", "missing", "invalid"]),
  reason: text3.nullable(),
  stale: z6.boolean(),
  history: z6.array(aaThroughputRecordSchema)
}).strict().refine(
  (r) => r.status === "available" === (r.value !== null) && r.history.every((h) => h.configurationId === r.configurationId)
);
var speedClaimSchema = z6.object({
  id,
  modelIds: z6.array(id).min(1).max(30),
  effortScope: z6.enum(["explicit", "unknown", "all-declared"]),
  efforts: z6.array(id).max(10),
  channel: speedChannelSchema,
  claim: z6.literal(true),
  sourceKind: z6.enum(["vendor-announcement", "public-report"]),
  metric: z6.enum(["output-throughput", "output-throughput-ratio"]),
  value: number2.nullable(),
  ratio: z6.number().finite().positive().nullable(),
  qualifier: z6.enum(["approximate", "upper-bound", "reported"]),
  boundary: text3,
  tokenBasis: text3,
  publishedAt: speedDateSchema,
  effectiveAt: date3.nullable(),
  effectiveTiming: text3,
  observedAt: date3,
  source: text3,
  sourceUrl: url,
  evidenceUrls: z6.array(url).min(1).max(8),
  evidenceHash: z6.string().regex(/^[a-f0-9]{64}$/).nullable(),
  qualification: text3
}).strict().refine(
  (c) => (c.effortScope === "explicit" ? c.efforts.length > 0 : c.efforts.length === 0) && (c.metric === "output-throughput" ? c.value !== null && c.ratio === null : c.value === null && c.ratio !== null)
);
var reviewedSpeedClaimSchema = speedClaimSchema.safeExtend({
  review: z6.object({
    status: z6.literal("approved"),
    reviewedAt: date3,
    contentHash: z6.string().regex(/^[a-f0-9]{64}$/)
  }).strict(),
  current: z6.boolean()
});
var speedReviewSchema = z6.object({
  claim: speedClaimSchema,
  contentHash: z6.string().regex(/^[a-f0-9]{64}$/),
  status: z6.enum(["pending", "approved", "rejected"]),
  createdAt: date3,
  reviewedAt: date3.nullable(),
  reviewNote: z6.string().max(4e3).nullable()
}).strict().refine(
  (r) => r.status === "pending" || !!r.reviewedAt && !!r.reviewNote?.trim()
);
var speedClaimJournalSchema = z6.object({
  schemaVersion: z6.literal(1),
  entries: z6.array(speedReviewSchema).max(2e4)
}).strict();

// shared/plan-knowledge.ts
import { z as z7 } from "zod";
var text4 = z7.string().min(1).max(4e3);
var id2 = z7.string().regex(/^[\w:.-]{1,160}$/);
var number3 = z7.number().finite().nonnegative();
var hash = z7.string().regex(/^[a-f0-9]{64}$/);
var date4 = text4.refine((value) => Number.isFinite(Date.parse(value)));
var url2 = z7.string().url().refine((value) => value.startsWith("https://"));
var knowledgeProductSchema = z7.object({
  id: id2,
  name: text4,
  vendor: text4,
  category: z7.enum(["direct", "tool", "aggregator", "api", "unknown"])
}).strict();
var knowledgeEntrySchema = z7.object({
  id: id2,
  upstreamPlanId: id2,
  productId: id2,
  tierGroupId: id2,
  name: text4,
  nameEn: z7.string().max(4e3),
  upstreamNames: z7.array(text4),
  billing: z7.enum(["subscription", "metered"]),
  scenario: z7.string().max(4e3),
  region: z7.enum(["cn", "international", "us", "unknown"]),
  generation: z7.string().max(100),
  formalPlanId: id2.nullable(),
  mappingStatus: z7.enum(["unmapped", "linked"])
}).strict();
var knowledgeObservationSchema = z7.object({
  id: id2,
  entryId: id2,
  upstreamModel: text4,
  formalModelId: id2.nullable(),
  upstreamGeneration: z7.string().max(100),
  price: z7.object({
    amount: number3.nullable(),
    currency: z7.string().max(10),
    period: z7.enum(["month", "year", "usage", "unknown"]),
    upstreamAmount: number3.nullable(),
    monthlyEquivalent: number3.nullable(),
    comparisonMonthlyUsd: number3.nullable(),
    status: z7.literal("upstream-observation")
  }).strict(),
  economics: z7.object({
    monthlyTokens: number3.nullable(),
    effectiveUsdPerMillionTokens: number3.nullable(),
    upstreamEffectiveUsdPerMillionTokens: number3.nullable(),
    unmeteredPromotion: z7.boolean(),
    promotionUntil: z7.string().nullable(),
    sharedPool: z7.enum(["shared", "unknown", "not-applicable"]),
    additiveCapacity: z7.literal(false),
    comparisonEligible: z7.boolean(),
    diagnostics: z7.array(text4)
  }).strict(),
  workload: z7.object({
    kind: z7.enum([
      "standard",
      "lowCache",
      "anthropic",
      "measured",
      "unknown"
    ]),
    cache: number3.max(1).nullable(),
    input: number3.max(1).nullable(),
    output: number3.max(1).nullable(),
    cacheWrite: number3.max(1).nullable(),
    monthWeeks: number3.nullable(),
    saturatedUsage: z7.literal(true),
    contextAndEffort: z7.literal("source-specific-or-unknown")
  }).strict(),
  sample: z7.object({
    label: z7.string().max(4e3),
    kind: z7.string().max(100),
    precision: z7.enum(["day", "month", "range", "unknown"]),
    derivedFrom: z7.string().max(4e3)
  }).strict(),
  confidence: z7.enum(["high", "medium", "low", "unknown"]),
  evidence: z7.object({
    sourceLabel: z7.string().max(4e3),
    sourceUrl: url2,
    links: z7.array(url2),
    note: z7.string().max(4e3),
    observedAt: date4,
    recordHash: hash
  }).strict()
}).strict();
var knowledgeChangeSchema = z7.object({
  id: id2,
  kind: z7.enum(["added", "updated", "withdrawn", "assumptions-review"]),
  observationId: id2.nullable(),
  beforeHash: hash.nullable(),
  afterHash: hash.nullable(),
  sourceCommit: z7.string().regex(/^[a-f0-9]{40}$/),
  observedAt: date4,
  status: z7.enum(["published-observation", "review-required"])
}).strict();
var clock = z7.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/);
var knowledgeCalendarLeadSchema = z7.object({
  id: id2,
  entryId: id2,
  status: z7.literal("UNVERIFIED"),
  formalPlanId: z7.null(),
  formalModelId: z7.null(),
  personalQualification: z7.literal("unknown"),
  requiresOfficialReview: z7.literal(true),
  observationIds: z7.array(id2).min(1),
  sourceCommit: z7.string().regex(/^[a-f0-9]{40}$/),
  sourceHash: hash,
  evidence: z7.array(
    z7.object({
      observationId: id2,
      recordHash: hash,
      sourceUrl: url2,
      originalText: text4,
      observedAt: date4
    }).strict()
  ).min(1),
  proposed: z7.object({
    kind: z7.enum([
      "recurring-window",
      "time-dependent-pricing",
      "limited-promotion"
    ]),
    timezone: z7.string().max(100).refine((value) => {
      try {
        new Intl.DateTimeFormat("en", { timeZone: value });
        return true;
      } catch {
        return false;
      }
    }).nullable(),
    windows: z7.array(
      z7.object({
        start: clock,
        end: clock,
        weekdays: z7.array(z7.number().int().min(1).max(7)).max(7)
      }).strict().refine(
        (window) => window.start !== window.end && new Set(window.weekdays).size === window.weekdays.length
      )
    ),
    coefficient: z7.object({
      value: z7.number().finite().positive(),
      meaning: z7.enum([
        "deduction-multiplier",
        "price-multiplier",
        "capacity-multiplier"
      ])
    }).strict().nullable(),
    validUntil: date4.nullable(),
    conditions: z7.array(text4)
  }).strict()
}).strict();
var planKnowledgeSchema = z7.object({
  schemaVersion: z7.literal(1),
  revision: text4,
  source: z7.object({
    id: z7.literal("real-api-pricing"),
    name: z7.literal("Real API Pricing"),
    url: url2,
    commit: z7.string().regex(/^[a-f0-9]{40}$/),
    adoptedHash: hash,
    conventionsHash: hash,
    capturedAt: date4,
    mappingRevision: text4,
    parserVersion: z7.literal(1),
    attribution: text4
  }).strict(),
  assumptions: z7.object({
    formula: text4,
    tokenPolicy: text4,
    unmeteredPolicy: text4,
    calculationVersion: text4,
    monthWeeks: number3,
    exchangeRate: z7.object({
      value: number3,
      units: z7.literal("CNY per USD"),
      date: text4,
      sourceUrl: url2
    }).strict(),
    capacityMeaning: z7.literal("scenario-estimate-at-saturated-usage"),
    confidenceMeaning: z7.literal("upstream-evidence-grade-not-probability")
  }).strict(),
  products: z7.array(knowledgeProductSchema),
  entries: z7.array(knowledgeEntrySchema),
  observations: z7.array(knowledgeObservationSchema),
  changes: z7.array(knowledgeChangeSchema),
  calendarLeads: z7.array(knowledgeCalendarLeadSchema).optional(),
  reconciliation: z7.object({
    sourceRows: z7.number().int().nonnegative(),
    subscriptionRows: z7.number().int().nonnegative(),
    apiRows: z7.number().int().nonnegative(),
    subscriptionKeys: z7.number().int().nonnegative(),
    apiKeys: z7.number().int().nonnegative(),
    unmappedEntries: z7.number().int().nonnegative()
  }).strict()
}).strict().superRefine((knowledge, ctx) => {
  const products = new Set(knowledge.products.map((row) => row.id));
  const entries = new Map(knowledge.entries.map((row) => [row.id, row]));
  const observations = new Set(knowledge.observations.map((row) => row.id));
  const leads = knowledge.calendarLeads ?? [];
  const byObservation = new Map(
    knowledge.observations.map((row) => [row.id, row])
  );
  if (new Set(leads.map((row) => row.id)).size !== leads.length || leads.some(
    (lead) => !entries.has(lead.entryId) || lead.sourceCommit !== knowledge.source.commit || lead.sourceHash !== knowledge.source.adoptedHash || new Set(lead.observationIds).size !== lead.observationIds.length || lead.evidence.length !== lead.observationIds.length || new Set(lead.evidence.map((row) => row.observationId)).size !== lead.evidence.length || lead.evidence.some((evidence) => {
      const observation = byObservation.get(evidence.observationId);
      return !lead.observationIds.includes(evidence.observationId) || observation?.entryId !== lead.entryId || observation.evidence.recordHash !== evidence.recordHash || observation.evidence.sourceUrl !== evidence.sourceUrl || observation.evidence.observedAt !== evidence.observedAt;
    })
  ))
    ctx.addIssue({
      code: "custom",
      message: "knowledge_calendar_lead_reference_mismatch"
    });
  const usedEntries = new Set(
    knowledge.observations.map((row) => row.entryId)
  );
  const subscriptions = knowledge.observations.filter(
    (row) => entries.get(row.entryId)?.billing === "subscription"
  );
  const summary = knowledge.reconciliation;
  if (products.size !== knowledge.products.length || entries.size !== knowledge.entries.length || observations.size !== knowledge.observations.length || usedEntries.size !== entries.size || knowledge.entries.some(
    (row) => !products.has(row.productId) || row.mappingStatus === "linked" !== (row.formalPlanId !== null)
  ) || knowledge.observations.some((row) => !entries.has(row.entryId)) || summary.sourceRows !== knowledge.observations.length || summary.subscriptionRows !== subscriptions.length || summary.apiRows !== knowledge.observations.length - subscriptions.length || summary.subscriptionKeys !== knowledge.entries.filter((row) => row.billing === "subscription").length || summary.apiKeys !== knowledge.entries.filter((row) => row.billing === "metered").length || summary.unmappedEntries !== knowledge.entries.filter((row) => row.mappingStatus === "unmapped").length)
    ctx.addIssue({
      code: "custom",
      message: "knowledge_reconciliation_or_reference_mismatch"
    });
});

// shared/portfolio-contract.ts
import { z as z8 } from "zod";
var publicPortfolioSchema = z8.object({
  policyVersion: z8.string().min(1),
  revision: z8.string().regex(/^[a-f0-9]{64}$/),
  activeIds: z8.array(z8.string().min(1)).max(32),
  counts: z8.object({
    candidates: z8.number().int().min(0).max(200),
    active: z8.number().int().min(0).max(32),
    observing: z8.number().int().min(0).max(32),
    configurations: z8.number().int().min(0).max(256),
    frozen: z8.number().int().min(0).max(100)
  }),
  vendors: z8.array(
    z8.object({
      developerId: z8.string().min(1),
      name: z8.string().min(1),
      metric: z8.enum(["aa-coding", "aa-intelligence"]),
      score: z8.number().finite(),
      modelId: z8.string().min(1),
      modelName: z8.string().min(1),
      effort: z8.string().min(1),
      sourceUrl: z8.url(),
      observedAt: z8.iso.datetime({ offset: true }),
      provisional: z8.boolean()
    })
  ).max(32),
  mainstays: z8.record(z8.string(), z8.array(z8.string().min(1)).max(4)),
  states: z8.array(
    z8.object({
      id: z8.string().min(1),
      status: z8.enum(["candidate", "observing", "tracked", "frozen"]),
      basis: z8.enum(["benchmark", "paid-popularity", "official-product"]).nullable(),
      reason: z8.string().min(1),
      nextDecisionAt: z8.iso.datetime({ offset: true }).optional(),
      comparisonUntil: z8.iso.datetime({ offset: true }).optional(),
      replacementId: z8.string().min(1).optional(),
      admission: z8.object({
        weeklyRank: z8.number().int().positive().nullable(),
        daily: z8.object({
          date: z8.string().nullable(),
          rank: z8.number().int().positive().nullable(),
          known: z8.boolean(),
          fresh: z8.boolean(),
          previousDate: z8.string().nullable(),
          previousRank: z8.number().int().positive().nullable(),
          confirmed: z8.boolean()
        }).optional(),
        codingEvidenceSources: z8.array(z8.string()).max(10),
        efficientProduct: z8.boolean(),
        diagnostics: z8.array(z8.string()).max(20)
      }).optional()
    })
  ).max(300),
  nextCheckAt: z8.iso.datetime({ offset: true })
}).strict().superRefine((p, ctx) => {
  const active = new Set(p.activeIds), ids3 = new Set(p.states.map((s) => s.id));
  if (active.size !== p.activeIds.length || ids3.size !== p.states.length || p.counts.active !== active.size || p.states.filter((s) => s.status === "tracked").length > 28 || p.states.filter((s) => s.status === "observing").length !== p.counts.observing || p.states.filter((s) => s.status === "frozen").length !== p.counts.frozen || p.states.some(
    (s) => (s.status === "tracked" || s.status === "observing") && !active.has(s.id)
  ) || p.activeIds.some(
    (id3) => !p.states.some(
      (s) => s.id === id3 && (s.status === "tracked" || s.status === "observing")
    )
  ) || Object.values(p.mainstays).some(
    (list) => new Set(list).size !== list.length || list.some((id3) => !active.has(id3))
  ) || p.vendors.some((v) => !active.has(v.modelId)))
    ctx.addIssue({ code: "custom", message: "invalid_portfolio_references" });
});

// shared/public-publication.ts
var PUBLIC_COMPONENTS = [
  "methods",
  "registry",
  "models",
  "plans",
  "rules",
  "news",
  "calendar"
];
var ALL_PUBLIC_COMPONENTS = [...PUBLIC_COMPONENTS, "client"];
var COMPONENT_DEPENDENCIES = {
  methods: [],
  registry: [],
  models: ["registry", "methods"],
  plans: ["registry"],
  rules: ["plans"],
  news: ["plans"],
  calendar: ["plans", "rules"],
  client: ["models", "registry", "rules", "calendar"]
};
var PUBLIC_HASH = /^[a-f0-9]{64}$/;
var PUBLIC_ID = /^[a-f0-9]{24}$/;
var isRecord = (value) => !!value && typeof value === "object" && !Array.isArray(value);
var text5 = z9.string().min(1);
var date5 = text5.refine((value) => Number.isFinite(Date.parse(value)));
var finite = z9.number().finite();
var record = z9.record(z9.string(), z9.unknown());
var indexMetric = z9.object({
  methodId: z9.literal("unified-v03-estimator-0.1.0-internal"),
  outputThroughput: outputThroughputSchema.optional(),
  speedDiagnostics: z9.object({
    taskTimeQuantile: finite.min(0).max(1).nullable(),
    throughputQuantile: finite.min(0).max(1).nullable(),
    throughputVsMedian: finite.nonnegative().nullable(),
    populationId: text5,
    reason: text5.nullable()
  }).optional(),
  taskChannel: speedChannelSchema.optional(),
  taskObservedAt: speedDateSchema.optional(),
  abilityIndex: finite.nullable(),
  abilityWithinModel: finite.nullable().optional(),
  abilityWithinModelBasis: z9.enum(["anchor", "same-source-chain", "offset-calibrated"]).nullable().optional(),
  abilityComparability: z9.object({
    version: text5,
    anchorEffort: text5.nullable(),
    path: z9.array(text5),
    sources: z9.array(text5),
    adjacent: z9.array(
      z9.object({
        effort: text5,
        status: z9.enum(["same-source", "unavailable"]),
        points: finite.nullable(),
        sources: z9.array(text5)
      })
    ),
    reason: z9.enum([
      "anchor",
      "same-source-chain",
      "disconnected-evidence"
    ])
  }).optional(),
  taskTimeWithinModel: finite.positive().nullable().optional(),
  taskTimeCrossModel: z9.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    version: text5,
    value: finite.positive().nullable(),
    estimateValue: finite.positive().nullable(),
    sourceMultiplier: finite.positive().nullable(),
    scaleFactor: finite.positive().nullable(),
    source: text5.nullable(),
    sourceSeconds: finite.positive().nullable(),
    referenceSeconds: finite.positive().nullable(),
    cohort: text5.nullable(),
    boundary: text5.nullable(),
    sourceUrl: z9.string().nullable(),
    protocolId: text5.nullable(),
    selectedProtocolId: text5.nullable(),
    anchorEffort: text5.nullable(),
    anchorLevel: finite.positive().nullable(),
    withinModelRatio: finite.positive().nullable(),
    calibrationId: text5,
    calibrationPath: z9.array(text5),
    status: z9.enum([
      "baseline",
      "calibrated",
      "uncalibrated",
      "unavailable"
    ]),
    protocolFallback: z9.boolean(),
    flags: z9.array(text5)
  }).optional(),
  taskTimeWithinModelBasis: z9.enum(["anchor", "same-protocol-chain"]).nullable().optional(),
  taskTimeComparability: z9.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    version: text5,
    protocolId: text5.nullable(),
    source: text5.nullable(),
    cohort: text5.nullable(),
    boundary: text5.nullable(),
    referenceSeconds: finite.positive().nullable(),
    coveredEfforts: z9.array(text5),
    anchorEffort: text5.nullable(),
    componentId: text5.nullable(),
    path: z9.array(text5),
    adjacent: z9.array(
      z9.object({
        effort: text5,
        ratio: finite.positive().nullable(),
        status: z9.enum(["same-protocol", "disconnected"])
      })
    ),
    reason: z9.enum([
      "measured",
      "missing-in-selected-protocol",
      "no-measured-protocol"
    ])
  }).optional(),
  taskTimeEstimate: z9.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    value: finite.positive(),
    seconds: finite.positive(),
    method: z9.enum([
      "interpolated",
      "extrapolated",
      "proxy-aa-generation",
      "anchored-combined",
      "anchored-generation",
      "anchored-generation-ratio"
    ]),
    steps: finite.int().nonnegative().nullable().optional(),
    generationBeta: finite.nullable().optional(),
    interval: z9.object({ low: finite.positive(), high: finite.positive() }).refine((i) => i.low <= i.high).optional(),
    intervalBasis: z9.literal("held-out-residual-p10-p90").optional(),
    anchors: z9.array(text5),
    beta: finite,
    betaVersion: text5,
    expectedError: z9.object({
      median: finite.min(1),
      p90: finite.min(1),
      unit: z9.literal("multiplicative-factor"),
      tests: finite.positive(),
      validation: z9.enum([
        "leave-one-model-out",
        "leave-one-effort-out",
        "conditional-model-holdout"
      ])
    }).nullable(),
    protocolId: text5.optional(),
    source: text5,
    cohort: text5,
    boundary: text5.nullable(),
    referenceSeconds: finite.positive(),
    costSource: text5.nullable(),
    fitId: text5,
    evidenceIds: z9.array(text5),
    exclusions: z9.array(text5).optional(),
    rankingEligible: z9.literal(false)
  }).nullable().optional(),
  taskTimeEstimateReason: text5.optional(),
  expenseMultiplier: finite.nonnegative().nullable(),
  expenseUsdPerTask: finite.nonnegative().nullable().optional(),
  expenseUsdEvidence: expenseUsdEvidenceSchema.optional(),
  taskTimeMultiplier: finite.nonnegative().nullable(),
  taskSeconds: finite.nonnegative().nullable(),
  taskSource: text5.nullable(),
  taskBoundary: text5.nullable(),
  taskCohort: text5.nullable(),
  taskReferenceSeconds: finite.nonnegative().nullable(),
  taskSourceUrl: text5.nullable(),
  basis: text5,
  completeness: z9.object({
    ability: finite,
    expense: finite,
    taskTime: finite
  }),
  sources: z9.array(
    z9.object({
      id: text5,
      label: text5,
      cohort: text5,
      url: text5,
      evidenceWindow: text5
    }).passthrough()
  ),
  effortGains: z9.record(
    z9.string(),
    z9.object({
      points: finite.nullable(),
      sources: z9.array(text5),
      completeness: finite
    })
  ),
  expenseRatios: z9.record(
    z9.string(),
    z9.object({
      ratio: finite.nonnegative().nullable(),
      sources: z9.array(text5)
    })
  )
}).passthrough().superRefine((v, ctx) => {
  if (v.expenseUsdPerTask === void 0 && v.expenseUsdEvidence === void 0)
    return;
  const usd = v.expenseUsdPerTask, ev = v.expenseUsdEvidence;
  if (usd === void 0 || !ev || ev.status === "unavailable" !== (usd === null) || usd !== null && (v.expenseMultiplier === null || Math.abs(
    usd - v.expenseMultiplier * ev.referenceWorkload.referenceCostUsd
  ) > Math.max(1e-10, Math.abs(usd) * 1e-10)))
    ctx.addIssue({
      code: "custom",
      message: "inconsistent_expense_usd_projection"
    });
});
var publicModelSchema = z9.object({
  throughputClaims: z9.array(reviewedSpeedClaimSchema).optional(),
  id: text5,
  family: z9.enum(["gpt6", "claude", "zhipu", "other"]),
  name: text5,
  subtitle: z9.string(),
  color: text5,
  recommended: text5.nullable(),
  developerId: text5.optional(),
  efforts: z9.array(
    z9.object({
      effort: text5,
      label: text5,
      capability: finite.nullable(),
      cost: finite.nullable(),
      time: finite.nullable(),
      available: z9.boolean(),
      indexMetrics: indexMetric.optional(),
      expenseUsdPerTask: finite.nonnegative().nullable().optional(),
      expenseUsdEvidence: expenseUsdEvidenceSchema.optional()
    }).passthrough().superRefine((e, ctx) => {
      if (e.expenseUsdPerTask === void 0 && e.expenseUsdEvidence === void 0)
        return;
      if (e.expenseUsdPerTask === void 0 || !e.expenseUsdEvidence || e.expenseUsdEvidence.status === "unavailable" !== (e.expenseUsdPerTask === null) || e.indexMetrics?.expenseUsdPerTask !== void 0 && e.indexMetrics.expenseUsdPerTask !== e.expenseUsdPerTask)
        ctx.addIssue({
          code: "custom",
          message: "inconsistent_visualization_expense_usd"
        });
    })
  ).min(1)
}).passthrough();
var dataset = z9.object({
  releaseVersion: z9.string().regex(/^\d+\.\d+\.\d+$/).optional(),
  models: z9.array(publicModelSchema),
  mode: z9.enum(["index", "aa", "demo", "live"]),
  timeMetric: z9.enum(["task_duration", "agent_wall_time"]),
  statistic: z9.enum(["mean", "source_reported"]),
  updatedAt: date5
}).passthrough();
var coverageStatus = z9.enum([
  "available",
  "conditional",
  "unavailable",
  "unknown"
]);
var coverage = z9.object({
  matchBasis: z9.enum(["reviewed", "advertised", "conditional"]).optional(),
  advertisedAliases: z9.array(text5).optional(),
  aliasRevision: text5.optional(),
  planId: text5,
  modelId: text5,
  modelVersion: text5,
  modelStatus: coverageStatus,
  effortStatus: coverageStatus,
  supportedEfforts: z9.array(text5).nullable(),
  region: text5,
  channel: text5,
  qualification: z9.string().nullable(),
  qualificationSummary: z9.string().max(40).nullable().optional(),
  qualificationSummaryZh: z9.string().max(24).nullable().optional(),
  effectiveFrom: date5.nullable(),
  effectiveUntil: date5.nullable(),
  sourceId: text5.nullable(),
  sourceUrl: z9.string().nullable(),
  verifiedAt: date5.nullable()
}).passthrough();
var plan = z9.object({
  id: text5,
  provider: text5,
  name: text5,
  region: text5,
  generation: text5,
  price: z9.object({
    amount: finite.nonnegative().nullable(),
    currency: z9.string(),
    period: z9.enum(["month", "quarter", "year", "usage", "unknown"]),
    qualifier: z9.string()
  }).passthrough(),
  models: z9.array(text5),
  clients: z9.array(text5),
  quota: z9.string(),
  sourceId: text5.nullable(),
  sourceUrl: text5,
  reviewedAt: date5,
  notes: z9.array(z9.string()),
  coverage: z9.array(coverage).optional(),
  catalogueEvidence: z9.object({
    status: z9.enum(["confirmed", "catalogue-unpublished", "unknown"]),
    sourceUrl: text5,
    verifiedAt: date5,
    note: z9.string()
  }).strict().optional(),
  modelCatalog: z9.object({
    status: z9.enum(["listed", "unpublished", "unknown"]),
    reason: text5,
    sourceUrl: text5,
    verifiedAt: date5,
    note: z9.string(),
    entries: z9.array(
      z9.object({
        name: text5,
        aliases: z9.array(text5),
        status: z9.enum(["indexed", "listed-only", "not-in-index"]),
        reason: text5,
        developerId: text5.nullable(),
        sourceModelId: text5.nullable(),
        modelId: text5.nullable(),
        modelVersion: text5.nullable(),
        kind: z9.enum(["text", "embedding", "unknown"]),
        availability: z9.enum(["listed", "sunsetting", "unknown"]),
        ability: z9.object({
          value: finite,
          kind: z9.enum(["index", "single-source-reference"]),
          methodId: text5,
          configuration: text5.nullable(),
          sourceUrl: text5,
          observedAt: date5,
          sourceStale: z9.boolean(),
          comparableWithIndex: z9.boolean()
        }).strict().nullable(),
        recommendedEffort: text5.nullable(),
        sourceUrl: text5,
        verifiedAt: date5,
        qualification: z9.string()
      }).strict().superRefine((entry, ctx) => {
        const indexed = entry.status === "indexed";
        if (indexed && !entry.modelId || !indexed && (entry.modelId !== null || entry.recommendedEffort !== null))
          ctx.addIssue({
            code: "custom",
            message: "invalid_catalog_index_identity"
          });
        if (entry.ability && (indexed ? entry.ability.kind !== "index" || !entry.ability.comparableWithIndex : entry.ability.kind !== "single-source-reference" || entry.ability.comparableWithIndex))
          ctx.addIssue({
            code: "custom",
            message: "invalid_catalog_metric_kind"
          });
      })
    )
  }).strict().optional(),
  quotaEstimates: z9.array(
    z9.object({
      amount: finite.nonnegative(),
      unit: z9.literal("requests"),
      window: z9.enum(["5h", "week", "month"]),
      windowHours: finite.nonnegative().nullable(),
      modelAlias: text5,
      client: text5,
      agentTeam: z9.boolean(),
      perSeat: z9.boolean(),
      qualification: z9.string(),
      evidenceIds: z9.array(text5)
    }).strict()
  ).optional(),
  modelListingStatus: z9.enum(["listed", "unknown"]).optional(),
  modelListings: z9.array(
    z9.object({
      alias: text5,
      aliases: z9.array(text5),
      advertisedVersion: text5,
      channel: text5,
      channelModelId: text5.nullable(),
      modelId: text5.nullable(),
      modelVersion: text5.nullable(),
      targetModelId: text5.nullable(),
      status: z9.enum(["matched", "not-in-index", "unresolved"]),
      reason: text5,
      matchBasis: z9.enum(["reviewed", "advertised", "conditional"]).nullable(),
      sourceId: text5.nullable(),
      sourceUrl: z9.string(),
      sourceHash: text5.nullable(),
      verifiedAt: date5,
      aliasRevision: text5,
      qualification: z9.string()
    })
  ).optional(),
  fieldEvidence: z9.record(
    z9.string(),
    z9.object({
      status: z9.enum(["confirmed", "unknown"]),
      qualification: z9.string(),
      sources: z9.array(
        z9.object({
          sourceUrl: text5,
          sourceHash: text5,
          observedAt: date5,
          quote: z9.string()
        })
      )
    })
  ).optional(),
  metering: planMeteringSchema.optional(),
  quotaTerms: z9.array(
    z9.object({
      id: text5,
      amount: finite.nonnegative().nullable(),
      unit: z9.enum([
        "requests",
        "tokens",
        "credits",
        "USD",
        "percentage",
        "unknown"
      ]),
      window: z9.enum(["rolling", "week", "month", "unknown"]),
      windowHours: finite.nonnegative().nullable(),
      resetKind: z9.enum([
        "rolling",
        "calendar",
        "subscription-anniversary",
        "unknown"
      ]),
      timezone: text5.nullable(),
      anchor: text5.nullable(),
      poolId: text5,
      aggregation: z9.enum(["simultaneous-gates", "do-not-sum"]),
      qualification: z9.string(),
      evidenceIds: z9.array(text5)
    }).passthrough()
  ).optional(),
  constraints: z9.array(
    z9.object({
      kind: text5,
      value: z9.union([z9.string(), z9.boolean()]),
      qualification: z9.string(),
      evidenceIds: z9.array(text5)
    })
  ).optional(),
  advertisedAccess: z9.array(
    z9.object({
      alias: text5,
      modelVersion: text5.optional(),
      nativeEfforts: z9.array(text5).optional(),
      qualification: z9.string(),
      evidenceIds: z9.array(text5)
    })
  ).optional(),
  usageRates: z9.array(
    z9.object({
      modelAlias: text5,
      currency: z9.string(),
      perTokens: finite.positive(),
      input: finite.nonnegative(),
      output: finite.nonnegative(),
      cacheRead: finite.nonnegative().optional(),
      qualification: z9.string(),
      evidenceIds: z9.array(text5)
    })
  ).optional()
}).passthrough();
var event = z9.object({
  id: text5,
  uid: text5,
  sequence: z9.number().int().nonnegative(),
  start: date5,
  end: date5,
  title: z9.string(),
  kind: text5,
  multiplier: finite.nullable(),
  eligibility: z9.enum(["conditional", "eligible", "ineligible", "unknown"]),
  sourceUrl: z9.string(),
  status: z9.enum(["CONFIRMED", "TENTATIVE", "CANCELLED"]),
  description: z9.string(),
  ruleIds: z9.array(text5),
  lastModified: date5
}).passthrough().refine((value) => Date.parse(value.end) > Date.parse(value.start));
var calendarView = z9.object({
  provider: text5,
  language: z9.enum(["zh", "en"]),
  context: z9.null(),
  timezone: text5,
  from: date5,
  to: date5,
  events: z9.array(event),
  announcements: z9.array(record),
  notes: z9.array(z9.string()),
  sources: z9.array(record)
}).passthrough();
var newsView = z9.object({
  data: z9.array(
    z9.object({
      id: text5,
      title: z9.string(),
      summary: z9.string(),
      provider: text5,
      topic: text5,
      originalUrl: text5,
      observedAt: date5,
      publishedAt: date5.nullable(),
      verification: text5
    }).passthrough()
  )
}).passthrough();
var schemas = {
  client: clientDigestSchema,
  methods: z9.object({
    releaseVersion: z9.string().regex(/^\d+\.\d+\.\d+$/).optional(),
    release: record.optional(),
    methodology: record,
    sources: record,
    snapshot: record,
    legacyPublication: record,
    sourceSnapshots: z9.record(z9.string(), text5.nullable()),
    asOf: date5.nullable()
  }).passthrough(),
  registry: z9.object({
    portfolio: publicPortfolioSchema.optional(),
    clientAliases: clientAliasRegistrySchema.optional(),
    revision: text5,
    developers: z9.array(
      z9.object({ id: text5, name: text5, shortName: text5, mark: text5 })
    ),
    releases: z9.array(
      z9.object({
        id: text5,
        displayName: text5,
        modelsdev: text5,
        developerId: text5,
        lineageId: text5,
        status: z9.enum(["stable", "preview", "retired"]),
        role: text5
      }).passthrough()
    ),
    codingRecords: z9.array(
      z9.object({
        modelId: text5,
        tool: text5,
        status: z9.enum(["current", "retired"]),
        verifiedAt: date5,
        sourceUrl: text5,
        qualification: z9.string()
      }).passthrough()
    ),
    codingArchiveDays: finite.nonnegative(),
    defaultPolicy: z9.object({
      defaultDevelopers: z9.array(text5),
      lineagesByDeveloper: z9.record(z9.string(), z9.array(text5)),
      maxModels: z9.number().int().positive().optional()
    }).passthrough(),
    providers: z9.array(
      z9.object({
        id: text5.regex(/^[\w:.-]{1,96}$/),
        name: text5,
        category: z9.enum(["direct", "aggregator"])
      })
    ),
    planAliases: z9.record(
      z9.string().regex(/^[\w:.-]{1,96}$/),
      text5.regex(/^[\w:.-]{1,96}$/)
    ),
    versions: z9.array(
      z9.object({ id: text5, name: text5, developerId: text5 }).passthrough()
    ),
    catalog: z9.object({
      entries: z9.array(record),
      models: z9.array(record),
      configurations: z9.array(record),
      services: z9.array(record)
    })
  }).passthrough(),
  models: z9.object({
    index: dataset,
    legacy: dataset,
    publicModels: z9.array(
      z9.object({ id: text5, name: text5, configurations: z9.array(record) }).passthrough()
    ),
    configurations: z9.array(
      z9.object({
        id: text5,
        slug: text5,
        originalName: text5,
        mappingStatus: z9.enum(["verified", "pending"]),
        evidence: z9.object({ observedAt: date5, snapshotId: text5 }).passthrough()
      }).passthrough()
    ),
    metrics: z9.object({
      profiles: z9.array(
        z9.object({
          modelId: text5,
          name: text5,
          recommended: text5.nullable(),
          configurations: z9.array(
            indexMetric.safeExtend({ effort: text5 })
          )
        }).passthrough()
      ).optional()
    }).passthrough()
  }).passthrough(),
  plans: z9.object({
    plans: z9.array(plan),
    coverage: z9.array(coverage),
    knowledge: planKnowledgeSchema.optional(),
    value: planValuePublicationSchema.optional()
  }).passthrough(),
  rules: z9.object({
    version: text5,
    clientMultipliers: clientMultiplierPackSchema.optional(),
    rules: z9.array(
      z9.object({
        id: text5,
        provider: text5,
        generations: z9.array(text5),
        models: z9.array(text5),
        clients: z9.array(text5),
        timezone: text5,
        startHour: finite,
        endHour: finite
      }).passthrough()
    ),
    unresolved: z9.array(record)
  }).passthrough(),
  news: z9.object({ zh: newsView, en: newsView }).passthrough(),
  calendar: z9.object({
    from: date5,
    to: date5,
    providers: z9.record(
      z9.string(),
      z9.object({ zh: calendarView, en: calendarView })
    )
  }).passthrough()
};
var encodePublicJSON = (value) => new TextEncoder().encode(JSON.stringify(value));
async function publicContentHash(bytes) {
  const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
function assertPublicOnly(value) {
  if (Array.isArray(value)) {
    value.forEach(assertPublicOnly);
    return;
  }
  if (!isRecord(value)) return;
  for (const [key, child] of Object.entries(value)) {
    if (/^(pages|payload|raw|rawPayload|rawSnapshot|accountRef|credentialRef|apiKey|api_key|accessToken|authorization|owner|prompt|prompts|quotaSnapshot|localReservations|privateQuota|newsAIRecords|password|secret|credentials|cookies|balances)$/i.test(
      key
    ))
      throw new Error("publication_private_field");
    assertPublicOnly(child);
  }
}
function validatePointer(value) {
  assertPublicOnly(value);
  if (!isRecord(value) || value.schemaVersion !== 1 || typeof value.publicationId !== "string" || !PUBLIC_ID.test(value.publicationId) || typeof value.manifestHash !== "string" || !PUBLIC_HASH.test(value.manifestHash) || value.promotionId !== void 0 && (typeof value.promotionId !== "string" || !/^[a-f0-9-]{36}$/.test(value.promotionId)))
    throw new Error("publication_invalid_pointer");
}
function validateManifest(value) {
  assertPublicOnly(value);
  if (!isRecord(value) || value.schemaVersion !== 1 || typeof value.publicationId !== "string" || !PUBLIC_ID.test(value.publicationId) || typeof value.publishedAt !== "string" || !Number.isFinite(Date.parse(value.publishedAt)) || typeof value.comparisonVersion !== "string" || !isRecord(value.methods) || value.methods.index !== "unified-v03-estimator-0.1.0-internal" || value.methods.recommendation !== "balanced-coding-absolute-v4" || !isRecord(value.components))
    throw new Error("publication_incompatible_manifest");
  if (Object.keys(value.components).length !== (value.components.client ? ALL_PUBLIC_COMPONENTS.length : PUBLIC_COMPONENTS.length))
    throw new Error("publication_invalid_components");
  for (const kind of value.components.client ? ALL_PUBLIC_COMPONENTS : PUBLIC_COMPONENTS) {
    const ref = value.components[kind];
    if (!isRecord(ref) || ref.schemaVersion !== 1 || typeof ref.hash !== "string" || !PUBLIC_HASH.test(ref.hash) || !Number.isSafeInteger(ref.bytes) || Number(ref.bytes) < 2 || Number(ref.bytes) > 5e7)
      throw new Error("publication_invalid_reference");
  }
}
function validateComponent(kind, value, manifest) {
  if (!isRecord(value) || value.schemaVersion !== 1 || value.kind !== kind || !isRecord(value.dependencies) || !Array.isArray(value.evidence) || !isRecord(value.data))
    throw new Error("publication_incompatible_component");
  assertPublicOnly(value);
  if (!z9.array(
    z9.object({
      source: text5,
      snapshotId: text5.nullable(),
      observedAt: date5.nullable(),
      validUntil: date5.nullable().optional()
    }).passthrough()
  ).safeParse(value.evidence).success)
    throw new Error("publication_invalid_evidence");
  const dependencies = kind === "plans" && isRecord(value.data) && value.data.value ? [...COMPONENT_DEPENDENCIES[kind], "models"] : COMPONENT_DEPENDENCIES[kind], suppliedDependencies = value.dependencies;
  if (Object.keys(suppliedDependencies).length !== dependencies.length || dependencies.some(
    (key) => suppliedDependencies[key] !== manifest.components[key].hash
  ))
    throw new Error("publication_dependency_mismatch");
  const d = value.data;
  const validation = schemas[kind].safeParse(d);
  if (!validation.success)
    throw Object.assign(new Error(`publication_invalid_data_${kind}`), {
      validationIssues: validation.error.issues.map((issue) => ({
        path: issue.path.join("."),
        code: issue.code
      }))
    });
  const arrays = {
    registry: ["developers", "releases", "codingRecords", "versions"],
    models: ["publicModels", "configurations"],
    plans: ["plans", "coverage"],
    rules: ["rules", "unresolved"]
  };
  if ((arrays[kind] ?? []).some((key) => !Array.isArray(d[key])))
    throw new Error("publication_invalid_data");
  if (kind === "models" && (!isRecord(d.index) || !Array.isArray(d.index.models) || !isRecord(d.legacy) || !Array.isArray(d.legacy.models)))
    throw new Error("publication_invalid_models");
  const catalog = d.catalog;
  if (kind === "registry" && (typeof d.revision !== "string" || !isRecord(d.defaultPolicy) || !isRecord(catalog) || !["entries", "models", "configurations", "services"].every(
    (key) => Array.isArray(catalog[key])
  ) || !Number.isFinite(d.codingArchiveDays)))
    throw new Error("publication_invalid_registry");
  if (kind === "news" && ["zh", "en"].some(
    (lang) => !isRecord(d[lang]) || !Array.isArray(d[lang].data)
  ))
    throw new Error("publication_invalid_news");
  if (kind === "calendar" && (typeof d.from !== "string" || typeof d.to !== "string" || !(Date.parse(d.to) > Date.parse(d.from)) || !isRecord(d.providers)))
    throw new Error("publication_invalid_calendar");
  if (kind === "methods" && (!isRecord(d.legacyPublication) || d.legacyPublication.publicationVersion !== manifest.comparisonVersion))
    throw new Error("publication_comparison_version_mismatch");
}

// shared/client-reader.ts
async function verifyClientDigest(value) {
  validateManifest(value.manifest);
  const {
    schemaVersion,
    comparisonVersion,
    methods,
    components,
    publicationId
  } = value.manifest;
  if ((await publicContentHash(
    encodePublicJSON({
      schemaVersion,
      comparisonVersion,
      methods,
      components
    })
  )).slice(0, 24) !== publicationId)
    throw Error("publication_identity_mismatch");
  const ref = components.client;
  if (!ref) throw Error("publication_client_unavailable");
  const bytes = encodePublicJSON(value.component);
  if (bytes.length > CLIENT_RAW_LIMIT || bytes.length !== ref.bytes || await publicContentHash(bytes) !== ref.hash)
    throw Error("publication_client_hash_mismatch");
  validateComponent("client", value.component, value.manifest);
}
var ClientDataReader = class {
  baseUrl;
  fetcher;
  cache;
  current = null;
  etag = null;
  generation = 0;
  cacheWrite = Promise.resolve();
  constructor(options) {
    this.baseUrl = new URL(
      options.baseUrl.endsWith("/") ? options.baseUrl : options.baseUrl + "/"
    );
    if (!["https:", "http:"].includes(this.baseUrl.protocol) || this.baseUrl.username || this.baseUrl.password || this.baseUrl.hash || this.baseUrl.search || this.baseUrl.protocol === "http:" && !["localhost", "127.0.0.1", "[::1]"].includes(this.baseUrl.hostname))
      throw Error("publication_invalid_base");
    this.fetcher = options.fetcher ?? ((a, b) => fetch(a, b));
    this.cache = options.cache;
  }
  get(path, etag) {
    return this.fetcher(new URL("publications/" + path, this.baseUrl), {
      headers: etag ? { "If-None-Match": etag } : {},
      signal: AbortSignal.timeout(15e3),
      credentials: "omit",
      redirect: "error",
      cache: "no-cache"
    });
  }
  async bytes(path) {
    const r = await this.get(path);
    if (!r.ok) throw Error("publication_http_" + r.status);
    const b = new Uint8Array(await r.arrayBuffer());
    if (b.length > CLIENT_RAW_LIMIT)
      throw Error("publication_object_too_large");
    return path.startsWith("objects/") ? decodePublicationStorage(b, CLIENT_RAW_LIMIT) : b;
  }
  async refresh() {
    const generation = ++this.generation;
    try {
      if (!this.current && this.cache) {
        try {
          const c = await this.cache.load();
          if (c) {
            await verifyClientDigest(c);
            if (generation === this.generation) this.current = c;
          }
        } catch {
        }
      }
      const r = await this.get("current.json", this.current ? this.etag : null);
      if (r.status === 304) {
        if (!this.current) throw Error("publication_unexpected_304");
        return {
          state: "current",
          digest: this.current,
          errorCode: null
        };
      }
      if (!r.ok) throw Error("publication_http_" + r.status);
      const p = await r.json();
      validatePointer(p);
      const tag = r.headers.get("etag");
      if (this.current?.manifest.publicationId === p.publicationId && await publicContentHash(encodePublicJSON(this.current.manifest)) === p.manifestHash) {
        if (generation === this.generation) this.etag = tag;
        return {
          state: "current",
          digest: this.current,
          errorCode: null
        };
      }
      const mb = await this.bytes(`releases/${p.publicationId}/manifest.json`);
      if (await publicContentHash(mb) !== p.manifestHash)
        throw Error("publication_manifest_hash_mismatch");
      const manifest = JSON.parse(new TextDecoder().decode(mb));
      validateManifest(manifest);
      if (manifest.publicationId !== p.publicationId)
        throw Error("publication_identity_mismatch");
      if (!manifest.components.client)
        throw Error("publication_client_unavailable");
      const cb = await this.bytes(
        `objects/${manifest.components.client.hash}.json`
      );
      if (cb.length !== manifest.components.client.bytes || await publicContentHash(cb) !== manifest.components.client.hash)
        throw Error("publication_client_hash_mismatch");
      const next = {
        manifest,
        component: JSON.parse(new TextDecoder().decode(cb))
      };
      await verifyClientDigest(next);
      if (generation === this.generation) {
        if (this.cache) {
          const save = this.cacheWrite.catch(() => {
          }).then(async () => {
            if (generation === this.generation) await this.cache.save(next);
          });
          this.cacheWrite = save;
          await save;
        }
        if (generation === this.generation) {
          this.current = next;
          this.etag = tag;
        }
      }
      return {
        state: "current",
        digest: this.current,
        errorCode: null
      };
    } catch (e) {
      return {
        state: this.current ? "last-good" : "unavailable",
        digest: this.current,
        errorCode: e instanceof Error && e.message.startsWith("publication_") ? e.message : "publication_read_failed"
      };
    }
  }
};
export {
  ClientDataReader,
  encodePublicJSON,
  publicContentHash,
  verifyClientDigest
};
