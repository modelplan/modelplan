// SPDX-License-Identifier: MIT
// Generated from schema/app-cli/app-server.json (Go wire DTOs). DO NOT EDIT.
// Schema SHA-256: f1152344fe82fa877acbeea7d049b3c5c20250256392de318ea90e5f4529e419
import type { Schema } from '../src/schema.js';

export type WireAccount = {
  readonly "accountLocator": string | null;
  readonly "beta": boolean;
  readonly "credits": WireCredits | null;
  readonly "freshUntil": string | null;
  readonly "lastFailure": WireFailure | null;
  readonly "observedAt": string | null;
  readonly "plan": WirePlan;
  readonly "refreshNotBefore"?: string | null | null;
  readonly "resetCards"?: WireResetCards | null;
  readonly "route": "saved_login_api" | "runtime_rpc" | "local_log" | "api_key_api" | "local_sqlite" | "status_line" | "browser_session" | "manual" | "unknown";
  readonly "subscriptionRef": string | null;
  readonly "today"?: WireAccountToday | null;
  readonly "valueState": "current" | "retained" | "none";
  readonly "windows": ReadonlyArray<WireWindow>;
};

export type WireAccountToday = {
  readonly "bindingBasis": "source-wide-current-binding" | "session-binding";
  readonly "generationTps"?: number | null;
  readonly "observedOutputTokens"?: number | null;
  readonly "runningSessions"?: number | null;
};

export type WireCockpitAccount = {
  readonly "account": WireAccount;
  readonly "tool": string;
};

export type WireCockpitAlert = {
  readonly "remainingPercent": number;
  readonly "severity": string;
  readonly "source": string;
  readonly "subscriptionRef": string;
  readonly "windowId": string;
};

export type WireCockpitCredits = {
  readonly "balance": number | null;
  readonly "observedAt": string;
};

export type WireCockpitData = {
  readonly "details"?: WireCockpitDetails | null;
  readonly "history"?: WireCockpitHistory | null;
  readonly "projection": WireRowsProjection;
  readonly "subscriptions": ReadonlyArray<WireCockpitSubscription>;
};

export type WireCockpitDetails = {
  readonly "alerts": ReadonlyArray<WireCockpitAlert>;
  readonly "forecasts"?: ReadonlyArray<WireCockpitForecast>;
  readonly "publication"?: WireCockpitPublication | null;
  readonly "publishedModels"?: ReadonlyArray<WireCockpitPublicationModel>;
  readonly "resetEvents": ReadonlyArray<WireResetEvent>;
  readonly "sessionCoverage": string;
  readonly "sessions": ReadonlyArray<WireCockpitSession>;
  readonly "sources": ReadonlyArray<string>;
  readonly "subscriptions": ReadonlyArray<WireCockpitSubscriptionDetails>;
  readonly "version": number;
};

export type WireCockpitEntityRanking = {
  readonly "attribution": string;
  readonly "measure": string;
  readonly "recent30d": WireCockpitEntityWindow;
  readonly "recent7d": WireCockpitEntityWindow;
};

export type WireCockpitEntityWindow = {
  readonly "entities": number;
  readonly "top": ReadonlyArray<WireCockpitRankedEntity>;
  readonly "totalObservedOutputTokens": number;
};

export type WireCockpitForecast = {
  readonly "basis": "recent-rate" | "cycle-average" | "none";
  readonly "observedAt": string;
  readonly "pace": "tight" | "on_track" | "surplus" | "exhausted";
  readonly "runsOutAt": string | null;
  readonly "source": string;
  readonly "subscriptionRef": string;
  readonly "windowId": string;
};

export type WireCockpitHistory = {
  readonly "coverage": string;
  readonly "daily": ReadonlyArray<WireCockpitSourceBucket>;
  readonly "dailyFrom": string | null;
  readonly "hourly": ReadonlyArray<WireCockpitSourceBucket>;
  readonly "models": WireCockpitEntityRanking;
  readonly "projects": WireCockpitProjectRanking;
  readonly "recordingSince": string | null;
  readonly "sources": ReadonlyArray<string>;
  readonly "subscriptions": ReadonlyArray<WireCockpitSubscriptionHistory>;
  readonly "tools": WireCockpitEntityRanking;
  readonly "version": number;
};

export type WireCockpitHistorySums = {
  readonly "cacheHitRatio": number | null;
  readonly "cacheReadTokens": number | null;
  readonly "cacheWriteTokens": number | null;
  readonly "eligibleRequests": number;
  readonly "generationTps": number | null;
  readonly "inputTokens": number | null;
  readonly "observedRequests": number;
  readonly "outputTokens": number;
};

export type WireCockpitProjectRanking = {
  readonly "recent30d": ReadonlyArray<WireCockpitRankedProject>;
  readonly "recent7d": ReadonlyArray<WireCockpitRankedProject>;
};

export type WireCockpitPublication = {
  readonly "contractVersion": number;
  readonly "models": ReadonlyArray<WireCockpitPublicationModel>;
  readonly "publicationId": string;
  readonly "publishedAt": string;
  readonly "source": string;
  readonly "truncated": boolean;
};

export type WireCockpitPublicationEffort = {
  readonly "ability": number | null;
  readonly "cost": number | null;
  readonly "effort": string;
  readonly "label": string;
  readonly "multiplier"?: number | null;
  readonly "provisional"?: boolean;
  readonly "star": boolean;
  readonly "time": number | null;
};

export type WireCockpitPublicationModel = {
  readonly "developerId": string;
  readonly "efforts": ReadonlyArray<WireCockpitPublicationEffort>;
  readonly "id": string;
  readonly "name": string;
  readonly "recommended": string;
};

export type WireCockpitQueryParams = {
  readonly "redBelow"?: 10 | 16 | 20 | 25;
};

export type WireCockpitRankedEntity = {
  readonly "name": string;
  readonly "observedOutputTokens": number;
  readonly "observedRequests": number;
  readonly "share": number;
};

