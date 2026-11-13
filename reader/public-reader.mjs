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

// shared/speed-tiers.ts
import { z as z2 } from "zod";

// data/reviewed-speed-tiers.json
var reviewed_speed_tiers_default = {
  schemaVersion: 1,
  tiers: [
    {
      id: "codex-fast",
      harness: "codex",
      tier: "fast",
      label: "Fast",
      toggle: '/fast; config.toml: service_tier = "fast" with [features].fast_mode = true',
      eligibility: {
        plans: ["chatgpt-sign-in"],
        note: "ChatGPT desktop app, Codex CLI and IDE extension when signed in with ChatGPT, for supported models where available. With an API key Codex uses API token pricing and these multipliers do not apply."
      },
      models: [
        { vendorModelId: "gpt-6.1-sol", speed: { ratio: null, qualifier: "unstated" } },
        { vendorModelId: "gpt-6-astra", speed: { ratio: null, qualifier: "unstated" } },
        { vendorModelId: "gpt-6-sol", speed: { ratio: null, qualifier: "unstated" } },
        { vendorModelId: "gpt-6-luna", speed: { ratio: null, qualifier: "unstated" } }
      ],
      billing: [
        { account: "subscription", billsTo: "plan-quota", basis: "included-usage", ratio: 2.5 },
        { account: "credits", billsTo: "credits", basis: "credit-rate", ratio: 2 }
      ],
      caveats: ["speed-stated-for-older-model-only"],
      sources: ["https://learn.chatgpt.com/docs/agent-configuration/speed"],
      reviewedAt: "2026-10-15T06:30:00Z",
      reviewNote: 'Official page: supported models "including" the four listed; 2.5x included subscription limits; 2x purchased credits and Enterprise pay-as-you-go. The only speed figure (1.5x) is stated for GPT-5.6, which is not in the list, so every listed model keeps an unstated speed.'
    },
    {
      id: "codex-ultrafast",
      harness: "codex",
      tier: "ultrafast",
      label: "Ultrafast",
      toggle: "Codex speed selector",
      eligibility: {
        plans: ["chatgpt-pro-500", "enterprise-eligible", "edu-eligible"],
        note: "Pro $500 and eligible Enterprise (credit or USD usage-based agreements; off by default, enabled by workspace owners) and Edu (credits) plans. Other self-serve plans have no access, even with purchased credits. On Pro $500 it uses included usage first, then credits."
      },
      models: [
        { vendorModelId: "gpt-6-astra", speed: { ratio: 8, qualifier: "up-to" } },
        { vendorModelId: "gpt-6.1-sol", speed: { ratio: null, qualifier: "unstated" } }
      ],
      billing: [
        { account: "subscription", billsTo: "plan-quota", basis: "included-usage", ratio: 8 },
        { account: "credits", billsTo: "credits", basis: "credit-rate", ratio: 6 }
      ],
      caveats: ["restricted-plans", "enterprise-off-by-default"],
      sources: ["https://learn.chatgpt.com/docs/agent-configuration/speed"],
      reviewedAt: "2026-10-15T06:30:00Z",
      reviewNote: "Official page: GPT-6 Astra Ultrafast generates tokens up to 8x faster than Astra Standard in Codex (token generation, not task time); no figure for GPT-6.1 Sol. 8x included subscription limits; 6x purchased credits and Enterprise pay-as-you-go. Related ceiling claim: reviewed-speed-claims openai-astra-ultrafast-ceiling-2026-09-29."
    },
    {
      id: "claude-code-fast",
      harness: "claude-code",
      tier: "fast",
      label: "Fast mode",
      toggle: '/fast; settings: "fastMode": true',
      eligibility: {
        plans: ["claude-subscription-usage-credits", "claude-console"],
        note: "Pro, Max, Team and Enterprise through usage credits only (usage credits must be on; Team and Enterprise need an Owner to enable fast mode), and provisioned Claude Console organizations. Not on Amazon Bedrock, Google Cloud, Microsoft Foundry or Claude Platform on AWS. Research preview."
      },
      models: [
        { vendorModelId: "claude-opus-5-5", speed: { ratio: 2.5, qualifier: "up-to" } },
        { vendorModelId: "claude-opus-5", speed: { ratio: 2.5, qualifier: "up-to" } },
        { vendorModelId: "claude-opus-4-8", speed: { ratio: 2.5, qualifier: "up-to" } }
      ],
      billing: [
        { account: "subscription", billsTo: "usage-credits", basis: "token-price", ratio: 2 },
        { account: "api", billsTo: "api", basis: "token-price", ratio: 2 }
      ],
      caveats: ["not-plan-quota", "rebills-context-on-enable", "research-preview", "separate-rate-limit"],
      sources: [
        "https://code.claude.com/docs/en/fast-mode",
        "https://platform.claude.com/docs/en/about-claude/pricing"
      ],
      reviewedAt: "2026-10-15T06:30:00Z",
      reviewNote: "Fast mode $8/$40 per MTok on Opus 5.5 against standard $4/$20, and $10/$50 on Opus 5 and Opus 4.8 against $5/$25: 2x in every case. Up to 2.5x faster, same model. Subscriptions pay from usage credits even with plan allowance left. The first enable in a conversation bills the whole context at the uncached fast input price once."
    }
  ]
};

// shared/speed-tiers.ts
var text2 = z2.string().min(1);
var speedTierSchema = z2.object({
  id: text2,
  harness: z2.enum(["codex", "claude-code"]),
  tier: z2.enum(["fast", "ultrafast"]),
  label: text2,
  toggle: text2,
  eligibility: z2.object({ plans: z2.array(text2).min(1), note: text2 }).strict(),
  models: z2.array(
    z2.object({
      vendorModelId: text2,
      speed: z2.object({
        ratio: z2.number().finite().gt(1).nullable(),
        qualifier: z2.enum(["up-to", "approximate", "unstated"])
      }).strict().refine(
        (s) => s.ratio === null === (s.qualifier === "unstated"),
        "speed_ratio_qualifier_mismatch"
      )
    }).strict()
  ).min(1),
  billing: z2.array(
    z2.object({
      account: z2.enum(["subscription", "credits", "api"]),
      billsTo: z2.enum(["plan-quota", "usage-credits", "credits", "api"]),
      basis: z2.enum(["included-usage", "credit-rate", "token-price"]),
      ratio: z2.number().finite().gt(1)
    }).strict()
  ).min(1),
  caveats: z2.array(
    z2.enum([
      "not-plan-quota",
      "rebills-context-on-enable",
      "research-preview",
      "separate-rate-limit",
      "restricted-plans",
      "enterprise-off-by-default",
      "speed-stated-for-older-model-only"
    ])
  ),
  sources: z2.array(z2.url()).min(1),
  reviewedAt: z2.iso.datetime({ offset: true })
}).strict();
var reviewedSchema = z2.object({
  schemaVersion: z2.literal(1),
  tiers: z2.array(speedTierSchema.safeExtend({ reviewNote: text2 }))
}).strict().refine(
  (v) => new Set(v.tiers.map((t) => t.id)).size === v.tiers.length,
  "duplicate_speed_tier"
);
var REVIEWED_SPEED_TIERS = reviewedSchema.parse(reviewed_speed_tiers_default).tiers.map(({ reviewNote: _note, ...tier }) => tier);
var clientSpeedTierSchema = speedTierSchema.safeExtend({
  models: z2.array(
    z2.object({
      vendorModelId: text2,
      modelId: text2.nullable(),
      speed: speedTierSchema.shape.models.element.shape.speed
    }).strict()
  ).min(1)
});

