# SPDX-License-Identifier: MIT
"""Fail-closed direct-mode recovery after a run's guardian has died.

Only a recorded candidate scope may be stopped. This routine does not release
the GUI booking; the caller must preserve the returned cleanup receipt and use
the existing booking close contract. M3/M4 isolation and capture are separate.
"""
import json
from pathlib import Path

import candidate_scratch
import guardian
import process_scan

KEYS = ("pid", "startSeconds", "startMicroseconds")


def _identity(value):
    return (isinstance(value, dict) and all(type(value.get(k)) is int for k in KEYS)
            and value["pid"] > 0)


def _same(left, right):
    return _identity(left) and _identity(right) and all(left[k] == right[k] for k in KEYS)


def recover(registry, lease, reservation, guardian_identity, *, parent, pid_file,
            lookup=guardian.identity, scan=None, close=guardian.close):
    if not isinstance(registry, dict) or not isinstance(lease, dict):
        raise ValueError("run registry and lease required")
    run_id, epoch = registry.get("runID"), registry.get("epoch")
    if not run_id or not epoch or lease.get("runID") != run_id or lease.get("epoch") != epoch:
        raise ValueError("run identity mismatch")
    if not _identity(guardian_identity):
        raise ValueError("recorded guardian identity required")
    if _same(lookup(guardian_identity["pid"]), guardian_identity):
        raise ValueError("guardian is still running")
    if not isinstance(reservation, dict) or reservation.get("launchMode") != "direct":
        raise ValueError("direct subject reservation required")
    scope = reservation.get("scan")
    if not process_scan.valid_scope(scope):
        raise ValueError("valid scoped reservation required")
    root = candidate_scratch.validate_registry(registry, parent=parent, run_id=run_id, epoch=epoch).resolve()
    prefix = scope.get("prefix")
    if not prefix or not Path(prefix).resolve().is_relative_to(root):
        raise ValueError("process scope is outside candidate scratch")
    scan = scan or (lambda item: process_scan.scan(item, lookup))
    found = scan(scope)  # failure is not an empty scan
    if reservation.get("state") == "running":
        subject = {key: reservation.get(key) for key in KEYS}
        if not _identity(subject):
            raise ValueError("registered subject identity required")
        actual = lookup(subject["pid"])
        if _same(actual, subject) and not any(_same(item, subject) for item in found):
            raise ValueError("live subject is not in candidate scope")
    elif reservation.get("state") != "launching":
        raise ValueError("registered or launching subject required")
    pid_file = Path(pid_file)
    with guardian.registration(pid_file):
        with pid_file.open(encoding="utf-8") as stream:
            if json.load(stream) != reservation:
                raise ValueError("subject reservation changed")
        closed, _ = close(pid_file)
    if closed is not True:
        raise ValueError("candidate closure unconfirmed")
    return candidate_scratch.cleanup_registered(
        registry, reservation, parent=parent, run_id=run_id, epoch=epoch,
        subject_closed=True, lookup=lookup, scan=scan)