export type WireCockpitRankedProject = {
  readonly "effort": string | null;
  readonly "label": string | null;
  readonly "model": string | null;
  readonly "observedOutputTokens": number;
  readonly "ref": string;
  readonly "share": number;
};

export type WireCockpitResetCount = {
  readonly "count": number | null;
  readonly "expiresAt": string | null;
  readonly "kind": string;
};

export type WireCockpitSession = {
  readonly "effort": string | null;
  readonly "lastObservedAt": string;
  readonly "model": string;
  readonly "projectLabel": string | null;
  readonly "rate": number | null;
  readonly "sessionRef": string;
  readonly "source": string;
  readonly "state": string;
  readonly "subscriptionRef": string | null;
};

export type WireCockpitSourceBucket = {
  readonly "at": string;
  readonly "observedOutputTokens": number;
  readonly "source": string;
};

export type WireCockpitSourceHistory = {
  readonly "bindingBasis": string;
  readonly "recent30d": WireCockpitHistorySums;
  readonly "recent7d": WireCockpitHistorySums;
  readonly "source": string;
};

export type WireCockpitSubscription = {
  readonly "accounts": ReadonlyArray<WireCockpitAccount>;
  readonly "subscriptionRef": string;
};

export type WireCockpitSubscriptionDetails = {
  readonly "credits": WireCockpitCredits | null;
  readonly "resetCards"?: WireResetCards | null;
  readonly "resetCounts": ReadonlyArray<WireCockpitResetCount>;
  readonly "resetCountsTruncated"?: boolean;
  readonly "subscriptionRef": string;
  readonly "today": ReadonlyArray<WireCockpitToday>;
};

export type WireCockpitSubscriptionHistory = {
  readonly "sources": ReadonlyArray<WireCockpitSourceHistory>;
  readonly "subscriptionRef": string;
};

export type WireCockpitToday = {
  readonly "bindingBasis": string;
  readonly "generationTps": number | null;
  readonly "observedOutputTokens": number;
  readonly "source": string;
};

export type WireCredits = {
  readonly "balance": number | null;
  readonly "unit": string;
};

export type WireExpiryState = {
  readonly "nextStep": WireNextStep | null;
  readonly "reason": WireReason;
  readonly "state": "off" | "needs_action" | "needs_consent" | "pending" | "unsupported" | "needs_keychain" | "failed" | "empty" | "stale" | "fresh";
};

export type WireFailure = {
  readonly "at": string;
  readonly "code": "ok" | "estimated" | "stale_reading" | "observation_time_unknown" | "not_read_yet" | "reader_busy" | "consent_changed" | "no_manual_reading" | "no_usage_windows" | "consent_required" | "consent_denied" | "consent_outdated" | "keychain_unset" | "keychain_denied" | "keychain_canceled" | "keychain_not_found" | "keychain_unavailable" | "keychain_confirmation_needed" | "login_expired" | "runtime_missing" | "update_required" | "key_missing" | "tool_not_found" | "catalogue_retired" | "http_401" | "unsupported_login" | "privacy_blocked" | "catalogue_off" | "not_admitted" | "policy_pending" | "codexbar_not_audited" | "codexbar_not_read" | "codexbar_access_unknown" | "browser_session_consent_required" | "no_reader" | "cleanup_pending" | "file_missing" | "file_unreadable" | "parse_error" | "schema_changed" | "http_403" | "http_429" | "http_5xx" | "network" | "timeout" | "other" | "readers_off" | "no_consent" | "no_dock_rows";
};

export type WireModelScope = {
  readonly "models": ReadonlyArray<"gemini-2.5-flash" | "gemini-2.5-pro" | "opus" | "sonnet" | "unknown">;
};

export type WireName = {
  readonly "en": string;
  readonly "userAuthored"?: boolean;
  readonly "zh": string;
};

export type WireNextStep = {
  readonly "action": "open_settings_consent" | "open_settings_keychain" | "open_tool" | "install_runtime" | "refresh" | "update_cli" | "none";
  readonly "availableAt"?: string | null;
  readonly "disabledReason"?: "cooldown" | "read_only" | "offline" | null;
  readonly "text": WireText;
};

export type WirePlan = {
  readonly "id": string;
  readonly "name"?: WireName | null;
};

export type WireProposedResetLink = {
  readonly "type": "aihot" | "original" | "official";
  readonly "url": string;
};

export type WireProposedResetSchedule = {
  readonly "from": string;
  readonly "precision": "window" | "date" | "approximate" | "deadline";
  readonly "through": string;
};

export type WireProposedResetSource = {
  readonly "kind": "publication";
  readonly "links"?: ReadonlyArray<WireProposedResetLink>;
  readonly "publicationId": string;
  readonly "url"?: string;
};

export type WireReason = {
  readonly "code": "ok" | "estimated" | "stale_reading" | "observation_time_unknown" | "not_read_yet" | "reader_busy" | "consent_changed" | "no_manual_reading" | "no_usage_windows" | "consent_required" | "consent_denied" | "consent_outdated" | "keychain_unset" | "keychain_denied" | "keychain_canceled" | "keychain_not_found" | "keychain_unavailable" | "keychain_confirmation_needed" | "login_expired" | "runtime_missing" | "update_required" | "key_missing" | "tool_not_found" | "catalogue_retired" | "http_401" | "unsupported_login" | "privacy_blocked" | "catalogue_off" | "not_admitted" | "policy_pending" | "codexbar_not_audited" | "codexbar_not_read" | "codexbar_access_unknown" | "browser_session_consent_required" | "no_reader" | "cleanup_pending" | "file_missing" | "file_unreadable" | "parse_error" | "schema_changed" | "http_403" | "http_429" | "http_5xx" | "network" | "timeout" | "other" | "readers_off" | "no_consent" | "no_dock_rows";
  readonly "text": WireText;
};

export type WireResetCardItem = {
  readonly "expiresAt": string | null;
  readonly "id": string;
};

