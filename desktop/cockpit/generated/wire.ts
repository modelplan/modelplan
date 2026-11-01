// SPDX-License-Identifier: MIT
// Generated from schema/app-cli/app-server.json (Go wire DTOs). DO NOT EDIT.
// Schema SHA-256: b977376c5993c3075a9b9f032499952211bd68cd0026a1735a17872de664f315
import type { Schema } from '../src/schema.js';

export type WireAccount = {
  readonly "accountLocator": string | null;
  readonly "beta": boolean;
  readonly "credits": WireCredits | null;
  readonly "freshUntil": string | null;
  readonly "lastFailure": WireFailure | null;
  readonly "observedAt": string | null;
  readonly "plan": WirePlan;
  readonly "route": "saved_login_api" | "runtime_rpc" | "local_log" | "api_key_api" | "local_sqlite" | "status_line" | "browser_session" | "manual" | "unknown";
  readonly "subscriptionRef": string | null;
  readonly "valueState": "current" | "retained" | "none";
  readonly "windows": ReadonlyArray<WireWindow>;
};

export type WireCockpitAccount = {
  readonly "account": WireAccount;
  readonly "tool": string;
};

export type WireCockpitData = {
  readonly "projection": WireRowsProjection;
  readonly "subscriptions": ReadonlyArray<WireCockpitSubscription>;
};

export type WireCockpitSubscription = {
  readonly "accounts": ReadonlyArray<WireCockpitAccount>;
  readonly "subscriptionRef": string;
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

export type WireReason = {
  readonly "code": "ok" | "estimated" | "stale_reading" | "observation_time_unknown" | "not_read_yet" | "reader_busy" | "consent_changed" | "no_manual_reading" | "no_usage_windows" | "consent_required" | "consent_denied" | "consent_outdated" | "keychain_unset" | "keychain_denied" | "keychain_canceled" | "keychain_not_found" | "keychain_unavailable" | "keychain_confirmation_needed" | "login_expired" | "runtime_missing" | "update_required" | "key_missing" | "tool_not_found" | "catalogue_retired" | "http_401" | "unsupported_login" | "privacy_blocked" | "catalogue_off" | "not_admitted" | "policy_pending" | "codexbar_not_audited" | "codexbar_not_read" | "codexbar_access_unknown" | "browser_session_consent_required" | "no_reader" | "cleanup_pending" | "file_missing" | "file_unreadable" | "parse_error" | "schema_changed" | "http_403" | "http_429" | "http_5xx" | "network" | "timeout" | "other" | "readers_off" | "no_consent" | "no_dock_rows";
  readonly "text": WireText;
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
  readonly "state": "off" | "needs_action" | "needs_consent" | "pending" | "unsupported" | "needs_keychain" | "failed" | "empty" | "stale" | "fresh";
  readonly "stateAfterExpiry": WireExpiryState | null;
  readonly "surfaces": ReadonlyArray<"dock" | "menu" | "settings">;
  readonly "vendorKey": string | null;
};

export type WireRowsProjection = {
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
  readonly "observedAt": string | null;
  readonly "poolKey": string;
  readonly "remainingPercent": number | null;
  readonly "resetMode": "fixed" | "rolling" | "unknown";
  readonly "resetsAt": string | null;
  readonly "role": "session" | "daily" | "weekly" | "monthly" | "other";
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
  "CockpitData": {
    "additionalProperties": false,
    "properties": {
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
