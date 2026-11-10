"""Safety tests for the pinned-image, sandbox-only XLSX Docker runner."""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
from software_learning.container_worker_runner import DockerXlsxWorker, WorkerFailure

IMAGE = "learningapp-xlsx-worker@sha256:" + "a" * 64
GOOD = {
    "status": "parsed_unverified", "sheet": "Budget",
    "cells": {"C10": {"kind": "formula", "value": "=SUM(C2:C9)"}},
    "evidence_trust": "unverified_checker_only", "can_award_skill": False,
}


class FakeExec:
    def __init__(self, output=None, code=0, error=None):
        self.commands = []
        self.output = output if output is not None else json.dumps(GOOD).encode()
        self.code = code
        self.error = error

    def __call__(self, command, **kwargs):
        self.commands.append((command, kwargs))
        if self.error is not None:
            raise self.error
        return subprocess.CompletedProcess(command, self.code, self.output, b"private data should not leak")


class DockerXlsxWorkerTests(unittest.TestCase):
    def test_valid_pinned_image_sandbox_with_bounded_io(self):
        fake = FakeExec()
        runner = DockerXlsxWorker(IMAGE, execute=fake)
        result = runner.parse(b"some workbook bytes")
        self.assertEqual(result, GOOD)
        self.assertEqual(len(fake.commands), 1)
        cmd, kwargs = fake.commands[0]
        self.assertEqual(cmd[0], "/usr/bin/docker")
        self.assertIn("--network=none", cmd)
        self.assertIn("--read-only", cmd)
        self.assertIn("--cap-drop=ALL", cmd)
        self.assertIn("--security-opt=no-new-privileges", cmd)
        self.assertIn("--user=65532:65532", cmd)
        self.assertIn("--memory=128m", cmd)
        self.assertIn("--pids-limit=32", cmd)
        self.assertIn("--cpus=0.5", cmd)
        self.assertIn("--pull=never", cmd)
        self.assertIn("--ipc=none", cmd)
        self.assertIn(IMAGE, cmd)
        self.assertEqual(cmd[-1], "budget.xlsx")
        self.assertEqual(kwargs["input"], b"some workbook bytes")
        self.assertEqual(kwargs["timeout"], 10)
        self.assertFalse(kwargs["check"])
        self.assertNotIn("shell", kwargs)
        self.assertNotIn("DOCKER_HOST", kwargs["env"])
        self.assertEqual(kwargs["env"]["DOCKER_CONFIG"], "/nonexistent")

    def test_rejects_unpinned_image_and_command_injection(self):
        for image in ("learningapp:latest", "image@sha256:abc",
                      "x@sha256:" + "F" * 64, IMAGE + ";rm -rf /",
                      "docker.io/example/worker:latest", "",
                      "example.com/foo@sha256:" + "a" * 64 + " ",
                      "invalid image@sha256:" + "a" * 64):
            with self.subTest(image=image):
                with self.assertRaises(ValueError):
                    DockerXlsxWorker(image, execute=FakeExec())

    def test_worker_nonzero_is_rejected_without_stderr_leak(self):
        for code in (1, 2, 125):
            with self.subTest(code=code):
                fake = FakeExec(code=code, output=b"secret")
                with self.assertRaises(WorkerFailure) as cm:
                    DockerXlsxWorker(IMAGE, execute=fake).parse(b"workbook")
                self.assertNotIn("secret", str(cm.exception))

    def test_timeout_fails_closed(self):
        fake = FakeExec(error=subprocess.TimeoutExpired("docker", 10, output=b"private"))
        with self.assertRaises(WorkerFailure) as cm:
            DockerXlsxWorker(IMAGE, execute=fake).parse(b"workbook")
        self.assertNotIn("private", str(cm.exception))

    def test_malformed_or_large_output_fails_closed(self):
        for response in (b"{", b"[]", b"null", b"\xff", b"X" * 16385):
            with self.subTest(response=response[:20]):
                with self.assertRaises(WorkerFailure):
                    DockerXlsxWorker(IMAGE, execute=FakeExec(output=response)).parse(b"workbook")

    def test_worker_rejection_cannot_be_mistaken_for_success(self):
        for value in ({"status": "rejected", "reason": "unsupported_or_unsafe_workbook"},
                      {"status": "parsed_unverified", "evidence_trust": "server_verified",
                       "can_award_skill": True}):
            with self.assertRaises(WorkerFailure):
                DockerXlsxWorker(IMAGE, execute=FakeExec(output=json.dumps(value).encode())).parse(b"workbook")

    def test_oversized_input_rejected_without_subprocess(self):
        fake = FakeExec()
        with self.assertRaises(WorkerFailure):
            DockerXlsxWorker(IMAGE, execute=fake).parse(b"0" * (10*1024*1024+1))
        self.assertEqual(fake.commands, [])


if __name__ == "__main__":
    unittest.main()
