# SPDX-License-Identifier: MIT
"""Prepare a pinned app archive for the existing booked, guardian-led launch.

Preparation does not launch anything. The caller must book, start a guardian
with the generated registry and subject PID path, and obtain the usual release
before calling run. No Keychain search list is modified.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

import candidate_config
import candidate_scratch
import guardian

SOURCE = re.compile(r"[0-9a-f]{40}\Z")


def prepare(archive, manifest, template, parent, registry_path):
    with Path(manifest).open(encoding="utf-8") as stream:
        pin = json.load(stream)
    source, digest = pin.get("sourceSHA"), pin.get("sha256")
    if not isinstance(source, str) or not SOURCE.fullmatch(source):
        raise ValueError("manifest needs full sourceSHA")
    candidate_config.verify_archive(archive, digest)
    with Path(template).open(encoding="utf-8") as stream:
        config = json.load(stream)
    if config.get("profile") != "synthetic" or config.get("launchMode", "direct") != "direct":
        raise ValueError("direct synthetic launch template required")
    for key in ("leasePath", "releasePath", "stopPath", "subjectPidPath", "candidateCleanupReceipt"):
        if not isinstance(config.get(key), str) or not Path(config[key]).is_absolute():
            raise ValueError(key + " must be an absolute local path")
    expected = config.get("expectedLease") or {}
    run_id, epoch = expected.get("runID"), expected.get("epoch")
    if not run_id or not epoch:
        raise ValueError("template expectedLease needs runID and epoch")
    registry = candidate_scratch.create(parent, run_id, epoch)
    root = Path(registry["root"])
    try:
        config.update(subjectKind="app-zip", launchMode="direct", argv=[str(Path(archive).resolve())],
                      binarySHA256=digest, syntheticHome=str(root / "home"), syntheticTmp=str(root / "tmp"))
        config_path = root / "launch.json"
        with config_path.open("x", encoding="utf-8") as stream:
            json.dump(config, stream, sort_keys=True)
        record = {"registry": registry, "sourceSHA": source, "packageSHA256": digest,
                  "launchConfig": str(config_path), "stopPath": config["stopPath"],
                  "candidateCleanupReceipt": config["candidateCleanupReceipt"]}
        fd = os.open(registry_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(record, stream, sort_keys=True); stream.flush(); os.fsync(stream.fileno())
        return record
    except BaseException:
        candidate_scratch.cleanup(registry, parent=parent, run_id=run_id, epoch=epoch, subject_closed=True)
        raise


def run(record, receipt_path, *, runner=subprocess.run, clock=time.time, wait=time.sleep):
    started = clock(); status = None; failure = None
    try:
        config_path = Path(record["launchConfig"])
        with config_path.open(encoding="utf-8") as stream:
            config = json.load(stream)
        if config.get("binarySHA256") != record.get("packageSHA256"):
            raise ValueError("candidate hash identity changed")
        candidate_config.verify_archive(config["argv"][0], record["packageSHA256"])
        result = runner([sys.executable, str(Path(__file__).with_name("launch.py")), "--config", str(config_path), "--execute"], check=False)
        status = result.returncode
    except BaseException as error:
        failure = type(error).__name__
    finally:
        try:
            guardian.stop(Path(record["stopPath"]), "candidate-launch-ended", clock())
        except OSError:
            failure = failure or "StopFileError"
    cleanup_path = Path(record["candidateCleanupReceipt"])
    deadline = clock() + 30
    while not cleanup_path.exists() and clock() < deadline:
        wait(0.1)
    try:
        cleanup = json.loads(cleanup_path.read_text())
    except (OSError, ValueError):
        cleanup = None
    registry = record["registry"]
    cleaned = (isinstance(cleanup, dict) and cleanup.get("cleaned") is True
               and cleanup.get("runID") == registry["runID"] and cleanup.get("epoch") == registry["epoch"]
               and not Path(registry["root"]).exists())
    receipt = {"sourceSHA": record["sourceSHA"], "packageSHA256": record["packageSHA256"],
               "startedAt": started, "stoppedAt": clock(), "launchExit": status, "cleaned": cleaned,
               "error": failure}
    with Path(receipt_path).open("x", encoding="utf-8") as stream:
        json.dump(receipt, stream, sort_keys=True)
    if not cleaned:
        raise RuntimeError("cleanup unconfirmed; booking must remain held")
    if failure is not None or status not in (0, 3):
        raise RuntimeError("candidate launch failed; inspect receipt")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    prep = sub.add_parser("prepare")
    for flag in ("archive", "manifest", "template", "scratch-parent", "registry"):
        prep.add_argument("--" + flag, required=True)
    execute = sub.add_parser("run")
    execute.add_argument("--registry", required=True); execute.add_argument("--receipt", required=True)
    args = parser.parse_args()
    if args.action == "prepare":
        result = prepare(args.archive, args.manifest, args.template, args.scratch_parent, args.registry)
    else:
        with Path(args.registry).open(encoding="utf-8") as stream:
            result = run(json.load(stream), args.receipt)
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
