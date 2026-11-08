"""GitHub CI-only Supabase Storage concurrency probe on loopback Docker services.

Synthetic objects only. Never contacts hosted projects or opens signed URLs.
Proves local-provider create-only / version / RLS / cleanup behavior, not
production immutability, account erasure or broker crash safety.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from hashlib import sha256
from io import BytesIO
import json
import os
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
from uuid import uuid4
from zipfile import ZIP_DEFLATED, ZipFile

BUCKET = "learningapp-excel-private"
MIME = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def _local_config() -> tuple[str, str, str]:
    url = os.environ.get("API_URL", "").rstrip("/")
    u = urlsplit(url)
    if (u.scheme != "http" or u.hostname not in ("127.0.0.1", "localhost")
        or u.username or u.password or u.path not in ("", "/")
        or u.query or u.fragment or not u.port):
        raise RuntimeError("Local Storage probe requires a loopback API")
    service = os.environ.get("SERVICE_ROLE_KEY", "")
    anon = os.environ.get("ANON_KEY", "")
    if not service or not anon:
        raise RuntimeError("Missing local Supabase credentials")
    return url, service, anon


def _request(base: str, key: str, method: str, name: str,
             data: bytes | None = None, *, info: bool = False):
    if method not in ("POST", "GET", "DELETE"):
        raise ValueError("Unsupported probe method")
    endpoint = "object/info" if info else "object"
    req = Request(
        f"{base}/storage/v1/{endpoint}/{BUCKET}/{name}", method=method,
        data=data, headers={
            "apikey": key, "Authorization": f"Bearer {key}",
            "Content-Type": MIME,
            "Accept": "application/json" if info or method != "GET" else MIME,
            "Cache-Control": "no-store",
        },
    )
    try:
        with urlopen(req, timeout=12) as response:
            if response.geturl() != req.full_url:
                raise AssertionError("Unexpected redirect")
            return response.status, response.read(10 * 1024 * 1024 + 1)
    except HTTPError as error:
        # Do not log the response body, object name or credential.
        return error.code, b""


def _fixture(marker: int) -> bytes:
    buf = BytesIO()
    with ZipFile(buf, "w", compression=ZIP_DEFLATED) as archive:
        archive.writestr("synthetic.txt", str(marker).encode("ascii"))
    return buf.getvalue()


def run() -> None:
    base, service, anon = _local_config()
    owner, attempt = uuid4(), uuid4()
    path = f"{owner}/{attempt}/workbook.xlsx"
    other = f"{owner}/{uuid4()}/workbook.xlsx"
    candidates = [_fixture(1), _fixture(2), _fixture(3)]
    try:
        with ThreadPoolExecutor(max_workers=3) as pool:
            outcomes = list(pool.map(
                lambda content: _request(base, service, "POST", path, content),
                candidates,
            ))
        winners = [i for i, (code, _) in enumerate(outcomes)
                   if code in (200, 201)]
        losers = [code for code, _ in outcomes if code not in (200, 201)]
        if (len(winners) != 1 or len(losers) != 2
            or any(code not in (400, 409) for code in losers)):
            raise AssertionError("Local Storage create-only race contract failed; HTTP statuses=" + str([code for code, _ in outcomes]))
        status, readback = _request(base, service, "GET", path)
        if (status != 200 or sha256(readback).digest()
            != sha256(candidates[winners[0]]).digest()):
            raise AssertionError("Local Storage committed bytes changed")
        code, metadata_blob = _request(base, service, "GET", path, info=True)
        if code != 200 or len(metadata_blob) > 16384:
            raise AssertionError("Local Storage object-info request failed")
        try:
            metadata = json.loads(metadata_blob)
            revision = metadata["version"]
            if (metadata["name"] != path or metadata["bucket_id"] != BUCKET
                or metadata["metadata"]["size"] != len(readback)
                or not isinstance(revision, str) or not 1 <= len(revision) <= 256
                or not revision.isascii()):
                raise ValueError("Invalid immutable object revision metadata")
        except Exception:
            raise AssertionError("Local Storage revision contract changed") from None
        conflict, _ = _request(base, service, "POST", path, candidates[0])
        if conflict not in (400, 409):
            raise AssertionError("Existing object accepted a second write")
        denied, _ = _request(base, anon, "POST", other, candidates[0])
        if denied in (200, 201):
            raise AssertionError("Anonymous direct workbook upload accepted")
        removed, _ = _request(base, service, "DELETE", path)
        if removed not in (200, 204):
            raise AssertionError("Storage API could not remove synthetic workbook")
        absent, _ = _request(base, service, "GET", path)
        if absent not in (400, 404):
            raise AssertionError("Deleted workbook is still readable")
        resurrection, _ = _request(base, anon, "POST", path, candidates[0])
        if resurrection in (200, 201):
            raise AssertionError("Anonymous client resurrected deleted workbook")
    finally:
        for name in (path, other):
            try:
                _request(base, service, "DELETE", name)
            except Exception:
                pass
    print("Local Storage race, byte/revision seal, RLS and cleanup passed")


if __name__ == "__main__":
    run()
