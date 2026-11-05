# SPDX-License-Identifier: MIT
"""Create and recover only scratch directories explicitly owned by one candidate run.

This is not a candidate launcher or isolation proof. A supervisor must first
verify that the subject and its helpers are closed, then invoke cleanup using
the original registry. An unreadable or mismatched registry fails closed.
"""
import json
import os
from pathlib import Path
import secrets
import shutil
import tempfile

PREFIX = "modelplan-candidate-"
MARKER = ".modelplan-owned-run.json"


def create(parent, run_id, epoch):
    parent = Path(parent)
    if not parent.is_absolute() or parent.is_symlink() or not parent.is_dir():
        raise ValueError("existing absolute non-symlink scratch parent required")
    if not isinstance(run_id, str) or not run_id or not isinstance(epoch, str) or not epoch:
        raise ValueError("run identity required")
    root = Path(tempfile.mkdtemp(prefix=PREFIX, dir=parent))
    token = secrets.token_hex(32)
    stat = root.stat()
    registry = {"root": str(root), "parent": str(parent.resolve()), "runID": run_id,
                "epoch": epoch, "token": token, "device": stat.st_dev, "inode": stat.st_ino}
    try:
        marker = root / MARKER
        fd = os.open(marker, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(registry, stream, sort_keys=True)
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        shutil.rmtree(root)
        raise
    return registry


def cleanup(registry, *, parent, run_id, epoch, subject_closed):
    if subject_closed is not True:
        raise ValueError("subject closure not confirmed")
    if not isinstance(registry, dict) or registry.get("runID") != run_id or registry.get("epoch") != epoch:
        raise ValueError("run identity mismatch")
    approved_parent = Path(parent)
    if not approved_parent.is_absolute() or approved_parent.is_symlink() or not approved_parent.is_dir():
        raise ValueError("scratch parent invalid")
    if str(approved_parent.resolve()) != registry.get("parent"):
        raise ValueError("scratch parent mismatch")
    root = Path(registry.get("root", ""))
    if (not root.is_absolute() or root.is_symlink() or not root.name.startswith(PREFIX)
            or root.parent.resolve() != approved_parent.resolve() or not root.is_dir()):
        raise ValueError("scratch root invalid")
    stat = root.stat()
    if (stat.st_uid != os.geteuid() or stat.st_dev != registry.get("device")
            or stat.st_ino != registry.get("inode")):
        raise ValueError("scratch identity changed")
    marker = root / MARKER
    if marker.is_symlink() or not marker.is_file():
        raise ValueError("scratch marker missing or unsafe")
    with marker.open(encoding="utf-8") as stream:
        if json.load(stream) != registry:
            raise ValueError("scratch marker mismatch")
    if not shutil.rmtree.avoids_symlink_attacks:
        raise RuntimeError("safe directory removal unavailable")
    shutil.rmtree(root)
    return {"runID": run_id, "epoch": epoch, "cleaned": not root.exists()}