export type WireResetCardSource = {
  readonly "observedAt": string;
  readonly "source": string;
};

export type WireResetCards = {
  readonly "count": number | null;
  readonly "earliestExpiresAt"?: string | null;
  readonly "items"?: ReadonlyArray<WireResetCardItem>;
  readonly "sources": ReadonlyArray<WireResetCardSource>;
  readonly "state": string;
  readonly "truncated": boolean;
};

export type WireResetEvent = {
  readonly "confirms"?: string;
  readonly "expiresAt": string;
  readonly "id": string;
  readonly "planIds"?: ReadonlyArray<string>;
  readonly "provider": string;
  readonly "publishedAt": string;
  readonly "rowId": string;
  readonly "schedule"?: WireProposedResetSchedule;
  readonly "source": WireProposedResetSource;
  readonly "status": "announced" | "confirmed";
  readonly "version": 1;
};

export type WireRow = {
  readonly "accounts": ReadonlyArray<WireAccount>;
  readonly "consent": "allowed" | "implicit" | "denied" | "unset" | "not_required" | "retired";
  readonly "expiresAt": string | null;
  readonly "id": string;
  readonly "kind": "tool" | "declared";
  readonly "name": WireName;
  readonly "nextStep": WireNextStep | null;
  readonly "order": number;
  readonly "reason": WireReason;
  readonly "refreshNotBefore"?: string | null | null;
  readonly "state": "off" | "needs_action" | "needs_consent" | "pending" | "unsupported" | "needs_keychain" | "failed" | "empty" | "stale" | "fresh";
  readonly "stateAfterExpiry": WireExpiryState | null;
  readonly "surfaces": ReadonlyArray<"dock" | "menu" | "settings">;
  readonly "vendorKey": string | null;
};

export type WireRowsProjection = {
  readonly "forecasts"?: ReadonlyArray<WireCockpitForecast> | null;
  readonly "resetEvents"?: ReadonlyArray<WireResetEvent>;
  readonly "rows": ReadonlyArray<WireRow>;
  readonly "rowsSummary": WireRowsSummary;
  readonly "rowsVersion": number;
};

export type WireRowsSummary = {
  readonly "nextStep": WireNextStep | null;
  readonly "reason": WireReason;
  readonly "state": "ok" | "readers_off" | "no_consent" | "empty" | "pending";
  readonly "text": WireText;
};

export type WireText = {
  readonly "en": string;
  readonly "zh": string;
};

export type WireWindow = {
  readonly "current": boolean;
  readonly "durationSeconds": number | null;
  readonly "id": string;
  readonly "label": WireText;
  readonly "limitKey": string;
  readonly "modelScope"?: WireModelScope;
  readonly "observedAt": string | null;
  readonly "poolKey": string;
  readonly "remainingPercent": number | null;
  readonly "resetMode": "fixed" | "rolling" | "unknown";
  readonly "resetsAt": string | null;
  readonly "role": "session" | "daily" | "weekly" | "monthly" | "other";
  readonly "source"?: "local_history" | "runtime" | "saved_login" | "api_key" | "other" | null;
  readonly "validUntil": string | null;
};