// shared/client-digest.ts
import { z as z3 } from "zod";

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
var CLIENT_RAW_LIMIT = 25e4;
var text3 = z3.string().min(1);
var scalar = z3.number().finite();
var nullable = scalar.nullable();
var date = z3.string().refine((v) => Number.isFinite(Date.parse(v)));
var ids2 = z3.array(text3);
var tags = z3.array(
  z3.enum([
    "cheapest",
    "strongest",
    "best_value",
    "equivalent_costlier",
    "dominated"
  ])
);
var clientAliasRegistrySchema = z3.object({
  revision: text3,
  checkedAt: text3,
  records: z3.array(
    z3.object({
      modelId: text3,
      sourceModelId: text3,
      harnessIds: z3.object({ api: ids2, "claude-code": ids2, codex: ids2 }).strict(),
      sourceUrls: z3.array(z3.url()),
      qualification: text3,
      requiredEndpoints: z3.record(z3.string(), z3.url())
    }).strict()
  )
}).strict();
var REVIEWED_CLIENT_ALIASES = clientAliasRegistrySchema.parse(client_harness_aliases_default);
var member = z3.object({
  id: text3,
  ability: scalar.optional(),
  cost: scalar.positive().optional(),
  costRelative: scalar.positive().optional(),
  status: z3.literal("incomplete").optional(),
  tags,
  dominatedBy: z3.object({ id: text3, kind: z3.enum(["equivalent", "weaker"]) }).strict().nullable()
}).strict();
var clientDigestSchema = z3.object({
  // Additive fields are optional for historical publications. The producer is held
  // exact by the publication replay check.
  projectionVersion: z3.string().regex(/^client-v1\.[1-9]\d*$/).optional(),
  multipliers: z3.array(clientMultiplierSchema).optional(),
  // client-v1.2 (#347): Fast / Ultrafast and their billing multipliers per harness.
  speedTiers: z3.array(clientSpeedTierSchema).optional(),
  multiplierHorizon: z3.object({
    from: date,
    to: date,
    selection: z3.literal("highest-priority-no-stacking")
  }).strict().optional(),
  units: z3.object({
    ability: z3.literal("websiteAbility"),
    cost: z3.literal("usdPerReferenceTask"),
    time: z3.literal("taskTimeCrossModel")
  }).strict(),
  builtAt: date,
  aliasRevision: text3,
  selectionRevision: text3.optional(),
  developers: z3.array(
    z3.object({ id: text3, name: text3, color: text3, region: text3.nullable() }).strict()
  ),
  models: z3.array(
    z3.object({
      id: text3,
      name: text3,
      developerId: text3,
      current: z3.boolean(),
      // Published selection results only; the reader never derives a ranking.
      lineageId: text3.nullable().optional(),
      lineageStatus: z3.enum(["current", "older", "preview", "retired"]).nullable().optional(),
      defaultSelected: z3.boolean().nullable().optional(),
      recommended: text3.nullable(),
      // ADR 0033; optional so digests published before it still validate.
      recommendationBasis: z3.enum(["balanced", "single-configuration", "assumed-highest"]).nullable().optional(),
      harnessIds: z3.object({ api: ids2, "claude-code": ids2, codex: ids2 }).strict(),
      harnessEvidence: z3.object({
        checkedAt: text3,
        sourceUrls: z3.array(z3.url()),
        qualification: text3,
        requiredEndpoints: z3.record(z3.string(), z3.url())
      }).strict().nullable(),
      efforts: z3.array(
        z3.object({
          effort: text3,
          label: text3,
          available: z3.boolean(),
          ability: nullable,
          abilityBasis: z3.enum(["abilityWithinModel", "capability"]),
          cost: scalar.nonnegative().nullable(),
          costBasisId: text3.nullable(),
          time: scalar.nonnegative().nullable(),
          timeEstimated: z3.boolean(),
          timeBasis: z3.object({
            source: text3,
            cohort: text3,
            boundary: text3,
            referenceSeconds: scalar.positive()
          }).strict().nullable(),
          // Present only when true: the ability rests on evidence outside the range its
          // cross-source link was fitted on. Shown within its own model's ladder only;
          // the producer already leaves it out of every cross-model lineup.
          provisional: z3.literal(true).optional()
        }).strict()
      )
    }).strict()
  ),
  lineups: z3.array(
    z3.object({
      developerId: text3,
      costBasisId: text3,
      method: z3.literal(LINEUP_METHOD),
      tie: z3.literal(LINEUP_TIE),
      baseline: text3,
      frontier: ids2,
      steps: z3.array(
        z3.object({
          from: text3,
          to: text3,
          abilityDelta: scalar,
          costRatio: scalar.positive()
        }).strict()
      ),
      members: z3.array(member)
    }).strict()
  ),
  resets: z3.array(
    z3.object({
      id: text3,
      provider: text3,
      eventType: z3.enum([
        "reset_credit_issued",
        "direct_reset_announced",
        "direct_reset_reported_complete"
      ]).optional(),
      schedule: z3.object({
        precision: z3.enum(["window", "date", "approximate", "deadline"]),
        from: date,
        through: date,
        label: z3.string()
      }).strict().nullable().optional(),
      observationUrl: z3.url().optional(),
      scope: text3.nullable(),
      status: text3,
      at: date.nullable(),
      precision: text3,
      publishedAt: date,
      url: z3.url()
    }).strict()
  ),
  windows: z3.array(
    z3.object({
      id: text3,
      provider: text3,
      title: z3.object({ zh: text3, en: text3 }).strict(),
      startsAt: date,
      endsAt: date,
      status: text3,
      eligibility: text3,
      url: z3.url()
    }).strict()
  )
}).loose().superRefine((d, ctx) => {
  const fail = (message) => ctx.addIssue({ code: "custom", message });
  const unique = (items) => new Set(items).size === items.length;
  if (!unique(d.models.map((m) => m.id)) || !unique(d.developers.map((m) => m.id)) || !unique(d.lineups.map((l) => l.developerId)))
    fail("duplicate_client_identity");
  if (d.projectionVersion !== void 0 !== (d.multipliers !== void 0) || d.projectionVersion !== void 0 !== (d.multiplierHorizon !== void 0))
    fail("incomplete_multiplier_projection");
  if (d.projectionVersion === "client-v1.2" && d.speedTiers === void 0 || d.speedTiers !== void 0 && (d.projectionVersion === void 0 || d.projectionVersion === "client-v1.1"))
    fail("incomplete_speed_tier_projection");
  const models = new Map(d.models.map((m) => [m.id, m]));
  for (const t of d.speedTiers ?? [])
    for (const m of t.models)
      if (m.modelId !== null && !models.get(m.modelId)?.harnessIds[t.harness].includes(m.vendorModelId))
        fail("invalid_speed_tier_model");
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

// shared/effort-reference.ts
import { z as z4 } from "zod";
var EFFORT_REFERENCE_POLICY = Object.freeze({
  id: "bughunt-effort-reference-v1",
  version: "2026-10-13.1",
  scope: "debugging-benchmark-only",
  retainedScoreFraction: 0.8,
  minimumHeadroomFraction: 0.1,
  selection: "least-source-cost-after-quality-protection",
  defaultRecommendationChanged: false,
  automaticRoutingEligible: false
});
var effortReferenceSchema = z4.object({
  policyId: z4.literal("bughunt-effort-reference-v1"),
  policyVersion: z4.string(),
  reviewRevision: z4.string(),
  reviewedSourceCommit: z4.string().regex(/^[a-f0-9]{40}$/),
  source: z4.literal("bughunt"),
  scope: z4.literal("debugging-benchmark-only"),
  scoreBasis: z4.literal("fraction-of-best-observed-in-cohort"),
  costBasis: z4.literal("multiple-of-lowest-complete-run-cost-in-cohort"),
  status: z4.enum(["provisional", "unavailable", "review-required"]),
  effort: z4.string().nullable(),
  nativeEffortSupport: z4.literal("not-established-by-reference"),
  defaultRecommendationChanged: z4.literal(false),
  automaticRoutingEligible: z4.literal(false),
  cohortId: z4.string(),
  sourceModel: z4.string(),
  harness: z4.string(),
  costKind: z4.enum(["bill", "list"]),
  comparability: z4.enum(["documented", "limited"]),
  sourceUrl: z4.url(),
  snapshotId: z4.string().nullable(),
  sourceContentHash: z4.string().regex(/^[a-f0-9]{64}$/).nullable(),
  observedAt: z4.iso.datetime({ offset: true }).nullable(),
  checkedAt: z4.iso.datetime({ offset: true }).nullable(),
  qualityFloorFraction: z4.number().finite().min(0).max(1).nullable(),
  rows: z4.array(
    z4.object({
      recordId: z4.string(),
      effort: z4.string(),
      benchmarkScoreFraction: z4.number().finite().min(0).max(1),
      costMultiplier: z4.number().finite().min(1),
      repetitions: z4.number().int().positive(),
      effortEvidence: z4.string(),
      eligible: z4.boolean()
    }).strict()
  ).max(10),
  limitations: z4.array(z4.string()).max(24),
  reason: z4.string()
}).strict().superRefine((value, ctx) => {
  if (value.status === "provisional" && (!value.snapshotId || !value.sourceContentHash || !value.observedAt || !value.checkedAt || !value.effort || value.rows.length < 2 || !value.rows.some((r) => r.effort === value.effort && r.eligible)))
    ctx.addIssue({
      code: "custom",
      message: "inconsistent_reference_choice"
    });
  if (value.status !== "provisional" && value.effort !== null)
    ctx.addIssue({
      code: "custom",
      message: "unreviewed_reference_cannot_choose"
    });
  if (value.status === "provisional" && value.rows.length) {
    const lo = Math.min(...value.rows.map((r) => r.benchmarkScoreFraction));
    const floor = Math.max(
      EFFORT_REFERENCE_POLICY.retainedScoreFraction,
      lo + EFFORT_REFERENCE_POLICY.minimumHeadroomFraction * (1 - lo)
    );
    const selected = value.rows.find((r) => r.effort === value.effort);
    const expected = value.rows.filter((r) => r.eligible).sort(
      (a, b) => a.costMultiplier - b.costMultiplier || b.benchmarkScoreFraction - a.benchmarkScoreFraction || a.effort.localeCompare(b.effort)
    )[0];
    if (expected?.effort !== selected?.effort || value.qualityFloorFraction === null || Math.abs(value.qualityFloorFraction - floor) > 1e-9 || Math.abs(
      Math.max(...value.rows.map((r) => r.benchmarkScoreFraction)) - 1
    ) > 1e-9 || Math.abs(Math.min(...value.rows.map((r) => r.costMultiplier)) - 1) > 1e-9 || new Set(value.rows.map((r) => r.effort)).size !== value.rows.length || value.rows.some(
      (r) => r.eligible ? r.benchmarkScoreFraction + 1e-9 < floor : r.benchmarkScoreFraction - 1e-9 > floor
    ) || selected && value.rows.some(
      (r) => r.eligible && r.costMultiplier + 1e-9 < selected.costMultiplier
    ))
      ctx.addIssue({
        code: "custom",
        message: "inconsistent_reference_ratios_or_quality_floor"
      });
  }
});

// shared/public-only.ts
function assertPublicField(key) {
  if (/^(pages|payload|raw|rawPayload|rawSnapshot|accountRef|credentialRef|apiKey|api_key|accessToken|authorization|owner|prompt|prompts|quotaSnapshot|localReservations|privateQuota|newsAIRecords|password|secret|credentials|cookies|balances)$/i.test(
    key
  ))
    throw Error("publication_private_field");
}
function assertPublicOnly(value) {
  if (Array.isArray(value)) {
    value.forEach(assertPublicOnly);
    return;
  }
  if (!value || typeof value !== "object") return;
  for (const [key, child] of Object.entries(value)) {
    assertPublicField(key);
    assertPublicOnly(child);
  }
}

// shared/reference-expense-usd.ts
import { z as z5 } from "zod";

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
var positive = z5.number().finite().positive();
var date2 = z5.iso.datetime({ offset: true });
var referenceExpenseWorkloadSchema = z5.object({
  id: z5.literal(reference_expense_usd_default.id),
  sourceId: z5.literal("aa-agent"),
  sourceUrl: z5.url(),
  protocolVersion: z5.literal("1.5"),
  currency: z5.literal("USD"),
  referenceCostUsd: z5.literal(reference_expense_usd_default.referenceCostUsd),
  frozenAt: z5.literal(reference_expense_usd_default.frozenAt),
  statistic: z5.string().min(1),
  referenceModels: positive.int(),
  referenceMakers: positive.int(),
  taskDefinition: z5.string().min(1),
  datasets: z5.array(z5.string().min(1)).length(3),
  pricingDefinition: z5.string().min(1),
  limitation: z5.string().min(1)
}).strict();
var parsedReference = referenceExpenseWorkloadSchema.parse(reference_expense_usd_default);
Object.freeze(parsedReference.datasets);
var REFERENCE_EXPENSE_WORKLOAD = Object.freeze(parsedReference);
var expenseUsdEvidenceSchema = z5.object({
  policyId: z5.literal("reference-task-usd-v1"),
  basis: z5.literal("api-list-price"),
  priceBasisScope: z5.literal("reference-anchor"),
  status: z5.enum(["converted", "estimated", "unavailable"]),
  conversion: z5.enum(["same-source-denormalization", "index-reference-rebase"]).nullable(),
  reason: z5.string().min(1).nullable(),
  referenceWorkload: referenceExpenseWorkloadSchema,
  observedAt: date2.nullable(),
  observedAtMeaning: z5.literal("oldest-contributing-cost-evidence-window"),
  sources: z5.array(
    z5.object({
      id: z5.string().min(1),
      url: z5.url(),
      cohort: z5.string().min(1),
      observedAt: date2,
      windowBasis: z5.enum(["source-evidence-window", "input-capture"])
    }).strict()
  ),
  measured: z5.literal(false),
  empiricalWorkloadCalibration: z5.literal(false),
  isSubscriptionConsumption: z5.literal(false),
  isRealBill: z5.literal(false)
}).strict().superRefine((v, ctx) => {
  if (v.status === "unavailable" !== (v.reason !== null) || v.status === "unavailable" && v.conversion !== null || v.status !== "unavailable" && (!v.observedAt || !v.conversion || !v.sources.length))
    ctx.addIssue({
      code: "custom",
      message: "inconsistent_expense_usd_evidence"
    });
});

// shared/plan-value-contract.ts
import { z as z6 } from "zod";
var PLAN_VALUE_VERSION = "plan-value-v0.2";
var planValuePublicationSchema = z6.object({
  formulaVersion: z6.enum(["plan-value-v0.1", PLAN_VALUE_VERSION]),
  inputHash: z6.string(),
  computedAt: z6.string(),
  calibration: z6.object({
    status: z6.literal("scenario-not-calibrated"),
    fitError: z6.null(),
    reason: z6.string()
  }),
  policy: z6.record(z6.string(), z6.unknown()),
  history: z6.record(z6.string(), z6.unknown()).optional(),
  rows: z6.array(z6.record(z6.string(), z6.unknown())).max(5e3)
}).strict();
var planValueSummarySchema = planValuePublicationSchema.omit({ rows: true }).extend({ rowCount: z6.number().int().nonnegative().max(5e3) }).strict();

// shared/plan-metering.ts
import { z as z7 } from "zod";
var number = z7.number().finite().nonnegative();
var meteringEvidenceSchema = z7.object({
  sourceId: z7.string(),
  sourceUrl: z7.url(),
  sourceHash: z7.string(),
  verifiedAt: z7.iso.datetime({ offset: true }),
  note: z7.string()
}).strict();
var planMeteringSchema = z7.object({
  schemaVersion: z7.literal(1),
  revision: z7.string(),
  priceBasis: z7.object({
    kind: z7.enum([
      "monthly-list",
      "annual",
      "promotion",
      "usage",
      "unknown"
    ]),
    tax: z7.enum(["excluded", "included", "unknown"]),
    currency: z7.string(),
    evidence: meteringEvidenceSchema.nullable()
  }).strict(),
  gates: z7.array(
    z7.object({
      id: z7.string(),
      poolId: z7.string(),
      modelAliases: z7.array(z7.string()).nullable(),
      unit: z7.enum(["USD", "credits", "requests", "tokens", "unknown"]),
      amount: number.nullable(),
      window: z7.enum(["rolling", "fixed", "unknown"]),
      hours: z7.number().positive().nullable(),
      anchor: z7.iso.datetime({ offset: true }).nullable(),
      timezone: z7.string().nullable(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(500),
  rates: z7.array(
    z7.object({
      modelAlias: z7.string(),
      poolId: z7.string(),
      unit: z7.enum(["USD", "credits", "requests", "tokens"]),
      perTokens: z7.number().positive(),
      input: number,
      output: number,
      cacheRead: number.nullable(),
      cacheWrite: number.nullable(),
      minContextTokens: number.nullable(),
      maxContextTokens: number.nullable(),
      condition: z7.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(500),
  timeBands: z7.array(
    z7.object({
      weekdays: z7.array(z7.number().int().min(1).max(7)),
      startHour: z7.number().min(0).max(23),
      endHour: z7.number().min(1).max(24),
      outsideMultiplier: z7.number().positive(),
      timezone: z7.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(4).optional(),
  relativeAllowances: z7.array(
    z7.object({
      basePlanId: z7.string(),
      factor: z7.number().positive(),
      window: z7.string(),
      evidence: meteringEvidenceSchema
    }).strict()
  ).max(20),
  overflow: z7.object({
    policy: z7.enum(["wait", "optional-paid", "unknown"]),
    automatic: z7.boolean().nullable(),
    priceKnown: z7.boolean(),
    evidence: meteringEvidenceSchema.nullable()
  }).strict(),
  limitations: z7.array(z7.string()).max(30)
}).strict();

// shared/public-publication.ts
import { z as z11 } from "zod";

// shared/speed-evidence.ts
import { z as z8 } from "zod";
var SPEED_CHANNELS = [
  "api",
  "subscription-default",
  "fast-mode",
  "ultrafast",
  "unknown"
];
var speedChannelSchema = z8.enum(SPEED_CHANNELS);
var speedDateSchema = z8.string().refine((v) => v === "unknown" || Number.isFinite(Date.parse(v)));
var date3 = z8.string().refine((v) => Number.isFinite(Date.parse(v)));
var id = z8.string().min(1).max(200);
var text4 = z8.string().min(1).max(4e3);
var number2 = z8.number().finite().nonnegative();
var url = z8.string().url().refine((v) => v.startsWith("https://"));
var SPEED_POLICY = {
  version: "channel-speed-evidence-v1",
  maximumChangesPerConfiguration: 32,
  measurementField: "median_output_tokens_per_second",
  diagnosticChannel: "api",
  quantile: "empirical midrank: (count strictly below + 0.5 * count equal) / population size",
  population: "native recommended configurations with both observed cross-model task coordinates and measured API throughput; before request filters",
  clientRule: "taskTimeQuantile <= 0.25 and throughputQuantile >= 2/3; clients decide eligibility using provenance and uncertainty flags"
};
var aaThroughputRecordSchema = z8.object({
  channel: z8.literal("api"),
  source: z8.literal("artificial-analysis"),
  unit: z8.literal("output_tokens_per_second"),
  claim: z8.literal(false),
  configurationId: id,
  value: number2.nullable(),
  status: z8.enum(["available", "missing", "invalid"]),
  field: z8.literal("median_output_tokens_per_second"),
  observedAt: date3,
  firstObservedAt: date3,
  sourceSnapshotHash: z8.string().regex(/^[a-f0-9]{64}$/)
}).strict().refine(
  (r) => r.status === "available" === (r.value !== null) && Date.parse(r.firstObservedAt) <= Date.parse(r.observedAt)
);
var aaThroughputHistorySchema = z8.record(
  id,
  z8.array(aaThroughputRecordSchema).min(1).max(SPEED_POLICY.maximumChangesPerConfiguration)
).refine(
  (v) => Object.keys(v).length <= 1e4 && Object.entries(v).every(
    ([key, rows]) => rows.every((r) => r.configurationId === key)
  )
);
var outputThroughputSchema = z8.object({
  value: number2.nullable(),
  unit: z8.literal("output_tokens_per_second"),
  channel: speedChannelSchema,
  observedAt: speedDateSchema,
  firstObservedAt: speedDateSchema,
  source: text4.nullable(),
  sourceUrl: url.nullable(),
  sourceSnapshotId: id.nullable(),
  configurationId: id.nullable(),
  claim: z8.literal(false),
  statistic: z8.literal("source-reported-median"),
  tokenBasis: z8.literal("source-defined-output"),
  sourceField: z8.literal("median_output_tokens_per_second"),
  status: z8.enum(["available", "missing", "invalid"]),
  reason: text4.nullable(),
  stale: z8.boolean(),
  history: z8.array(aaThroughputRecordSchema)
}).strict().refine(
  (r) => r.status === "available" === (r.value !== null) && r.history.every((h) => h.configurationId === r.configurationId)
);
var speedClaimSchema = z8.object({
  id,
  modelIds: z8.array(id).min(1).max(30),
  effortScope: z8.enum(["explicit", "unknown", "all-declared"]),
  efforts: z8.array(id).max(10),
  channel: speedChannelSchema,
  claim: z8.literal(true),
  sourceKind: z8.enum(["vendor-announcement", "public-report"]),
  metric: z8.enum(["output-throughput", "output-throughput-ratio"]),
  value: number2.nullable(),
  ratio: z8.number().finite().positive().nullable(),
  qualifier: z8.enum(["approximate", "upper-bound", "reported"]),
  boundary: text4,
  tokenBasis: text4,
  publishedAt: speedDateSchema,
  effectiveAt: date3.nullable(),
  effectiveTiming: text4,
  observedAt: date3,
  source: text4,
  sourceUrl: url,
  evidenceUrls: z8.array(url).min(1).max(8),
  evidenceHash: z8.string().regex(/^[a-f0-9]{64}$/).nullable(),
  qualification: text4
}).strict().refine(
  (c) => (c.effortScope === "explicit" ? c.efforts.length > 0 : c.efforts.length === 0) && (c.metric === "output-throughput" ? c.value !== null && c.ratio === null : c.value === null && c.ratio !== null)
);
var reviewedSpeedClaimSchema = speedClaimSchema.safeExtend({
  review: z8.object({
    status: z8.literal("approved"),
    reviewedAt: date3,
    contentHash: z8.string().regex(/^[a-f0-9]{64}$/)
  }).strict(),
  current: z8.boolean()
});
var speedReviewSchema = z8.object({
  claim: speedClaimSchema,
  contentHash: z8.string().regex(/^[a-f0-9]{64}$/),
  status: z8.enum(["pending", "approved", "rejected"]),
  createdAt: date3,
  reviewedAt: date3.nullable(),
  reviewNote: z8.string().max(4e3).nullable()
}).strict().refine(
  (r) => r.status === "pending" || !!r.reviewedAt && !!r.reviewNote?.trim()
);
var speedClaimJournalSchema = z8.object({
  schemaVersion: z8.literal(1),
  entries: z8.array(speedReviewSchema).max(2e4)
}).strict();

// shared/plan-knowledge.ts
import { z as z9 } from "zod";
var text5 = z9.string().min(1).max(4e3);
var id2 = z9.string().regex(/^[\w:.-]{1,160}$/);
var number3 = z9.number().finite().nonnegative();
var hash = z9.string().regex(/^[a-f0-9]{64}$/);
var date4 = text5.refine((value) => Number.isFinite(Date.parse(value)));
var url2 = z9.string().url().refine((value) => value.startsWith("https://"));
var knowledgeProductSchema = z9.object({
  id: id2,
  name: text5,
  vendor: text5,
  category: z9.enum(["direct", "tool", "aggregator", "api", "unknown"])
}).strict();
var knowledgeEntrySchema = z9.object({
  id: id2,
  upstreamPlanId: id2,
  productId: id2,
  tierGroupId: id2,
  name: text5,
  nameEn: z9.string().max(4e3),
  upstreamNames: z9.array(text5),
  billing: z9.enum(["subscription", "metered"]),
  scenario: z9.string().max(4e3),
  region: z9.enum(["cn", "international", "us", "unknown"]),
  generation: z9.string().max(100),
  formalPlanId: id2.nullable(),
  mappingStatus: z9.enum(["unmapped", "linked"])
}).strict();
var knowledgeObservationSchema = z9.object({
  id: id2,
  entryId: id2,
  upstreamModel: text5,
  formalModelId: id2.nullable(),
  upstreamGeneration: z9.string().max(100),
  price: z9.object({
    amount: number3.nullable(),
    currency: z9.string().max(10),
    period: z9.enum(["month", "year", "usage", "unknown"]),
    upstreamAmount: number3.nullable(),
    monthlyEquivalent: number3.nullable(),
    comparisonMonthlyUsd: number3.nullable(),
    status: z9.literal("upstream-observation")
  }).strict(),
  economics: z9.object({
    monthlyTokens: number3.nullable(),
    effectiveUsdPerMillionTokens: number3.nullable(),
    upstreamEffectiveUsdPerMillionTokens: number3.nullable(),
    unmeteredPromotion: z9.boolean(),
    promotionUntil: z9.string().nullable(),
    sharedPool: z9.enum(["shared", "unknown", "not-applicable"]),
    additiveCapacity: z9.literal(false),
    comparisonEligible: z9.boolean(),
    diagnostics: z9.array(text5)
  }).strict(),
  workload: z9.object({
    kind: z9.enum([
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
    saturatedUsage: z9.literal(true),
    contextAndEffort: z9.literal("source-specific-or-unknown")
  }).strict(),
  sample: z9.object({
    label: z9.string().max(4e3),
    kind: z9.string().max(100),
    precision: z9.enum(["day", "month", "range", "unknown"]),
    derivedFrom: z9.string().max(4e3)
  }).strict(),
  confidence: z9.enum(["high", "medium", "low", "unknown"]),
  evidence: z9.object({
    sourceLabel: z9.string().max(4e3),
    sourceUrl: url2,
    links: z9.array(url2),
    note: z9.string().max(4e3),
    observedAt: date4,
    recordHash: hash
  }).strict()
}).strict();
var knowledgeChangeSchema = z9.object({
  id: id2,
  kind: z9.enum(["added", "updated", "withdrawn", "assumptions-review"]),
  observationId: id2.nullable(),
  beforeHash: hash.nullable(),
  afterHash: hash.nullable(),
  sourceCommit: z9.string().regex(/^[a-f0-9]{40}$/),
  observedAt: date4,
  status: z9.enum(["published-observation", "review-required"])
}).strict();
var clock = z9.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/);
var knowledgeCalendarLeadSchema = z9.object({
  id: id2,
  entryId: id2,
  status: z9.literal("UNVERIFIED"),
  formalPlanId: z9.null(),
  formalModelId: z9.null(),
  personalQualification: z9.literal("unknown"),
  requiresOfficialReview: z9.literal(true),
  observationIds: z9.array(id2).min(1),
  sourceCommit: z9.string().regex(/^[a-f0-9]{40}$/),
  sourceHash: hash,
  evidence: z9.array(
    z9.object({
      observationId: id2,
      recordHash: hash,
      sourceUrl: url2,
      originalText: text5,
      observedAt: date4
    }).strict()
  ).min(1),
  proposed: z9.object({
    kind: z9.enum([
      "recurring-window",
      "time-dependent-pricing",
      "limited-promotion"
    ]),
    timezone: z9.string().max(100).refine((value) => {
      try {
        new Intl.DateTimeFormat("en", { timeZone: value });
        return true;
      } catch {
        return false;
      }
    }).nullable(),
    windows: z9.array(
      z9.object({
        start: clock,
        end: clock,
        weekdays: z9.array(z9.number().int().min(1).max(7)).max(7)
      }).strict().refine(
        (window) => window.start !== window.end && new Set(window.weekdays).size === window.weekdays.length
      )
    ),
    coefficient: z9.object({
      value: z9.number().finite().positive(),
      meaning: z9.enum([
        "deduction-multiplier",
        "price-multiplier",
        "capacity-multiplier"
      ])
    }).strict().nullable(),
    validUntil: date4.nullable(),
    conditions: z9.array(text5)
  }).strict()
}).strict();
var planKnowledgeSchema = z9.object({
  schemaVersion: z9.literal(1),
  revision: text5,
  source: z9.object({
    id: z9.literal("real-api-pricing"),
    name: z9.literal("Real API Pricing"),
    url: url2,
    commit: z9.string().regex(/^[a-f0-9]{40}$/),
    adoptedHash: hash,
    conventionsHash: hash,
    capturedAt: date4,
    mappingRevision: text5,
    parserVersion: z9.literal(1),
    attribution: text5
  }).strict(),
  assumptions: z9.object({
    formula: text5,
    tokenPolicy: text5,
    unmeteredPolicy: text5,
    calculationVersion: text5,
    monthWeeks: number3,
    exchangeRate: z9.object({
      value: number3,
      units: z9.literal("CNY per USD"),
      date: text5,
      sourceUrl: url2
    }).strict(),
    capacityMeaning: z9.literal("scenario-estimate-at-saturated-usage"),
    confidenceMeaning: z9.literal("upstream-evidence-grade-not-probability")
  }).strict(),
  products: z9.array(knowledgeProductSchema),
  entries: z9.array(knowledgeEntrySchema),
  observations: z9.array(knowledgeObservationSchema),
  changes: z9.array(knowledgeChangeSchema),
  calendarLeads: z9.array(knowledgeCalendarLeadSchema).optional(),
  reconciliation: z9.object({
    sourceRows: z9.number().int().nonnegative(),
    subscriptionRows: z9.number().int().nonnegative(),
    apiRows: z9.number().int().nonnegative(),
    subscriptionKeys: z9.number().int().nonnegative(),
    apiKeys: z9.number().int().nonnegative(),
    unmappedEntries: z9.number().int().nonnegative()
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
import { z as z10 } from "zod";
var publicPortfolioSchema = z10.object({
  policyVersion: z10.string().min(1),
  revision: z10.string().regex(/^[a-f0-9]{64}$/),
  activeIds: z10.array(z10.string().min(1)).max(32),
  counts: z10.object({
    candidates: z10.number().int().min(0).max(200),
    active: z10.number().int().min(0).max(32),
    observing: z10.number().int().min(0).max(32),
    configurations: z10.number().int().min(0).max(256),
    frozen: z10.number().int().min(0).max(100)
  }),
  vendors: z10.array(
    z10.object({
      developerId: z10.string().min(1),
      name: z10.string().min(1),
      metric: z10.enum(["aa-coding", "aa-intelligence"]),
      score: z10.number().finite(),
      modelId: z10.string().min(1),
      modelName: z10.string().min(1),
      effort: z10.string().min(1),
      sourceUrl: z10.url(),
      observedAt: z10.iso.datetime({ offset: true }),
      provisional: z10.boolean()
    })
  ).max(32),
  mainstays: z10.record(z10.string(), z10.array(z10.string().min(1)).max(4)),
  states: z10.array(
    z10.object({
      id: z10.string().min(1),
      status: z10.enum(["candidate", "observing", "tracked", "frozen"]),
      basis: z10.enum(["benchmark", "paid-popularity", "official-product"]).nullable(),
      reason: z10.string().min(1),
      nextDecisionAt: z10.iso.datetime({ offset: true }).optional(),
      comparisonUntil: z10.iso.datetime({ offset: true }).optional(),
      replacementId: z10.string().min(1).optional(),
      admission: z10.object({
        weeklyRank: z10.number().int().positive().nullable(),
        daily: z10.object({
          date: z10.string().nullable(),
          rank: z10.number().int().positive().nullable(),
          known: z10.boolean(),
          fresh: z10.boolean(),
          previousDate: z10.string().nullable(),
          previousRank: z10.number().int().positive().nullable(),
          confirmed: z10.boolean()
        }).optional(),
        codingEvidenceSources: z10.array(z10.string()).max(10),
        efficientProduct: z10.boolean(),
        diagnostics: z10.array(z10.string()).max(20)
      }).optional()
    })
  ).max(300),
  nextCheckAt: z10.iso.datetime({ offset: true })
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
var ALL_PUBLIC_COMPONENTS = [...PUBLIC_COMPONENTS, "client", "plan-value", "display"];
var COMPONENT_NAME = /^[a-z][a-z0-9-]{0,47}$/;
var COMPONENT_DEPENDENCIES = {
  methods: [],
  registry: [],
  models: ["registry", "methods"],
  plans: ["registry"],
  rules: ["plans"],
  news: ["plans"],
  calendar: ["plans", "rules"],
  client: ["models", "registry", "rules", "calendar"],
  "plan-value": ["models", "plans"],
  display: ["registry", "models"]
};
var PUBLIC_HASH = /^[a-f0-9]{64}$/;
var PUBLIC_ID = /^[a-f0-9]{24}$/;
var isRecord = (value) => !!value && typeof value === "object" && !Array.isArray(value);
var text6 = z11.string().min(1);
var date5 = text6.refine((value) => Number.isFinite(Date.parse(value)));
var finite = z11.number().finite();
var record = z11.record(z11.string(), z11.unknown());
var indexMetric = z11.object({
  methodId: z11.literal("unified-v03-estimator-0.1.0-internal"),
  outputThroughput: outputThroughputSchema.optional(),
  speedDiagnostics: z11.object({
    taskTimeQuantile: finite.min(0).max(1).nullable(),
    throughputQuantile: finite.min(0).max(1).nullable(),
    throughputVsMedian: finite.nonnegative().nullable(),
    populationId: text6,
    reason: text6.nullable()
  }).optional(),
  taskChannel: speedChannelSchema.optional(),
  taskObservedAt: speedDateSchema.optional(),
  abilityIndex: finite.nullable(),
  abilityWithinModel: finite.nullable().optional(),
  abilityWithinModelBasis: z11.enum(["anchor", "same-source-chain", "offset-calibrated"]).nullable().optional(),
  abilityComparability: z11.object({
    version: text6,
    anchorEffort: text6.nullable(),
    path: z11.array(text6),
    sources: z11.array(text6),
    adjacent: z11.array(
      z11.object({
        effort: text6,
        status: z11.enum(["same-source", "unavailable"]),
        points: finite.nullable(),
        sources: z11.array(text6)
      })
    ),
    reason: z11.enum([
      "anchor",
      "same-source-chain",
      "disconnected-evidence"
    ])
  }).optional(),
  taskTimeWithinModel: finite.positive().nullable().optional(),
  taskTimeCrossModel: z11.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    version: text6,
    value: finite.positive().nullable(),
    estimateValue: finite.positive().nullable(),
    sourceMultiplier: finite.positive().nullable(),
    scaleFactor: finite.positive().nullable(),
    source: text6.nullable(),
    sourceSeconds: finite.positive().nullable(),
    referenceSeconds: finite.positive().nullable(),
    cohort: text6.nullable(),
    boundary: text6.nullable(),
    sourceUrl: z11.string().nullable(),
    protocolId: text6.nullable(),
    selectedProtocolId: text6.nullable(),
    anchorEffort: text6.nullable(),
    anchorLevel: finite.positive().nullable(),
    withinModelRatio: finite.positive().nullable(),
    calibrationId: text6,
    calibrationPath: z11.array(text6),
    status: z11.enum([
      "baseline",
      "calibrated",
      "uncalibrated",
      "unavailable"
    ]),
    protocolFallback: z11.boolean(),
    flags: z11.array(text6)
  }).optional(),
  taskTimeWithinModelBasis: z11.enum(["anchor", "same-protocol-chain"]).nullable().optional(),
  taskTimeComparability: z11.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    version: text6,
    protocolId: text6.nullable(),
    source: text6.nullable(),
    cohort: text6.nullable(),
    boundary: text6.nullable(),
    referenceSeconds: finite.positive().nullable(),
    coveredEfforts: z11.array(text6),
    anchorEffort: text6.nullable(),
    componentId: text6.nullable(),
    path: z11.array(text6),
    adjacent: z11.array(
      z11.object({
        effort: text6,
        ratio: finite.positive().nullable(),
        status: z11.enum(["same-protocol", "disconnected"])
      })
    ),
    reason: z11.enum([
      "measured",
      "missing-in-selected-protocol",
      "no-measured-protocol"
    ])
  }).optional(),
  taskTimeEstimate: z11.object({
    channel: speedChannelSchema.optional(),
    observedAt: speedDateSchema.optional(),
    value: finite.positive(),
    seconds: finite.positive(),
    method: z11.enum([
      "interpolated",
      "extrapolated",
      "proxy-aa-generation",
      "anchored-combined",
      "anchored-generation",
      "anchored-generation-ratio"
    ]),
    steps: finite.int().nonnegative().nullable().optional(),
    generationBeta: finite.nullable().optional(),
    interval: z11.object({ low: finite.positive(), high: finite.positive() }).refine((i) => i.low <= i.high).optional(),
    intervalBasis: z11.literal("held-out-residual-p10-p90").optional(),
    anchors: z11.array(text6),
    beta: finite,
    betaVersion: text6,
    expectedError: z11.object({
      median: finite.min(1),
      p90: finite.min(1),
      unit: z11.literal("multiplicative-factor"),
      tests: finite.positive(),
      validation: z11.enum([
        "leave-one-model-out",
        "leave-one-effort-out",
        "conditional-model-holdout"
      ])
    }).nullable(),
    protocolId: text6.optional(),
    source: text6,
    cohort: text6,
    boundary: text6.nullable(),
    referenceSeconds: finite.positive(),
    costSource: text6.nullable(),
    fitId: text6,
    evidenceIds: z11.array(text6),
    exclusions: z11.array(text6).optional(),
    rankingEligible: z11.literal(false)
  }).nullable().optional(),
  taskTimeEstimateReason: text6.optional(),
  expenseMultiplier: finite.nonnegative().nullable(),
  expenseUsdPerTask: finite.nonnegative().nullable().optional(),
  expenseUsdEvidence: expenseUsdEvidenceSchema.optional(),
  taskTimeMultiplier: finite.nonnegative().nullable(),
  taskSeconds: finite.nonnegative().nullable(),
  taskSource: text6.nullable(),
  taskBoundary: text6.nullable(),
  taskCohort: text6.nullable(),
  taskReferenceSeconds: finite.nonnegative().nullable(),
  taskSourceUrl: text6.nullable(),
  basis: text6,
  completeness: z11.object({
    ability: finite,
    expense: finite,
    taskTime: finite
  }),
  sources: z11.array(
    z11.object({
      id: text6,
      label: text6,
      cohort: text6,
      url: text6,
      evidenceWindow: text6
    }).passthrough()
  ),
  effortGains: z11.record(
    z11.string(),
    z11.object({
      points: finite.nullable(),
      sources: z11.array(text6),
      completeness: finite
    })
  ),
  expenseRatios: z11.record(
    z11.string(),
    z11.object({
      ratio: finite.nonnegative().nullable(),
      sources: z11.array(text6)
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
var publicModelSchema = z11.object({
  referenceEffort: effortReferenceSchema.optional(),
  throughputClaims: z11.array(reviewedSpeedClaimSchema).optional(),
  id: text6,
  family: z11.enum(["gpt6", "claude", "zhipu", "other"]),
  name: text6,
  subtitle: z11.string(),
  color: text6,
  recommended: text6.nullable(),
  developerId: text6.optional(),
  efforts: z11.array(
    z11.object({
      effort: text6,
      label: text6,
      capability: finite.nullable(),
      cost: finite.nullable(),
      time: finite.nullable(),
      available: z11.boolean(),
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
var dataset = z11.object({
  releaseVersion: z11.string().regex(/^\d+\.\d+\.\d+$/).optional(),
  models: z11.array(publicModelSchema),
  mode: z11.enum(["index", "aa", "demo", "live"]),
  timeMetric: z11.enum(["task_duration", "agent_wall_time"]),
  statistic: z11.enum(["mean", "source_reported"]),
  updatedAt: date5
}).passthrough();
var coverageStatus = z11.enum([
  "available",
  "conditional",
  "unavailable",
  "unknown"
]);
var coverage = z11.object({
  matchBasis: z11.enum(["reviewed", "advertised", "conditional"]).optional(),
  advertisedAliases: z11.array(text6).optional(),
  aliasRevision: text6.optional(),
  planId: text6,
  modelId: text6,
  modelVersion: text6,
  modelStatus: coverageStatus,
  effortStatus: coverageStatus,
  supportedEfforts: z11.array(text6).nullable(),
  region: text6,
  channel: text6,
  qualification: z11.string().nullable(),
  qualificationSummary: z11.string().max(40).nullable().optional(),
  qualificationSummaryZh: z11.string().max(24).nullable().optional(),
  effectiveFrom: date5.nullable(),
  effectiveUntil: date5.nullable(),
  sourceId: text6.nullable(),
  sourceUrl: z11.string().nullable(),
  verifiedAt: date5.nullable()
}).passthrough();
var plan = z11.object({
  id: text6,
  provider: text6,
  name: text6,
  region: text6,
  generation: text6,
  price: z11.object({
    amount: finite.nonnegative().nullable(),
    currency: z11.string(),
    period: z11.enum(["month", "quarter", "year", "usage", "unknown"]),
    qualifier: z11.string()
  }).passthrough(),
  models: z11.array(text6),
  clients: z11.array(text6),
  quota: z11.string(),
  sourceId: text6.nullable(),
  sourceUrl: text6,
  reviewedAt: date5,
  notes: z11.array(z11.string()),
  coverage: z11.array(coverage).optional(),
  catalogueEvidence: z11.object({
    status: z11.enum(["confirmed", "catalogue-unpublished", "unknown"]),
    sourceUrl: text6,
    verifiedAt: date5,
    note: z11.string()
  }).strict().optional(),
  modelCatalog: z11.object({
    status: z11.enum(["listed", "unpublished", "unknown"]),
    reason: text6,
    sourceUrl: text6,
    verifiedAt: date5,
    note: z11.string(),
    entries: z11.array(
      z11.object({
        name: text6,
        aliases: z11.array(text6),
        status: z11.enum(["indexed", "listed-only", "not-in-index"]),
        reason: text6,
        developerId: text6.nullable(),
        sourceModelId: text6.nullable(),
        modelId: text6.nullable(),
        modelVersion: text6.nullable(),
        kind: z11.enum(["text", "embedding", "unknown"]),
        availability: z11.enum(["listed", "sunsetting", "unknown"]),
        ability: z11.object({
          value: finite,
          kind: z11.enum(["index", "single-source-reference"]),
          methodId: text6,
          configuration: text6.nullable(),
          sourceUrl: text6,
          observedAt: date5,
          sourceStale: z11.boolean(),
          comparableWithIndex: z11.boolean()
        }).strict().nullable(),
        recommendedEffort: text6.nullable(),
        sourceUrl: text6,
        verifiedAt: date5,
        qualification: z11.string()
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
  quotaEstimates: z11.array(
    z11.object({
      amount: finite.nonnegative(),
      unit: z11.literal("requests"),
      window: z11.enum(["5h", "week", "month"]),
      windowHours: finite.nonnegative().nullable(),
      modelAlias: text6,
      client: text6,
      agentTeam: z11.boolean(),
      perSeat: z11.boolean(),
      qualification: z11.string(),
      evidenceIds: z11.array(text6)
    }).strict()
  ).optional(),
  modelListingStatus: z11.enum(["listed", "unknown"]).optional(),
  productLine: z11.object({ id: text6, name: text6, nameZh: text6.optional() }).strict().optional(),
  tierId: text6.optional(),
  listing: z11.enum(["model", "tool"]).optional(),
  variant: z11.object({ scope: z11.enum(["personal", "team", "unknown"]), market: text6, billing: z11.enum(["month", "quarter", "year", "usage", "unknown"]) }).strict().optional(),
  modelListings: z11.array(
    z11.object({
      alias: text6,
      aliases: z11.array(text6),
      advertisedVersion: text6,
      channel: text6,
      channelModelId: text6.nullable(),
      modelId: text6.nullable(),
      modelVersion: text6.nullable(),
      targetModelId: text6.nullable(),
      status: z11.enum(["matched", "not-in-index", "unresolved"]),
      reason: text6,
      matchBasis: z11.enum(["reviewed", "advertised", "conditional"]).nullable(),
      sourceId: text6.nullable(),
      sourceUrl: z11.string(),
      sourceHash: text6.nullable(),
      verifiedAt: date5,
      aliasRevision: text6,
      qualification: z11.string()
    })
  ).optional(),
  fieldEvidence: z11.record(
    z11.string(),
    z11.object({
      status: z11.enum(["confirmed", "unknown"]),
      qualification: z11.string(),
      sources: z11.array(
        z11.object({
          sourceUrl: text6,
          sourceHash: text6,
          observedAt: date5,
          quote: z11.string()
        })
      )
    })
  ).optional(),
  metering: planMeteringSchema.optional(),
  quotaTerms: z11.array(
    z11.object({
      id: text6,
      amount: finite.nonnegative().nullable(),
      unit: z11.enum([
        "requests",
        "tokens",
        "credits",
        "USD",
        "percentage",
        "unknown"
      ]),
      window: z11.enum(["rolling", "week", "month", "unknown"]),
      windowHours: finite.nonnegative().nullable(),
      resetKind: z11.enum([
        "rolling",
        "calendar",
        "subscription-anniversary",
        "unknown"
      ]),
      timezone: text6.nullable(),
      anchor: text6.nullable(),
      poolId: text6,
      aggregation: z11.enum(["simultaneous-gates", "do-not-sum"]),
      qualification: z11.string(),
      evidenceIds: z11.array(text6)
    }).passthrough()
  ).optional(),
  constraints: z11.array(
    z11.object({
      kind: text6,
      value: z11.union([z11.string(), z11.boolean()]),
      qualification: z11.string(),
      evidenceIds: z11.array(text6)
    })
  ).optional(),
  advertisedAccess: z11.array(
    z11.object({
      alias: text6,
      modelVersion: text6.optional(),
      nativeEfforts: z11.array(text6).optional(),
      qualification: z11.string(),
      evidenceIds: z11.array(text6)
    })
  ).optional(),
  usageRates: z11.array(
    z11.object({
      modelAlias: text6,
      currency: z11.string(),
      perTokens: finite.positive(),
      input: finite.nonnegative(),
      output: finite.nonnegative(),
      cacheRead: finite.nonnegative().optional(),
      qualification: z11.string(),
      evidenceIds: z11.array(text6)
    })
  ).optional()
}).passthrough();
var event = z11.object({
  id: text6,
  uid: text6,
  sequence: z11.number().int().nonnegative(),
  start: date5,
  end: date5,
  title: z11.string(),
  kind: text6,
  multiplier: finite.nullable(),
  eligibility: z11.enum(["conditional", "eligible", "ineligible", "unknown"]),
  sourceUrl: z11.string(),
  status: z11.enum(["CONFIRMED", "TENTATIVE", "CANCELLED"]),
  description: z11.string(),
  ruleIds: z11.array(text6),
  lastModified: date5
}).passthrough().refine((value) => Date.parse(value.end) > Date.parse(value.start));
var calendarView = z11.object({
  provider: text6,
  language: z11.enum(["zh", "en"]),
  context: z11.null(),
  timezone: text6,
  from: date5,
  to: date5,
  events: z11.array(event),
  announcements: z11.array(record),
  notes: z11.array(z11.string()),
  sources: z11.array(record)
}).passthrough();
var newsView = z11.object({
  data: z11.array(
    z11.object({
      id: text6,
      title: z11.string(),
      summary: z11.string(),
      provider: text6,
      topic: text6,
      originalUrl: text6,
      observedAt: date5,
      publishedAt: date5.nullable(),
      verification: text6
    }).passthrough()
  )
}).passthrough();
var schemas = {
  "plan-value": planValuePublicationSchema,
  display: z11.object({ registry: record, speed: z11.record(z11.string(), z11.record(z11.string(), z11.object({ throughputStatus: text6.nullable(), reason: z11.string().nullable(), taskTimeQuantile: finite.nullable(), throughputQuantile: finite.nullable() }).strict())) }).strict(),
  client: clientDigestSchema,
  methods: z11.object({
    releaseVersion: z11.string().regex(/^\d+\.\d+\.\d+$/).optional(),
    release: record.optional(),
    methodology: record,
    sources: record,
    snapshot: record,
    legacyPublication: record,
    sourceSnapshots: z11.record(z11.string(), text6.nullable()),
    asOf: date5.nullable()
  }).passthrough(),
  registry: z11.object({
    portfolio: publicPortfolioSchema.optional(),
    clientAliases: clientAliasRegistrySchema.optional(),
    revision: text6,
    developers: z11.array(
      z11.object({ id: text6, name: text6, shortName: text6, mark: text6 })
    ),
    releases: z11.array(
      z11.object({
        id: text6,
        displayName: text6,
        modelsdev: text6,
        developerId: text6,
        lineageId: text6,
        status: z11.enum(["stable", "preview", "retired"]),
        role: text6
      }).passthrough()
    ),
    codingRecords: z11.array(
      z11.object({
        modelId: text6,
        tool: text6,
        status: z11.enum(["current", "retired"]),
        verifiedAt: date5,
        sourceUrl: text6,
        qualification: z11.string()
      }).passthrough()
    ),
    codingArchiveDays: finite.nonnegative(),
    defaultPolicy: z11.object({
      defaultDevelopers: z11.array(text6),
      lineagesByDeveloper: z11.record(z11.string(), z11.array(text6)),
      maxModels: z11.number().int().positive().optional()
    }).passthrough(),
    providers: z11.array(
      z11.object({
        id: text6.regex(/^[\w:.-]{1,96}$/),
        name: text6,
        category: z11.enum(["direct", "aggregator"])
      })
    ),
    planAliases: z11.record(
      z11.string().regex(/^[\w:.-]{1,96}$/),
      text6.regex(/^[\w:.-]{1,96}$/)
    ),
    versions: z11.array(
      z11.object({ id: text6, name: text6, developerId: text6 }).passthrough()
    ),
    catalog: z11.object({
      entries: z11.array(record),
      models: z11.array(record),
      configurations: z11.array(record),
      services: z11.array(record)
    })
  }).passthrough(),
  models: z11.object({
    index: dataset,
    legacy: dataset,
    publicModels: z11.array(
      z11.object({ id: text6, name: text6, configurations: z11.array(record) }).passthrough()
    ),
    configurations: z11.array(
      z11.object({
        id: text6,
        slug: text6,
        originalName: text6,
        mappingStatus: z11.enum(["verified", "pending"]),
        evidence: z11.object({ observedAt: date5, snapshotId: text6 }).passthrough()
      }).passthrough()
    ),
    metrics: z11.object({
      profiles: z11.array(
        z11.object({
          modelId: text6,
          name: text6,
          recommended: text6.nullable(),
          configurations: z11.array(
            indexMetric.safeExtend({ effort: text6 })
          )
        }).passthrough()
      ).optional()
    }).passthrough()
  }).passthrough(),
  plans: z11.object({
    plans: z11.array(plan),
    coverage: z11.array(coverage),
    knowledge: planKnowledgeSchema.optional(),
    value: planValuePublicationSchema.optional(),
    valueSummary: planValueSummarySchema.optional()
  }).passthrough(),
  rules: z11.object({
    version: text6,
    clientMultipliers: clientMultiplierPackSchema.optional(),
    clientWindowDays: z11.number().int().min(1).max(14).optional(),
    speedTiers: z11.array(speedTierSchema).optional(),
    rules: z11.array(
      z11.object({
        id: text6,
        provider: text6,
        generations: z11.array(text6),
        models: z11.array(text6),
        clients: z11.array(text6),
        timezone: text6,
        startHour: finite,
        endHour: finite
      }).passthrough()
    ),
    unresolved: z11.array(record)
  }).passthrough(),
  news: z11.object({ zh: newsView, en: newsView }).passthrough(),
  calendar: z11.object({
    from: date5,
    to: date5,
    providers: z11.record(
      z11.string(),
      z11.object({ zh: calendarView, en: calendarView })
    )
  }).passthrough()
};
var encodePublicJSON = (value) => new TextEncoder().encode(JSON.stringify(value));
async function publicContentHash(bytes) {
  const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
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
  const components = value.components;
  // Kinds this reader does not know (for example page-sized slices) are skipped, not rejected:
  // their references are still checked below, and nothing reads them here.
  if (PUBLIC_COMPONENTS.some((kind) => !components[kind]) || Object.keys(components).length > 32 || Object.keys(components).some((kind) => !COMPONENT_NAME.test(kind)))
    throw new Error("publication_invalid_components");
  for (const kind of Object.keys(value.components)) {
    const ref = value.components[kind];
    if (!isRecord(ref) || ref.schemaVersion !== 1 && ref.schemaVersion !== 2 || kind === "client" && ref.schemaVersion !== 1 || typeof ref.hash !== "string" || !PUBLIC_HASH.test(ref.hash) || !Number.isSafeInteger(ref.bytes) || Number(ref.bytes) < 2 || Number(ref.bytes) > 5e7)
      throw new Error("publication_invalid_reference");
  }
}
function validateComponent(kind, value, manifest) {
  if (!isRecord(value) || value.schemaVersion !== 1 && value.schemaVersion !== 2 || value.schemaVersion !== manifest.components[kind]?.schemaVersion || value.kind !== kind || !isRecord(value.dependencies) || !Array.isArray(value.evidence) || !isRecord(value.data))
    throw new Error("publication_incompatible_component");
  assertPublicOnly(value);
  if (!z11.array(
    z11.object({
      source: text6,
      snapshotId: text6.nullable(),
      observedAt: date5.nullable(),
      validUntil: date5.nullable().optional()
    }).passthrough()
  ).safeParse(value.evidence).success)
    throw new Error("publication_invalid_evidence");
  const dependencies = kind === "plans" && isRecord(value.data) && (value.data.value || value.data.valueSummary) ? [...COMPONENT_DEPENDENCIES[kind], "models"] : COMPONENT_DEPENDENCIES[kind], suppliedDependencies = value.dependencies;
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
  if (kind === "display" && !schemas.registry.safeParse(d.registry).success) throw Error("publication_invalid_display_registry");
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
