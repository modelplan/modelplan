# SPDX-License-Identifier: MIT
"""Shared-ledger GUI hook for gui-1. Booking never grants a GUI release.

Invoke request, start and finish in separate job steps. A queued request keeps
its ID if start is refused, so the caller can withdraw it rather than abandoning
the FIFO head. Finish requires the existing guardian outcome and an explicit,
run-bound cleanup receipt; unconfirmed teardown keeps the booking held.
"""
import argparse
import json
import os
from pathlib import Path

import book
import guardian


def shared_ledger():
    path = os.environ.get("MODELPLAN_BOOKING_LEDGER")
    if not path or not Path(path).is_absolute():
        raise ValueError("MODELPLAN_BOOKING_LEDGER must name the shared absolute ledger path")
    return book.Ledger(path)


def finish(ledger, booking_id, run_id, epoch, lease, guardian_result, cleanup):
    if not isinstance(lease, dict) or lease.get("runID") != run_id or lease.get("epoch") != epoch:
        raise ValueError("lease identity mismatch")
    if not isinstance(guardian_result, dict) or not guardian.finishable(
        guardian_result.get("guardian"), guardian_result.get("subjectClosed"), guardian_result.get("subject")
    ):
        raise ValueError("guardian did not confirm closure")
    if (not isinstance(cleanup, dict) or cleanup.get("runID") != run_id or cleanup.get("epoch") != epoch
            or cleanup.get("cleaned") is not True):
        raise ValueError("run-bound cleanup confirmation required")
    return ledger.finish(booking_id, "V1", run_id, epoch, cleaned=True)


def load(path):
    with Path(path).open(encoding="utf-8") as stream:
        return json.load(stream)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    request = sub.add_parser("request")
    request.add_argument("--unit", required=True)
    request.add_argument("--scenario", action="append", required=True)
    request.add_argument("--minutes", type=int, default=20)
    for action in ("start", "finish"):
        command = sub.add_parser(action)
        command.add_argument("--id", required=True)
        command.add_argument("--run-id", required=True)
        command.add_argument("--epoch", required=True)
        if action == "finish":
            command.add_argument("--lease", required=True)
            command.add_argument("--guardian-result", required=True)
            command.add_argument("--cleanup-receipt", required=True)
    withdraw = sub.add_parser("withdraw")
    withdraw.add_argument("--id", required=True)
    withdraw.add_argument("--reason", required=True)
    args = parser.parse_args(argv)
    ledger = shared_ledger()
    if args.action == "request":
        result = ledger.request("V1", args.unit, args.scenario, seconds=args.minutes * 60)
    elif args.action == "start":
        result = ledger.start(args.id, "V1", args.run_id, args.epoch)
    elif args.action == "withdraw":
        result = ledger.withdraw(args.id, lane="V1", reason=args.reason)
    else:
        result = finish(ledger, args.id, args.run_id, args.epoch, load(args.lease),
                        load(args.guardian_result), load(args.cleanup_receipt))
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
