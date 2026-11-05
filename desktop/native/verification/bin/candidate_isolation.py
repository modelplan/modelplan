#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Fail-closed admission for a packaged candidate.

No candidate is launched by this module. A scratch HOME alone does not prevent
system services from accessing the logged-in user's data. Until the necessary
OS-enforced controls are implemented and verified, the only verdict is refuse.
"""
import json
import sys


def isolation_receipt():
    """Return the current verdict without accepting caller-supplied proof."""
    return {
        "verdict": "refuse",
        "guards": {
            "syntheticInputs": "not-enforced",
            "credentialAndKeychainMutations": "not-enforced",
            "providerNetwork": "not-enforced",
        },
        "proofResults": {
            "syntheticDeniedRead": "not-run",
            "credentialMutationDenied": "not-run",
            "providerNetworkDenied": "not-run",
        },
        "scratchPaths": {},
        "reason": "OS-enforced filesystem, credential-service and network isolation has not been established",
    }


def main():
    print(json.dumps(isolation_receipt(), sort_keys=True))
    return 1


if __name__ == "__main__":
    sys.exit(main())
