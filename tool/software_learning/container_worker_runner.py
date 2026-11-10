"""Pinned, resource-limited Docker transport for the isolated XLSX parser.

Trusted backend use ONLY. Never accept image references, command arguments or
Docker host configuration from a learner. This is not a hosted service or a
privilege boundary against a compromised host/container runtime.
"""
from __future__ import annotations

import json
import re
import subprocess
from typing import Callable, Mapping

from .xlsx_snapshot import MAX_UPLOAD_BYTES

_IMAGE = re.compile(r"\A[a-z0-9][a-z0-9./_-]{0,127}@sha256:[0-9a-f]{64}\Z")
_MAX_STDOUT_BYTES = 16 * 1024
_TIMEOUT_SECONDS = 10


class WorkerFailure(RuntimeError):
    """Redacted worker failure, safe to expose without input details."""


class DockerXlsxWorker:
    """Single-use, no-network worker. Never shares credentials or mounts."""

    def __init__(self, image: str, *, execute: Callable | None = None) -> None:
        if not isinstance(image, str) or _IMAGE.fullmatch(image) is None:
            raise ValueError("A trusted SHA256-pinned worker image is required")
        self._image = image
        self._execute = execute if execute is not None else subprocess.run

    def parse(self, blob: bytes) -> Mapping[str, object]:
        if not isinstance(blob, bytes) or not blob or len(blob) > MAX_UPLOAD_BYTES:
            raise WorkerFailure("Invalid workbook input")

        # Docker CLI is invoked with a fixed binary and an argument vector.
        # Only a trusted, digest-pinned image is accepted. The host must keep
        # Docker socket access entirely outside client-request reach.
        cmd = [
            "/usr/bin/docker", "run", "--rm", "-i", "--pull=never",
            "--network=none", "--ipc=none", "--read-only",
            "--user=65532:65532", "--cap-drop=ALL",
            "--security-opt=no-new-privileges",
            "--pids-limit=32", "--memory=128m", "--cpus=0.5",
            "--ulimit=nofile=64:64", "--ulimit=fsize=10485760:10485760",
            "--tmpfs=/tmp:rw,nosuid,noexec,size=8m",
            self._image, "budget.xlsx",
        ]
        try:
            completed = self._execute(
                cmd, input=blob, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, timeout=_TIMEOUT_SECONDS,
                check=False,
                env={"PATH": "/usr/bin:/bin", "HOME": "/nonexistent",
                     "DOCKER_CONFIG": "/nonexistent"},
            )
        except Exception:
            # Do not leak subprocess arguments, image paths, stderr,
            # workbook bytes, environment, or private exception messages.
            raise WorkerFailure("Workbook processing unavailable") from None

        if (completed.returncode != 0 or
            not isinstance(completed.stdout, bytes) or
            len(completed.stdout) > _MAX_STDOUT_BYTES):
            raise WorkerFailure("Workbook processing unavailable")

        try:
            value = json.loads(completed.stdout.decode("utf-8", errors="strict"))
        except (ValueError, UnicodeDecodeError):
            raise WorkerFailure("Workbook processing unavailable") from None

        if (not isinstance(value, dict) or
            value.get("status") != "parsed_unverified" or
            value.get("evidence_trust") != "unverified_checker_only" or
            value.get("can_award_skill") is not False):
            raise WorkerFailure("Workbook processing unavailable")
        return value
