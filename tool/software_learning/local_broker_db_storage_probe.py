"""Disposable local-only real DB-lock + Supabase Storage broker race probe.

NO hosted URLs, Auth keys, user files or production database calls are allowed.
This uses the real PostgreSQL private broker RPCs and loopback Storage API,
not the real Auth HTTP gateway, learner UX, deployment topology or scheduler.
It confirms the trusted broker is the *sole writer* for a synthetic attempt
while a competing PostgreSQL transaction is rejected by NOWAIT. It does NOT
prove raw provider-wide concurrent create-only exclusivity or late writes.
"""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from threading import Event, Lock
from urllib.parse import urlsplit
from uuid import uuid4

from local_storage_race_probe import _fixture, _local_config, _request, BUCKET

# Only used inside GitHub's disposable local Supabase job.
import psycopg

from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from software_learning.brokered_upload import accept_workbook
from software_learning.private_assessment import VerifiedIdentity
from software_learning.private_upload_db import DbApiUploadRepository
from software_learning.private_retention_db import DbApiRetentionRepository
from software_learning.storage_retention import erase_owned_attempt


def _local_db_url() -> str:
    value = os.environ.get("DB_URL", "")
    parsed = urlsplit(value)
    if (parsed.scheme not in ("postgres", "postgresql")
        or parsed.hostname not in ("127.0.0.1", "localhost")
        or parsed.port is None or parsed.path != "/postgres"
        or parsed.username != "postgres" or parsed.query or parsed.fragment):
        raise RuntimeError("Broker probe requires a disposable loopback DB")
    return value


class LocalObjects:
    def __init__(self, api: str, key: str, database: str):
        self._api, self._key, self._db = api, key, database
        self._guard = Lock()
        self.create_calls = 0
        self.stat_statuses: list[int] = []
        self.entered = Event()
        self.release = Event()

    def stat(self, bucket: str, path: str) -> str | None:
        if bucket != BUCKET:
            raise RuntimeError("Unexpected private bucket")
        status, body = _request(self._api, self._key, "GET", path, info=True)
        with self._guard:
            self.stat_statuses.append(status)
        if status == 404:
            return None
        if status != 200:
            raise RuntimeError("Cannot inspect synthetic object")
        meta = json.loads(body)
        if (not isinstance(meta, dict) or meta.get("name") != path
            or meta.get("bucket_id") != bucket):
            raise RuntimeError("Invalid Storage metadata")
        revision = meta.get("version")
        if not isinstance(revision, str) or not 1 <= len(revision) <= 256:
            raise RuntimeError("Invalid Storage revision")
        return revision

    def create_only(self, bucket: str, path: str, blob: bytes) -> None:
        if bucket != BUCKET:
            raise RuntimeError("Unexpected private bucket")
        with self._guard:
            self.create_calls += 1
            count = self.create_calls
        if count == 1:
            # DB row lock is held. Competing NOWAIT admission MUST reject
            # before this synthetic object POST has even started.
            self.entered.set()
            if not self.release.wait(timeout=15):
                raise RuntimeError("Timed-out local race gate")
        status, _ = _request(self._api, self._key, "POST", path, blob)
        if status not in (200, 201):
            raise RuntimeError("Synthetic upload failed")

    def download_limited(self, bucket: str, path: str, limit: int) -> bytes:
        if bucket != BUCKET:
            raise RuntimeError("Unexpected private bucket")
        status, data = _request(self._api, self._key, "GET", path)
        if status != 200 or len(data) > limit:
            raise RuntimeError("Synthetic readback failed")
        return data

    def exists(self, bucket: str, path: str) -> bool:
        if bucket != BUCKET:
            raise RuntimeError("Unexpected private bucket")
        # The local provider can return HTTP 400 for a missing object after
        # deletion. Never classify arbitrary 400 responses as absent. Only
        # after an acknowledged Storage DELETE, use an independent privileged
        # read of the *local* storage.objects metadata for absence. This is
        # a disposable CI diagnostic, not the hosted retention adapter.
        http_status, _ = _request(self._api, self._key, "GET", path)
        if http_status == 200:
            return True
        if http_status not in (400, 404):
            raise RuntimeError("Unexpected synthetic Storage read status")
        with _connect(self._db, service=False) as conn:
            found = conn.execute(
                "SELECT EXISTS(SELECT 1 FROM storage.objects "
                "WHERE bucket_id=%s AND name=%s)",
                (bucket, path),
            ).fetchone()
        if (not isinstance(found, tuple) or len(found) != 1
            or type(found[0]) is not bool):
            raise RuntimeError("Untrusted local Storage metadata check")
        return found[0]

    def remove(self, bucket: str, path: str) -> None:
        if bucket != BUCKET:
            raise RuntimeError("Unexpected private bucket")
        status, _ = _request(self._api, self._key, "DELETE", path)
        if status not in (200, 204, 404):
            raise RuntimeError("Synthetic Storage deletion failed")


class LocalIdentity:
    """Synthetic fixed identity. Does NOT replace hosted JWT verification."""
    def __init__(self, owner: str, session: str):
        self.principal = VerifiedIdentity(owner, session, permanent=True)

    def verify(self, bearer_token: str) -> VerifiedIdentity:
        if bearer_token != "local-synthetic-bearer":
            raise ValueError("Invalid synthetic bearer")
        return self.principal


