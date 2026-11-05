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
import time
import process_scan

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


def cleanup_registered(registry, reservation, *, parent, run_id, epoch, subject_closed, lookup, scan,
                       launcher_wait=5.0, clock=time.monotonic, sleep=time.sleep):
    """Require the exact run's direct launcher to be gone and its recorded scope empty.

    LaunchServices has delayed launches and is not supported by this check.
    The normal guardian must already have stopped the registered subject.
    """
    if subject_closed is not True or not isinstance(reservation, dict):
        raise ValueError("subject closure and reservation required")
    if reservation.get("launchMode") != "direct" or reservation.get("state") not in ("running", "launching"):
        raise ValueError("only direct scoped subjects can be cleaned")
    scope = reservation.get("scan")
    launcher = reservation.get("launcher")
    if not process_scan.valid_scope(scope) or not isinstance(launcher, dict):
        raise ValueError("valid launcher identity and process scope required")
    keys = ("pid", "startSeconds", "startMicroseconds")
    if any(type(launcher.get(key)) is not int for key in keys) or launcher["pid"] <= 0:
        raise ValueError("invalid launcher identity")
    deadline = clock() + launcher_wait
    while True:
        current = lookup(launcher["pid"])
        if current is None or any(current.get(key) != launcher[key] for key in keys):
            break
        if clock() >= deadline:
            raise ValueError("launcher still running")
        sleep(0.05)
    root = Path(registry.get("root", "")).resolve()
    prefix = scope.get("prefix")
    if not prefix or not Path(prefix).resolve().is_relative_to(root):
        raise ValueError("process scope is outside candidate scratch")
    if scan(scope):
        raise ValueError("candidate process scope is not empty")
    return cleanup(registry, parent=parent, run_id=run_id, epoch=epoch, subject_closed=True)
