# SPDX-License-Identifier: MIT
"""Validate a packaged candidate's identity. This module does not launch it."""
import hashlib
import json
import os
import re
import stat
from pathlib import Path
from urllib.parse import urlsplit

SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def validate_config(config):
    if not isinstance(config, dict):
        raise ValueError("candidate configuration must be an object")
    if set(config) != {"candidate", "sha256", "buildID", "installDir"}:
        raise ValueError("candidate, sha256, buildID and installDir are required")
    source, digest, build_id, install = (config[k] for k in ("candidate", "sha256", "buildID", "installDir"))
    if not isinstance(source, str) or not source.strip():
        raise ValueError("candidate source required")
    url = urlsplit(source)
    if url.scheme:
        if url.scheme != "https" or not url.hostname or url.username or url.password or url.fragment:
            raise ValueError("candidate URL must be credential-free HTTPS")
    elif not Path(source).is_absolute():
        raise ValueError("candidate path must be absolute")
    if not isinstance(digest, str) or not SHA256.fullmatch(digest):
        raise ValueError("sha256 must be 64 lowercase hexadecimal characters")
    if not isinstance(build_id, str) or not build_id.strip() or not build_id.isprintable():
        raise ValueError("buildID required")
    if not isinstance(install, str) or not Path(install).is_absolute():
        raise ValueError("installDir must be absolute")
    destination = Path(install)
    if destination.exists() or destination.is_symlink() or not destination.parent.is_dir():
        raise ValueError("installDir must be a new path beneath an existing directory")
    return dict(config)


def verify_archive(path, expected):
    if not isinstance(expected, str) or not SHA256.fullmatch(expected):
        raise ValueError("invalid sha256")
    archive = Path(path)
    if archive.is_symlink() or not archive.is_file():
        raise ValueError("candidate must be a regular, non-symlink file")
    digest = hashlib.sha256()
    with archive.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != expected:
        raise ValueError("candidate archive sha256 mismatch")
    return digest.hexdigest()


def stage_local_archive(source, destination, expected):
    """Copy one local candidate into a fresh file; reject it before any unzip on mismatch.

    No candidate is launched here. The destination must be inside scratch owned
    by the caller; O_EXCL prevents replacement of an existing file or symlink.
    """
    if not isinstance(expected, str) or not SHA256.fullmatch(expected):
        raise ValueError("invalid sha256")
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    source_fd = os.open(source, flags)
    try:
        if not stat.S_ISREG(os.fstat(source_fd).st_mode):
            raise ValueError("candidate must be a regular file")
        fd = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)
        created = os.fstat(fd)
        try:
            digest = hashlib.sha256()
            with os.fdopen(fd, "wb") as target, os.fdopen(source_fd, "rb", closefd=False) as incoming:
                for block in iter(lambda: incoming.read(1024 * 1024), b""):
                    digest.update(block)
                    target.write(block)
                target.flush()
                os.fsync(target.fileno())
            if digest.hexdigest() != expected:
                raise ValueError("candidate archive sha256 mismatch")
        except BaseException:
            try:
                current = os.lstat(destination)
                if current.st_dev == created.st_dev and current.st_ino == created.st_ino:
                    os.unlink(destination)
            except FileNotFoundError:
                pass
            raise
        return digest.hexdigest()
    finally:
        os.close(source_fd)


def read_config(path):
    with Path(path).open(encoding="utf-8") as stream:
        return validate_config(json.load(stream))