def _connect(db: str, *, service: bool):
    conn = psycopg.connect(db, autocommit=False, connect_timeout=5)
    if service:
        try:
            conn.execute("SET ROLE service_role")
            conn.commit()
        except Exception:
            conn.close()
            raise
    return conn


def run() -> None:
    api, key, _anon = _local_config()
    database = _local_db_url()
    owner, session, attempt = (str(uuid4()) for _ in range(3))
    path = f"{owner}/{attempt}/workbook.xlsx"
    first, second = _fixture(1), _fixture(2)
    objects = LocalObjects(api, key, database)
    gateway = LocalIdentity(owner, session)
    prepared = False

    def broker(blob: bytes, attempted: Event | None = None):
        conn = _connect(database, service=True)
        try:
            class Attempt(DbApiUploadRepository):
                def begin(self, *args, **kwargs):
                    if attempted is not None:
                        attempted.set()
                    return super().begin(*args, **kwargs)
            return accept_workbook(
                bearer_token="local-synthetic-bearer",
                attempt_id=attempt, blob=blob,
                now=datetime.now(timezone.utc),
                sessions=gateway, repository=Attempt(conn),
                storage=objects,
            )
        finally:
            conn.close()

    try:
        with _connect(database, service=False) as conn:
            conn.execute("INSERT INTO auth.users(id,email) VALUES (%s,%s)",
                         (owner, f"{owner}@broker-local.invalid"))
            conn.execute("INSERT INTO auth.sessions(id,user_id) VALUES (%s,%s)",
                         (session, owner))
            conn.execute(
                "INSERT INTO public.software_learning_attempts "
                "(id,owner_id,issued_session_id,issued_at,expires_at) "
                "VALUES (%s,%s,%s,now(),now()+interval '45 minutes')",
                (attempt, owner, session),
            )
        prepared = True
        # Independently verify the private service-role RPC is eligible
        # before attributing any rejection to the Storage provider.
        try:
            with _connect(database, service=True) as probe_conn:
                row = probe_conn.execute(
                    "SELECT software_learning_private.sl_lock_excel_upload(%s,%s,%s)",
                    (attempt, owner, session),
                ).fetchone()
                if row is None or row[0] is None:
                    raise AssertionError("Synthetic DB broker permit was denied")
                probe_conn.rollback()
        except AssertionError:
            raise
        except Exception:
            raise AssertionError("Synthetic DB broker RPC preflight unavailable") from None

        competed = Event()
        with ThreadPoolExecutor(max_workers=2) as pool:
            writer = pool.submit(broker, first)
            if not objects.entered.wait(timeout=10):
                # Status codes only; never expose private response bodies,
                # workbook paths, secret keys or session identifiers.
                finished = writer.done()
                summary = writer.result(timeout=1).get("status") if finished else "running"
                raise AssertionError(
                    "First broker stopped before Storage write; "
                    f"broker_status={summary}; info_http_statuses={objects.stat_statuses}"
                )
            rival = pool.submit(broker, second, competed)
            if not competed.wait(timeout=10):
                raise AssertionError("Competing broker did not attempt row lock")
            try:
                rejected = rival.result(timeout=10)
            finally:
                objects.release.set()
            accepted = writer.result(timeout=15)

        if (accepted.get("status") != "accepted"
            or rejected.get("status") != "rejected"
            or accepted.get("evidence_trust") != "unverified_checker_only"
            or objects.create_calls != 1):
            raise AssertionError("Real DB lock failed to prevent dual broker writes")

        with _connect(database, service=False) as conn:
            row = conn.execute(
                "SELECT upload_sha256,upload_object_version,upload_enabled "
                "FROM public.software_learning_attempts WHERE id=%s",
                (attempt,),
            ).fetchone()
        if (row is None or row[0] != sha256(first).hexdigest()
            or not isinstance(row[1], str) or row[2] is not True
            or objects.download_limited(BUCKET, path, len(first)+1) != first):
            raise AssertionError("Sealed DB digest and Storage bytes diverged")

        replay = broker(second)
        if replay.get("status") != "rejected" or objects.create_calls != 1:
            raise AssertionError("Committed workbook accepted replay")

        retention = _connect(database, service=True)
        try:
            status = erase_owned_attempt(
                owner_id=owner, attempt_id=attempt,
                repository=DbApiRetentionRepository(retention),
                storage=objects,
            )
            if status != "erased":
                raise AssertionError("Storage-first local retention did not complete")
        finally:
            retention.close()

        with _connect(database, service=False) as conn:
            still_present = conn.execute(
                "SELECT 1 FROM public.software_learning_attempts WHERE id=%s",
                (attempt,),
            ).fetchone()
        if still_present is not None or objects.exists(BUCKET, path):
            raise AssertionError("Synthetic account workbook was not erased")
    finally:
        objects.release.set()
        # Never perform production cleanup. Both endpoints are loopback-only.
        if prepared:
            try:
                objects.remove(BUCKET, path)
            except Exception:
                pass
        with _connect(database, service=False) as conn:
            conn.execute(
                "DELETE FROM public.software_learning_attempts WHERE id=%s", (attempt,)
            )
            conn.execute("DELETE FROM auth.sessions WHERE id=%s", (session,))
            conn.execute("DELETE FROM auth.users WHERE id=%s", (owner,))
    print("Local DB NOWAIT broker, sealed readback, replay and Storage-first cleanup passed")


if __name__ == "__main__":
    run()
