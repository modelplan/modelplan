#!/usr/bin/env python3
"""Read only the user-maintained modelplan local state; emit no arbitrary fields."""
import datetime as dt
import errno
import json
import math
import os
from pathlib import Path
import re
import stat
import sys

LIMIT = 131072


def identifier(value):
    return value if isinstance(value, str) and re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,95}", value) else None


def timestamp(value):
    if not isinstance(value, str) or len(value) > 40:
        return None
    try:
        date = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return value if date.tzinfo is not None else None
    except ValueError:
        return None


def number(value, low, high):
    return value if type(value) in (int, float) and low <= value <= high and math.isfinite(value) else None


def sanitise(raw):
    if not isinstance(raw, dict) or type(raw.get("schemaVersion")) is not int or raw["schemaVersion"] != 1:
        return {"status": "unsupported_schema", "data": None}
    out = {"schemaVersion": 1, "plans": [], "resetCards": [], "windows": []}
    for key in ("plans", "resetCards", "windows"):
        rows = raw.get(key, [])
        if not isinstance(rows, list) or len(rows) > 100:
            return {"status": "invalid", "data": None}
        for row in rows:
            if not isinstance(row, dict) or not identifier(row.get("planId")):
                return {"status": "invalid", "data": None}
            item = {"planId": identifier(row["planId"])}
            if key == "plans":
                harnesses = row.get("harnesses", [])
                if not isinstance(harnesses, list) or len(harnesses) > 20 or any(not identifier(h) for h in harnesses):
                    return {"status": "invalid", "data": None}
                item["harnesses"] = harnesses
            else:
                allowed = ("five_hour", "weekly") if key == "resetCards" else ("five_hour", "weekly", "monthly", "unknown")
                item["kind"] = row.get("kind") if row.get("kind") in allowed else "unknown"
                if key == "resetCards":
                    count = row.get("count")
                    item.update(count=count if type(count) is int and 0 <= count <= 100000 else None,
                                expiresAt=timestamp(row.get("expiresAt")))
                else:
                    item.update(remainingPercent=number(row.get("remainingPercent"), 0, 100),
                                resetAt=timestamp(row.get("resetAt")), observedAt=timestamp(row.get("observedAt")),
                                resetMode=row.get("resetMode") if row.get("resetMode") in ("fixed", "rolling") else "unknown")
                    if "expiresAt" in row:
                        item["expiresAt"] = timestamp(row["expiresAt"])
            out[key].append(item)
    return {"status": "user_maintained", "data": out}


def read_local(path):
    # O_NOFOLLOW protects the final component; reject symlink ancestors as well.
    try:
        for parent in (path, *path.parents):
            if parent.is_symlink():
                return {"status": "unsafe_path", "data": None}
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            os.close(fd)
            return {"status": "unsafe_path", "data": None}
        with os.fdopen(fd, "rb") as stream:
            content = stream.read(LIMIT + 1)
        if len(content) > LIMIT:
            return {"status": "too_large", "data": None}
        return sanitise(json.loads(content))
    except FileNotFoundError:
        return {"status": "missing", "data": None}
    except PermissionError:
        return {"status": "unreadable", "reason": "permission_denied", "data": None}
    except OSError as error:
        if error.errno == errno.ELOOP:
            return {"status": "unsafe_path", "data": None}
        return {"status": "unreadable", "reason": "io_error", "data": None}
    except (ValueError, UnicodeError):
        return {"status": "invalid", "data": None}


if __name__ == "__main__":
    if len(sys.argv) != 1:
        result = {"status": "invalid_arguments", "data": None}
    else:
        result = read_local(Path.home() / ".config" / "modelplan" / "local.json")
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))
