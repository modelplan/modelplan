# SPDX-License-Identifier: MIT
"""Fail-closed orchestration for a future packaged-candidate V-01 run.

The default ports refuse to launch. Isolation and capture are owned by separate
work in progress; this module is not an alternate GUI launcher or an admission
authority. Synthetic port tests exercise ordering and recovery only.
"""
import re
from pathlib import Path

import admission
import candidate_config
import guardian as guardian_module

SOURCE_SHA = re.compile(r"[0-9a-f]{40}\Z")


class RefusingPorts:
    """No default route can admit or launch a subject."""

    def isolation(self, config):
        raise RuntimeError("candidate isolation interface unavailable")

    def admit(self, config, isolation):
        raise RuntimeError("candidate booking admission unavailable")

    def start_guardian(self, config, admission):
        raise RuntimeError("candidate guardian integration unavailable")

    def launch(self, config, isolation, admission, guardian):
        raise RuntimeError("candidate launcher integration unavailable")

    def capture(self, config, subject):
        raise RuntimeError("candidate window capture interface unavailable")

    def close(self, config, subject, guardian):
        raise RuntimeError("candidate independent recovery unavailable")

    def cleanup(self, config, closure):
        raise RuntimeError("candidate cleanup integration unavailable")

    def finish_booking(self, config, admission, cleanup):
        raise RuntimeError("candidate booking finish unavailable")


class ExistingAdmissionPorts(RefusingPorts):
    """Reuse admission and the existing external guardian; other ports refuse.

    Isolation must be supplied by the M3 integration before these methods can
    be reached. No launcher is started by this class.
    """

    def admit(self, config, isolation):
        run_config = config.get("runConfig")
        if not isinstance(run_config, dict):
            raise ValueError("existing launch runConfig required")
        argv = run_config.get("argv")
        booking = run_config.get("booking")
        if (run_config.get("subjectKind") != "app-zip" or run_config.get("launchMode") != "direct"
                or run_config.get("binarySHA256") != config.get("archiveSHA256")
                or not isinstance(argv, list) or not argv or not isinstance(argv[0], str)
                or Path(argv[0]).resolve() != Path(config["archive"]).resolve()
                or not isinstance(booking, dict) or booking.get("scenario") != "V-01"):
            raise ValueError("candidate and V-01 booking must match the existing direct launch config")
        admitted = admission.load_and_admit(run_config)
        return {"admitted": True, "runConfig": admitted}

    def start_guardian(self, config, admission_result):
        expected = config.get("guardianIdentity")
        keys = ("pid", "startSeconds", "startMicroseconds")
        if not isinstance(expected, dict) or any(type(expected.get(k)) is not int for k in keys) or expected["pid"] <= 0:
            raise ValueError("recorded guardian identity required")
        actual = guardian_module.identity(expected["pid"])
        if not isinstance(actual, dict) or any(actual.get(k) != expected[k] for k in keys):
            raise ValueError("existing guardian identity is not live")
        return dict(expected)


def run(config, ports=None):
    """Execute V-01 with injected ports; never finish a booking on unknown cleanup.

    `close` must independently close and scan the owned scope even when guardian
    stopped unexpectedly. It must not silently manufacture a clean receipt.
    The caller persists the returned receipt outside disposable scratch.
    """
    if not isinstance(config, dict) or not SOURCE_SHA.fullmatch(config.get("sourceSHA", "")):
        raise ValueError("full source SHA required")
    archive = config.get("archive")
    digest = config.get("archiveSHA256")
    if not isinstance(archive, str) or not archive:
        raise ValueError("local candidate archive required")
    candidate_config.verify_archive(archive, digest)
    ports = ports or ExistingAdmissionPorts()
    admission = guardian = subject = None
    capture = closure = cleanup = None
    errors = []
    phase = "isolation"
    try:
        isolation = ports.isolation(config)
        if not isinstance(isolation, dict) or isolation.get("enforced") is not True:
            raise RuntimeError("isolation verdict not enforced")
        phase = "booking"
        admitted = ports.admit(config, isolation)
        if not isinstance(admitted, dict) or admitted.get("admitted") is not True:
            raise RuntimeError("booking not admitted")
        admission = admitted
        phase = "guardian"
        guardian = ports.start_guardian(config, admission)
        if guardian is None:
            raise RuntimeError("guardian not started")
        phase = "launch"
        subject = ports.launch(config, isolation, admission, guardian)
        if subject is None:
            raise RuntimeError("subject not registered")
        phase = "capture"
        capture = ports.capture(config, subject)
        if not isinstance(capture, dict) or capture.get("scenario") != "V-01" or capture.get("complete") is not True:
            raise RuntimeError("candidate-owned V-01 capture incomplete")
    except Exception as error:
        errors.append({"phase": phase, "error": str(error) or type(error).__name__})
    finally:
        if admission is not None:
            try:
                closure = ports.close(config, subject, guardian)
                if not isinstance(closure, dict) or closure.get("closed") is not True or closure.get("scopeEmpty") is not True:
                    raise RuntimeError("subject closure unconfirmed")
                cleanup = ports.cleanup(config, closure)
                if not isinstance(cleanup, dict) or cleanup.get("cleaned") is not True:
                    raise RuntimeError("candidate cleanup unconfirmed")
                ports.finish_booking(config, admission, cleanup)
            except Exception as error:
                errors.append({"phase": "teardown", "error": str(error) or type(error).__name__})
    return {"sourceSHA": config["sourceSHA"], "candidateSHA256": digest, "scenario": "V-01",
            "outcome": "pass" if not errors and capture is not None else "not-run", "capture": capture,
            "closure": closure, "cleanup": cleanup, "errors": errors}
