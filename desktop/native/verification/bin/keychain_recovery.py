# SPDX-License-Identifier: MIT
"""Durable, fail-closed recovery protocol for a future isolated keychain run.

The backend is deliberately supplied by the caller; this module does not call
the system security tool, create a keychain, or enable packaged-candidate runs.
The journal must live on the run's private local scratch, not the shared disk.
"""
import json
import os
from pathlib import Path


def _paths(value):
    return (isinstance(value, list) and all(isinstance(item, str) and item.startswith("/")
                                           and "\0" not in item for item in value))


def begin(journal, keychain, backend, *, run_id, epoch):
    if (not isinstance(keychain, str) or not keychain.startswith("/") or "\0" in keychain
            or not isinstance(run_id, str) or not run_id or not isinstance(epoch, str) or not epoch):
        raise ValueError("explicit run identity and absolute keychain path required")
    original = backend.read_search_list()
    if not _paths(original) or keychain in original:
        raise ValueError("original search list unavailable or already contains run keychain")
    record = {"version": 1, "runID": run_id, "epoch": epoch, "original": original, "temporary": [keychain]}
    fd = os.open(journal, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        json.dump(record, stream, sort_keys=True)
        stream.flush()
        os.fsync(stream.fileno())
    # Journal exists before mutation, including if the backend crashes partway.
    if backend.read_search_list() != original:
        raise ValueError("search list changed during preparation; no mutation attempted")
    backend.write_search_list([keychain])
    if backend.read_search_list() != [keychain]:
        raise RuntimeError("temporary search list unconfirmed; recovery required")
    return record


def recover(journal, backend, *, run_id, epoch):
    path = Path(journal)
    if path.is_symlink() or not path.is_file():
        raise ValueError("regular recovery journal required")
    with path.open(encoding="utf-8") as stream:
        record = json.load(stream)
    if (not isinstance(record, dict) or set(record) != {"version", "runID", "epoch", "original", "temporary"}
            or record["version"] != 1 or record["runID"] != run_id or record["epoch"] != epoch
            or not _paths(record["original"]) or not _paths(record["temporary"])
            or len(record["temporary"]) != 1 or record["temporary"][0] in record["original"]):
        raise ValueError("invalid recovery journal")
    current = backend.read_search_list()
    if current == record["original"]:
        return "already-restored"
    if current != record["temporary"]:
        raise ValueError("search list changed independently; refuse to overwrite")
    backend.write_search_list(record["original"])
    if backend.read_search_list() != record["original"]:
        raise RuntimeError("search list restoration unconfirmed")
    return "restored"