export const definitions: Readonly<Record<string, Schema>> = {
  "Account": {
    "additionalProperties": false,
    "properties": {
      "accountLocator": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "beta": {
        "type": "boolean"
      },
      "credits": {
        "anyOf": [
          {
            "$ref": "#/$defs/Credits"
          },
          {
            "type": "null"
          }
        ]
      },
      "freshUntil": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "lastFailure": {
        "anyOf": [
          {
            "$ref": "#/$defs/Failure"
          },
          {
            "type": "null"
          }
        ]
      },
      "observedAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "plan": {
        "$ref": "#/$defs/Plan"
      },
      "refreshNotBefore": {
        "anyOf": [
          {
            "anyOf": [
              {
                "format": "date-time",
                "type": "string"
              },
              {
                "type": "null"
              }
            ]
          },
          {
            "type": "null"
          }
        ]
      },
      "resetCards": {
        "anyOf": [
          {
            "$ref": "#/$defs/ResetCards"
          },
          {
            "type": "null"
          }
        ]
      },
      "route": {
        "enum": [
          "saved_login_api",
          "runtime_rpc",
          "local_log",
          "api_key_api",
          "local_sqlite",
          "status_line",
          "browser_session",
          "manual",
          "unknown"
        ],
        "type": "string"
      },
      "subscriptionRef": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "today": {
        "anyOf": [
          {
            "$ref": "#/$defs/AccountToday"
          },
          {
            "type": "null"
          }
        ]
      },
      "valueState": {
        "enum": [
          "current",
          "retained",
          "none"
        ],
        "type": "string"
      },
      "windows": {
        "items": {
          "$ref": "#/$defs/Window"
        },
        "type": "array"
      }
    },
    "required": [
      "route",
      "subscriptionRef",
      "accountLocator",
      "plan",
      "beta",
      "credits",
      "valueState",
      "observedAt",
      "freshUntil",
      "lastFailure",
      "windows"
    ],
    "type": "object"
  },
  "AccountToday": {
    "additionalProperties": false,
    "properties": {
      "bindingBasis": {
        "enum": [
          "source-wide-current-binding",
          "session-binding"
        ],
        "type": "string"
      },
      "generationTps": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ],
        "minimum": 0
      },
      "observedOutputTokens": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ],
        "minimum": 1
      },
      "runningSessions": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ],
        "minimum": 1
      }
    },
    "required": [
      "bindingBasis"
    ],
    "type": "object"
  },
  "CockpitAccount": {
    "additionalProperties": false,
    "properties": {
      "account": {
        "$ref": "#/$defs/Account"
      },
      "tool": {
        "type": "string"
      }
    },
    "required": [
      "tool",
      "account"
    ],
    "type": "object"
  },
  "CockpitAlert": {
    "additionalProperties": false,
    "properties": {
      "remainingPercent": {
        "type": "number"
      },
      "severity": {
        "type": "string"
      },
      "source": {
        "type": "string"
      },
      "subscriptionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      },
      "windowId": {
        "type": "string"
      }
    },
    "required": [
      "source",
      "subscriptionRef",
      "windowId",
      "severity",
      "remainingPercent"
    ],
    "type": "object"
  },
  "CockpitCredits": {
    "additionalProperties": false,
    "properties": {
      "balance": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "observedAt": {
        "format": "date-time",
        "type": "string"
      }
    },
    "required": [
      "balance",
      "observedAt"
    ],
    "type": "object"
  },
  "CockpitData": {
    "additionalProperties": false,
    "properties": {
      "details": {
        "anyOf": [
          {
            "$ref": "#/$defs/CockpitDetails"
          },
          {
            "type": "null"
          }
        ]
      },
      "history": {
        "anyOf": [
          {
            "$ref": "#/$defs/CockpitHistory"
          },
          {
            "type": "null"
          }
        ]
      },
      "projection": {
        "$ref": "#/$defs/RowsProjection"
      },
      "subscriptions": {
        "items": {
          "$ref": "#/$defs/CockpitSubscription"
        },
        "type": "array"
      }
    },
    "required": [
      "projection",
      "subscriptions"
    ],
    "type": "object"
  },
  "CockpitDetails": {
    "additionalProperties": false,
    "properties": {
      "alerts": {
        "items": {
          "$ref": "#/$defs/CockpitAlert"
        },
        "maxItems": 128,
        "type": "array"
      },
      "forecasts": {
        "items": {
          "$ref": "#/$defs/CockpitForecast"
        },
        "maxItems": 128,
        "type": "array"
      },
      "publication": {
        "anyOf": [
          {
            "$ref": "#/$defs/CockpitPublication"
          },
          {
            "type": "null"
          }
        ]
      },
      "publishedModels": {
        "items": {
          "$ref": "#/$defs/CockpitPublicationModel"
        },
        "maxItems": 256,
        "type": "array"
      },
      "resetEvents": {
        "items": {
          "$ref": "#/$defs/ResetEvent"
        },
        "maxItems": 64,
        "type": "array"
      },
      "sessionCoverage": {
        "type": "string"
      },
      "sessions": {
        "items": {
          "$ref": "#/$defs/CockpitSession"
        },
        "maxItems": 64,
        "type": "array"
      },
      "sources": {
        "items": {
          "type": "string"
        },
        "maxItems": 4,
        "type": "array",
        "uniqueItems": true
      },
      "subscriptions": {
        "items": {
          "$ref": "#/$defs/CockpitSubscriptionDetails"
        },
        "maxItems": 128,
        "type": "array"
      },
      "version": {
        "maximum": 1,
        "minimum": 1,
        "type": "integer"
      }
    },
    "required": [
      "version",
      "sources",
      "subscriptions",
      "sessions",
      "sessionCoverage",
      "resetEvents",
      "alerts"
    ],
    "type": "object"
  },
  "CockpitEntityRanking": {
    "additionalProperties": false,
    "properties": {
      "attribution": {
        "type": "string"
      },
      "measure": {
        "type": "string"
      },
      "recent30d": {
        "$ref": "#/$defs/CockpitEntityWindow"
      },
      "recent7d": {
        "$ref": "#/$defs/CockpitEntityWindow"
      }
    },
    "required": [
      "measure",
      "attribution",
      "recent7d",
      "recent30d"
    ],
    "type": "object"
  },
  "CockpitEntityWindow": {
    "additionalProperties": false,
    "properties": {
      "entities": {
        "type": "integer"
      },
      "top": {
        "items": {
          "$ref": "#/$defs/CockpitRankedEntity"
        },
        "maxItems": 10,
        "type": "array"
      },
      "totalObservedOutputTokens": {
        "type": "integer"
      }
    },
    "required": [
      "entities",
      "totalObservedOutputTokens",
      "top"
    ],
    "type": "object"
  },
  "CockpitForecast": {
    "additionalProperties": false,
    "properties": {
      "basis": {
        "enum": [
          "recent-rate",
          "cycle-average",
          "none"
        ],
        "type": "string"
      },
      "observedAt": {
        "format": "date-time",
        "type": "string"
      },
      "pace": {
        "enum": [
          "tight",
          "on_track",
          "surplus",
          "exhausted"
        ],
        "type": "string"
      },
      "runsOutAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "source": {
        "type": "string"
      },
      "subscriptionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      },
      "windowId": {
        "type": "string"
      }
    },
    "required": [
      "source",
      "subscriptionRef",
      "windowId",
      "runsOutAt",
      "pace",
      "basis",
      "observedAt"
    ],
    "type": "object"
  },
  "CockpitHistory": {
    "additionalProperties": false,
    "properties": {
      "coverage": {
        "type": "string"
      },
      "daily": {
        "items": {
          "$ref": "#/$defs/CockpitSourceBucket"
        },
        "maxItems": 728,
        "type": "array"
      },
      "dailyFrom": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "hourly": {
        "items": {
          "$ref": "#/$defs/CockpitSourceBucket"
        },
        "maxItems": 192,
        "type": "array"
      },
      "models": {
        "$ref": "#/$defs/CockpitEntityRanking"
      },
      "projects": {
        "$ref": "#/$defs/CockpitProjectRanking"
      },
      "recordingSince": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "sources": {
        "items": {
          "type": "string"
        },
        "maxItems": 4,
        "type": "array",
        "uniqueItems": true
      },
      "subscriptions": {
        "items": {
          "$ref": "#/$defs/CockpitSubscriptionHistory"
        },
        "maxItems": 128,
        "type": "array"
      },
      "tools": {
        "$ref": "#/$defs/CockpitEntityRanking"
      },
      "version": {
        "maximum": 1,
        "minimum": 1,
        "type": "integer"
      }
    },
    "required": [
      "version",
      "sources",
      "coverage",
      "recordingSince",
      "subscriptions",
      "models",
      "tools",
      "dailyFrom",
      "daily",
      "hourly",
      "projects"
    ],
    "type": "object"
  },
  "CockpitHistorySums": {
    "additionalProperties": false,
    "properties": {
      "cacheHitRatio": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "cacheReadTokens": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ]
      },
      "cacheWriteTokens": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ]
      },
      "eligibleRequests": {
        "type": "integer"
      },
      "generationTps": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "inputTokens": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ]
      },
      "observedRequests": {
        "type": "integer"
      },
      "outputTokens": {
        "type": "integer"
      }
    },
    "required": [
      "inputTokens",
      "outputTokens",
      "cacheReadTokens",
      "cacheWriteTokens",
      "cacheHitRatio",
      "generationTps",
      "observedRequests",
      "eligibleRequests"
    ],
    "type": "object"
  },
  "CockpitProjectRanking": {
    "additionalProperties": false,
    "properties": {
      "recent30d": {
        "items": {
          "$ref": "#/$defs/CockpitRankedProject"
        },
        "maxItems": 10,
        "type": "array"
      },
      "recent7d": {
        "items": {
          "$ref": "#/$defs/CockpitRankedProject"
        },
        "maxItems": 10,
        "type": "array"
      }
    },
    "required": [
      "recent7d",
      "recent30d"
    ],
    "type": "object"
  },
  "CockpitPublication": {
    "additionalProperties": false,
    "properties": {
      "contractVersion": {
        "maximum": 1,
        "minimum": 1,
        "type": "integer"
      },
      "models": {
        "items": {
          "$ref": "#/$defs/CockpitPublicationModel"
        },
        "maxItems": 3,
        "type": "array"
      },
      "publicationId": {
        "maxLength": 128,
        "minLength": 1,
        "type": "string"
      },
      "publishedAt": {
        "format": "date-time",
        "type": "string"
      },
      "source": {
        "maxLength": 32,
        "minLength": 1,
        "type": "string"
      },
      "truncated": {
        "type": "boolean"
      }
    },
    "required": [
      "contractVersion",
      "publicationId",
      "publishedAt",
      "source",
      "models",
      "truncated"
    ],
    "type": "object"
  },
  "CockpitPublicationEffort": {
    "additionalProperties": false,
    "properties": {
      "ability": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "cost": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "effort": {
        "maxLength": 64,
        "minLength": 1,
        "type": "string"
      },
      "label": {
        "maxLength": 64,
        "type": "string"
      },
      "multiplier": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "provisional": {
        "type": "boolean"
      },
      "star": {
        "type": "boolean"
      },
      "time": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "required": [
      "effort",
      "label",
      "star",
      "ability",
      "cost",
      "time"
    ],
    "type": "object"
  },
  "CockpitPublicationModel": {
    "additionalProperties": false,
    "properties": {
      "developerId": {
        "maxLength": 128,
        "minLength": 1,
        "type": "string"
      },
      "efforts": {
        "items": {
          "$ref": "#/$defs/CockpitPublicationEffort"
        },
        "maxItems": 32,
        "type": "array"
      },
      "id": {
        "maxLength": 128,
        "minLength": 1,
        "type": "string"
      },
      "name": {
        "maxLength": 200,
        "minLength": 1,
        "type": "string"
      },
      "recommended": {
        "maxLength": 64,
        "type": "string"
      }
    },
    "required": [
      "id",
      "name",
      "developerId",
      "recommended",
      "efforts"
    ],
    "type": "object"
  },
  "CockpitQueryParams": {
    "additionalProperties": false,
    "properties": {
      "redBelow": {
        "enum": [
          10,
          16,
          20,
          25
        ],
        "type": "integer"
      }
    },
    "required": [],
    "type": "object"
  },
  "CockpitRankedEntity": {
    "additionalProperties": false,
    "properties": {
      "name": {
        "type": "string"
      },
      "observedOutputTokens": {
        "type": "integer"
      },
      "observedRequests": {
        "type": "integer"
      },
      "share": {
        "type": "number"
      }
    },
    "required": [
      "name",
      "observedRequests",
      "observedOutputTokens",
      "share"
    ],
    "type": "object"
  },
  "CockpitRankedProject": {
    "additionalProperties": false,
    "properties": {
      "effort": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "label": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "model": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "observedOutputTokens": {
        "type": "integer"
      },
      "ref": {
        "maxLength": 64,
        "type": "string"
      },
      "share": {
        "type": "number"
      }
    },
    "required": [
      "ref",
      "label",
      "model",
      "effort",
      "observedOutputTokens",
      "share"
    ],
    "type": "object"
  },
  "CockpitResetCount": {
    "additionalProperties": false,
    "properties": {
      "count": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ]
      },
      "expiresAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "kind": {
        "type": "string"
      }
    },
    "required": [
      "kind",
      "count",
      "expiresAt"
    ],
    "type": "object"
  },
  "CockpitSession": {
    "additionalProperties": false,
    "properties": {
      "effort": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "lastObservedAt": {
        "format": "date-time",
        "type": "string"
      },
      "model": {
        "type": "string"
      },
      "projectLabel": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "rate": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "sessionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      },
      "source": {
        "type": "string"
      },
      "state": {
        "type": "string"
      },
      "subscriptionRef": {
        "anyOf": [
          {
            "maxLength": 16,
            "pattern": "^[a-f0-9]{16}$",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "required": [
      "sessionRef",
      "source",
      "subscriptionRef",
      "model",
      "effort",
      "projectLabel",
      "lastObservedAt",
      "state",
      "rate"
    ],
    "type": "object"
  },
  "CockpitSourceBucket": {
    "additionalProperties": false,
    "properties": {
      "at": {
        "maxLength": 32,
        "type": "string"
      },
      "observedOutputTokens": {
        "type": "integer"
      },
      "source": {
        "type": "string"
      }
    },
    "required": [
      "at",
      "source",
      "observedOutputTokens"
    ],
    "type": "object"
  },
  "CockpitSourceHistory": {
    "additionalProperties": false,
    "properties": {
      "bindingBasis": {
        "type": "string"
      },
      "recent30d": {
        "$ref": "#/$defs/CockpitHistorySums"
      },
      "recent7d": {
        "$ref": "#/$defs/CockpitHistorySums"
      },
      "source": {
        "type": "string"
      }
    },
    "required": [
      "source",
      "bindingBasis",
      "recent7d",
      "recent30d"
    ],
    "type": "object"
  },
  "CockpitSubscription": {
    "additionalProperties": false,
    "properties": {
      "accounts": {
        "items": {
          "$ref": "#/$defs/CockpitAccount"
        },
        "type": "array"
      },
      "subscriptionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      }
    },
    "required": [
      "subscriptionRef",
      "accounts"
    ],
    "type": "object"
  },
  "CockpitSubscriptionDetails": {
    "additionalProperties": false,
    "properties": {
      "credits": {
        "anyOf": [
          {
            "$ref": "#/$defs/CockpitCredits"
          },
          {
            "type": "null"
          }
        ]
      },
      "resetCards": {
        "anyOf": [
          {
            "$ref": "#/$defs/ResetCards"
          },
          {
            "type": "null"
          }
        ]
      },
      "resetCounts": {
        "items": {
          "$ref": "#/$defs/CockpitResetCount"
        },
        "maxItems": 64,
        "type": "array"
      },
      "resetCountsTruncated": {
        "type": "boolean"
      },
      "subscriptionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      },
      "today": {
        "items": {
          "$ref": "#/$defs/CockpitToday"
        },
        "maxItems": 4,
        "type": "array"
      }
    },
    "required": [
      "subscriptionRef",
      "resetCounts",
      "credits",
      "today"
    ],
    "type": "object"
  },
  "CockpitSubscriptionHistory": {
    "additionalProperties": false,
    "properties": {
      "sources": {
        "items": {
          "$ref": "#/$defs/CockpitSourceHistory"
        },
        "maxItems": 4,
        "type": "array"
      },
      "subscriptionRef": {
        "maxLength": 16,
        "pattern": "^[a-f0-9]{16}$",
        "type": "string"
      }
    },
    "required": [
      "subscriptionRef",
      "sources"
    ],
    "type": "object"
  },
  "CockpitToday": {
    "additionalProperties": false,
    "properties": {
      "bindingBasis": {
        "type": "string"
      },
      "generationTps": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "observedOutputTokens": {
        "type": "integer"
      },
      "source": {
        "type": "string"
      }
    },
    "required": [
      "source",
      "observedOutputTokens",
      "generationTps",
      "bindingBasis"
    ],
    "type": "object"
  },
  "Credits": {
    "additionalProperties": false,
    "properties": {
      "balance": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "unit": {
        "type": "string"
      }
    },
    "required": [
      "balance",
      "unit"
    ],
    "type": "object"
  },
  "ExpiryState": {
    "additionalProperties": false,
    "properties": {
      "nextStep": {
        "anyOf": [
          {
            "$ref": "#/$defs/NextStep"
          },
          {
            "type": "null"
          }
        ]
      },
      "reason": {
        "$ref": "#/$defs/Reason"
      },
      "state": {
        "enum": [
          "off",
          "needs_action",
          "needs_consent",
          "pending",
          "unsupported",
          "needs_keychain",
          "failed",
          "empty",
          "stale",
          "fresh"
        ],
        "type": "string"
      }
    },
    "required": [
      "state",
      "reason",
      "nextStep"
    ],
    "type": "object"
  },
  "Failure": {
    "additionalProperties": false,
    "properties": {
      "at": {
        "format": "date-time",
        "type": "string"
      },
      "code": {
        "enum": [
          "ok",
          "estimated",
          "stale_reading",
          "observation_time_unknown",
          "not_read_yet",
          "reader_busy",
          "consent_changed",
          "no_manual_reading",
          "no_usage_windows",
          "consent_required",
          "consent_denied",
          "consent_outdated",
          "keychain_unset",
          "keychain_denied",
          "keychain_canceled",
          "keychain_not_found",
          "keychain_unavailable",
          "keychain_confirmation_needed",
          "login_expired",
          "runtime_missing",
          "update_required",
          "key_missing",
          "tool_not_found",
          "catalogue_retired",
          "http_401",
          "unsupported_login",
          "privacy_blocked",
          "catalogue_off",
          "not_admitted",
          "policy_pending",
          "codexbar_not_audited",
          "codexbar_not_read",
          "codexbar_access_unknown",
          "browser_session_consent_required",
          "no_reader",
          "cleanup_pending",
          "file_missing",
          "file_unreadable",
          "parse_error",
          "schema_changed",
          "http_403",
          "http_429",
          "http_5xx",
          "network",
          "timeout",
          "other",
          "readers_off",
          "no_consent",
          "no_dock_rows"
        ],
        "type": "string"
      }
    },
    "required": [
      "code",
      "at"
    ],
    "type": "object"
  },
  "ModelScope": {
    "additionalProperties": false,
    "properties": {
      "models": {
        "items": {
          "enum": [
            "gemini-2.5-flash",
            "gemini-2.5-pro",
            "opus",
            "sonnet",
            "unknown"
          ],
          "type": "string"
        },
        "maxItems": 32,
        "minItems": 1,
        "type": "array",
        "uniqueItems": true
      }
    },
    "required": [
      "models"
    ],
    "type": "object"
  },
  "Name": {
    "additionalProperties": false,
    "properties": {
      "en": {
        "type": "string"
      },
      "userAuthored": {
        "type": "boolean"
      },
      "zh": {
        "type": "string"
      }
    },
    "required": [
      "en",
      "zh"
    ],
    "type": "object"
  },
  "NextStep": {
    "additionalProperties": false,
    "properties": {
      "action": {
        "enum": [
          "open_settings_consent",
          "open_settings_keychain",
          "open_tool",
          "install_runtime",
          "refresh",
          "update_cli",
          "none"
        ],
        "type": "string"
      },
      "availableAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "disabledReason": {
        "anyOf": [
          {
            "enum": [
              "cooldown",
              "read_only",
              "offline"
            ],
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "text": {
        "$ref": "#/$defs/Text"
      }
    },
    "required": [
      "action",
      "text"
    ],
    "type": "object"
  },
  "Plan": {
    "additionalProperties": false,
    "properties": {
      "id": {
        "type": "string"
      },
      "name": {
        "anyOf": [
          {
            "$ref": "#/$defs/Name"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "required": [
      "id"
    ],
    "type": "object"
  },
  "ProposedResetLink": {
    "additionalProperties": false,
    "properties": {
      "type": {
        "enum": [
          "aihot",
          "original",
          "official"
        ],
        "type": "string"
      },
      "url": {
        "maxLength": 2048,
        "pattern": "^https://[A-Za-z0-9.-]+(/[A-Za-z0-9/_-]*)?$",
        "type": "string"
      }
    },
    "required": [
      "type",
      "url"
    ],
    "type": "object"
  },
  "ProposedResetSchedule": {
    "additionalProperties": false,
    "properties": {
      "from": {
        "format": "date-time",
        "type": "string"
      },
      "precision": {
        "enum": [
          "window",
          "date",
          "approximate",
          "deadline"
        ],
        "type": "string"
      },
      "through": {
        "format": "date-time",
        "type": "string"
      }
    },
    "required": [
      "precision",
      "from",
      "through"
    ],
    "type": "object"
  },
  "ProposedResetSource": {
    "additionalProperties": false,
    "properties": {
      "kind": {
        "enum": [
          "publication"
        ],
        "type": "string"
      },
      "links": {
        "description": "Present only when the client declares resetEventLinksV1; admitted links come from verified publication URL fields.",
        "items": {
          "$ref": "#/$defs/ProposedResetLink"
        },
        "maxItems": 3,
        "type": "array",
        "uniqueItems": true
      },
      "publicationId": {
        "pattern": "^[a-f0-9]{24}$",
        "type": "string"
      },
      "url": {
        "maxLength": 2048,
        "pattern": "^https://[A-Za-z0-9.-]+(/[A-Za-z0-9._~/%+:-]*)?$",
        "type": "string"
      }
    },
    "required": [
      "kind",
      "publicationId"
    ],
    "type": "object"
  },
  "Reason": {
    "additionalProperties": false,
    "properties": {
      "code": {
        "enum": [
          "ok",
          "estimated",
          "stale_reading",
          "observation_time_unknown",
          "not_read_yet",
          "reader_busy",
          "consent_changed",
          "no_manual_reading",
          "no_usage_windows",
          "consent_required",
          "consent_denied",
          "consent_outdated",
          "keychain_unset",
          "keychain_denied",
          "keychain_canceled",
          "keychain_not_found",
          "keychain_unavailable",
          "keychain_confirmation_needed",
          "login_expired",
          "runtime_missing",
          "update_required",
          "key_missing",
          "tool_not_found",
          "catalogue_retired",
          "http_401",
          "unsupported_login",
          "privacy_blocked",
          "catalogue_off",
          "not_admitted",
          "policy_pending",
          "codexbar_not_audited",
          "codexbar_not_read",
          "codexbar_access_unknown",
          "browser_session_consent_required",
          "no_reader",
          "cleanup_pending",
          "file_missing",
          "file_unreadable",
          "parse_error",
          "schema_changed",
          "http_403",
          "http_429",
          "http_5xx",
          "network",
          "timeout",
          "other",
          "readers_off",
          "no_consent",
          "no_dock_rows"
        ],
        "type": "string"
      },
      "text": {
        "$ref": "#/$defs/Text"
      }
    },
    "required": [
      "code",
      "text"
    ],
    "type": "object"
  },
  "ResetCardItem": {
    "additionalProperties": false,
    "properties": {
      "expiresAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "id": {
        "maxLength": 64,
        "pattern": "^[a-f0-9]{64}$",
        "type": "string"
      }
    },
    "required": [
      "id",
      "expiresAt"
    ],
    "type": "object"
  },
  "ResetCardSource": {
    "additionalProperties": false,
    "properties": {
      "observedAt": {
        "format": "date-time",
        "type": "string"
      },
      "source": {
        "type": "string"
      }
    },
    "required": [
      "source",
      "observedAt"
    ],
    "type": "object"
  },
  "ResetCards": {
    "additionalProperties": false,
    "properties": {
      "count": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ],
        "maximum": 10000,
        "minimum": 0
      },
      "earliestExpiresAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "items": {
        "items": {
          "$ref": "#/$defs/ResetCardItem"
        },
        "maxItems": 64,
        "type": "array"
      },
      "sources": {
        "items": {
          "$ref": "#/$defs/ResetCardSource"
        },
        "maxItems": 16,
        "type": "array"
      },
      "state": {
        "type": "string"
      },
      "truncated": {
        "type": "boolean"
      }
    },
    "required": [
      "state",
      "count",
      "truncated",
      "sources"
    ],
    "type": "object"
  },
  "ResetEvent": {
    "additionalProperties": false,
    "properties": {
      "confirms": {
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$",
        "type": "string"
      },
      "expiresAt": {
        "format": "date-time",
        "type": "string"
      },
      "id": {
        "pattern": "^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$",
        "type": "string"
      },
      "planIds": {
        "items": {
          "pattern": "^[a-z][a-z0-9-]{0,47}$",
          "type": "string"
        },
        "maxItems": 32,
        "minItems": 1,
        "type": "array",
        "uniqueItems": true
      },
      "provider": {
        "pattern": "^[a-z][a-z0-9-]{0,47}$",
        "type": "string"
      },
      "publishedAt": {
        "format": "date-time",
        "type": "string"
      },
      "rowId": {
        "pattern": "^[a-z][a-z0-9-]{0,47}$",
        "type": "string"
      },
      "schedule": {
        "$ref": "#/$defs/ProposedResetSchedule"
      },
      "source": {
        "$ref": "#/$defs/ProposedResetSource"
      },
      "status": {
        "enum": [
          "announced",
          "confirmed"
        ],
        "type": "string"
      },
      "version": {
        "enum": [
          1
        ],
        "type": "integer"
      }
    },
    "required": [
      "version",
      "id",
      "rowId",
      "status",
      "publishedAt",
      "expiresAt",
      "source",
      "provider"
    ],
    "type": "object"
  },
  "Row": {
    "additionalProperties": false,
    "properties": {
      "accounts": {
        "items": {
          "$ref": "#/$defs/Account"
        },
        "type": "array"
      },
      "consent": {
        "enum": [
          "allowed",
          "implicit",
          "denied",
          "unset",
          "not_required",
          "retired"
        ],
        "type": "string"
      },
      "expiresAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "id": {
        "type": "string"
      },
      "kind": {
        "enum": [
          "tool",
          "declared"
        ],
        "type": "string"
      },
      "name": {
        "$ref": "#/$defs/Name"
      },
      "nextStep": {
        "anyOf": [
          {
            "$ref": "#/$defs/NextStep"
          },
          {
            "type": "null"
          }
        ]
      },
      "order": {
        "type": "integer"
      },
      "reason": {
        "$ref": "#/$defs/Reason"
      },
      "refreshNotBefore": {
        "anyOf": [
          {
            "anyOf": [
              {
                "format": "date-time",
                "type": "string"
              },
              {
                "type": "null"
              }
            ]
          },
          {
            "type": "null"
          }
        ]
      },
      "state": {
        "enum": [
          "off",
          "needs_action",
          "needs_consent",
          "pending",
          "unsupported",
          "needs_keychain",
          "failed",
          "empty",
          "stale",
          "fresh"
        ],
        "type": "string"
      },
      "stateAfterExpiry": {
        "anyOf": [
          {
            "$ref": "#/$defs/ExpiryState"
          },
          {
            "type": "null"
          }
        ]
      },
      "surfaces": {
        "items": {
          "enum": [
            "dock",
            "menu",
            "settings"
          ],
          "type": "string"
        },
        "type": "array"
      },
      "vendorKey": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "required": [
      "id",
      "kind",
      "order",
      "name",
      "vendorKey",
      "surfaces",
      "consent",
      "state",
      "reason",
      "nextStep",
      "accounts",
      "expiresAt",
      "stateAfterExpiry"
    ],
    "type": "object"
  },
  "RowsProjection": {
    "additionalProperties": false,
    "properties": {
      "forecasts": {
        "anyOf": [
          {
            "items": {
              "$ref": "#/$defs/CockpitForecast"
            },
            "type": "array"
          },
          {
            "type": "null"
          }
        ],
        "maxItems": 128
      },
      "resetEvents": {
        "items": {
          "$ref": "#/$defs/ResetEvent"
        },
        "maxItems": 64,
        "type": "array",
        "uniqueItems": true
      },
      "rows": {
        "items": {
          "$ref": "#/$defs/Row"
        },
        "type": "array"
      },
      "rowsSummary": {
        "$ref": "#/$defs/RowsSummary"
      },
      "rowsVersion": {
        "type": "integer"
      }
    },
    "required": [
      "rowsVersion",
      "rows",
      "rowsSummary"
    ],
    "type": "object"
  },
  "RowsSummary": {
    "additionalProperties": false,
    "properties": {
      "nextStep": {
        "anyOf": [
          {
            "$ref": "#/$defs/NextStep"
          },
          {
            "type": "null"
          }
        ]
      },
      "reason": {
        "$ref": "#/$defs/Reason"
      },
      "state": {
        "enum": [
          "ok",
          "readers_off",
          "no_consent",
          "empty",
          "pending"
        ],
        "type": "string"
      },
      "text": {
        "$ref": "#/$defs/Text"
      }
    },
    "required": [
      "state",
      "reason",
      "text",
      "nextStep"
    ],
    "type": "object"
  },
  "Text": {
    "additionalProperties": false,
    "properties": {
      "en": {
        "type": "string"
      },
      "zh": {
        "type": "string"
      }
    },
    "required": [
      "en",
      "zh"
    ],
    "type": "object"
  },
  "Window": {
    "additionalProperties": false,
    "properties": {
      "current": {
        "type": "boolean"
      },
      "durationSeconds": {
        "anyOf": [
          {
            "type": "integer"
          },
          {
            "type": "null"
          }
        ]
      },
      "id": {
        "type": "string"
      },
      "label": {
        "$ref": "#/$defs/Text"
      },
      "limitKey": {
        "type": "string"
      },
      "modelScope": {
        "$ref": "#/$defs/ModelScope"
      },
      "observedAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "poolKey": {
        "type": "string"
      },
      "remainingPercent": {
        "anyOf": [
          {
            "type": "number"
          },
          {
            "type": "null"
          }
        ]
      },
      "resetMode": {
        "enum": [
          "fixed",
          "rolling",
          "unknown"
        ],
        "type": "string"
      },
      "resetsAt": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "role": {
        "enum": [
          "session",
          "daily",
          "weekly",
          "monthly",
          "other"
        ],
        "type": "string"
      },
      "source": {
        "anyOf": [
          {
            "enum": [
              "local_history",
              "runtime",
              "saved_login",
              "api_key",
              "other"
            ],
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      },
      "validUntil": {
        "anyOf": [
          {
            "format": "date-time",
            "type": "string"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "required": [
      "id",
      "role",
      "durationSeconds",
      "label",
      "limitKey",
      "poolKey",
      "resetMode",
      "remainingPercent",
      "resetsAt",
      "observedAt",
      "current",
      "validUntil"
    ],
    "type": "object"
  }
};
