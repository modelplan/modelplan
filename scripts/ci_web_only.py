#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Conservatively classify the complete three-dot PR diff for Mac routing."""
import re
import subprocess
import sys

PREFIXES = (b"desktop/cockpit/", b"desktop/tests/cockpit/")


def web_only(paths):
    return bool(paths) and all(path and path.startswith(PREFIXES) for path in paths)


def classify(base, head):
    if not all(re.fullmatch(r"[0-9a-f]{40}", ref) for ref in (base, head)):
        raise ValueError("expected full commit IDs")
    data = subprocess.check_output([
        "git", "diff", "--no-ext-diff", "--no-renames", "--name-only", "-z",
        f"{base}...{head}", "--",
    ])
    if data and not data.endswith(b"\0"):
        raise ValueError("incomplete diff")
    return web_only(data[:-1].split(b"\0") if data else [])


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("expected base and head")
        print("true" if classify(*sys.argv[1:]) else "false")
    except (ValueError, subprocess.CalledProcessError) as exc:
        print(f"Unable to classify PR diff: {exc}", file=sys.stderr)
        sys.exit(1)
