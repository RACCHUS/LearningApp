"""Draft shared activity evidence representation — never a trusted ledger write.

Excel file checking and the current in-memory simulation preview have one
shape, but neither can assert verified mastery or mutate skill progression.
This is an adapter contract to reconcile with the existing record_events,
EXM assessment and user_skill_stats projections BEFORE implementing writes.
"""
from __future__ import annotations

import re
from uuid import UUID

_SLUG = re.compile(r"\A[a-z][a-z0-9]*(?:-[a-z0-9]+)*\Z")
_SHA = re.compile(r"\A[a-f0-9]{64}\Z")
# Pilot skill is application-neutral; future growth must consult the existing
# canonical skills registry instead of extending a second skill taxonomy.
_PILOT_SHARED_SKILL = "spreadsheet-range-summation"


def _uuid(value: object) -> bool:
    if not isinstance(value, str):
        return False
    try:
        return str(UUID(value)) == value
    except (TypeError, ValueError, AttributeError):
        return False


def prepare_activity_evidence(
    *, source_kind: str, activity_id: str, activity_version: int,
    attempt_id: str | None, owner_id: str | None,
    skill_slug: str | None, result: str, assistance_mode: str,
    artifact_digest: str | None,
) -> dict[str, object]:
    """Prepare an unverified, nonpersistent result; no skill awards.

    In-memory preview events do not prove user identity, score, skill mastery,
    or learner independence. File results require a bound owner/attempt and
    digest, but may only report whether the checked workbook met the rubric,
    not who independently created it.
    """
    if (source_kind not in ("simulation_preview", "file_assessment") or
        not isinstance(activity_id, str) or not 1 <= len(activity_id) <= 96 or
        _SLUG.fullmatch(activity_id) is None or
        type(activity_version) is not int or not 1 <= activity_version <= 99 or
        assistance_mode not in ("independent", "hinted", "guided")):
        raise ValueError("Invalid activity evidence metadata")

    if source_kind == "simulation_preview":
        if (owner_id is not None or attempt_id is not None or
            artifact_digest is not None or skill_slug is not None or
            result not in ("completed", "terminated", "failed")):
            raise ValueError("Preview cannot claim learner or verified evidence")
    else:
        if (not _uuid(owner_id) or not _uuid(attempt_id) or
            not isinstance(artifact_digest, str) or
            _SHA.fullmatch(artifact_digest) is None or
            skill_slug != _PILOT_SHARED_SKILL or
            result not in ("pass", "fail", "inconclusive")):
            raise ValueError("Invalid workbook evidence")
    return {
        "schema_version": 1,
        "source_kind": source_kind,
        "activity_id": activity_id,
        "activity_version": activity_version,
        "owner_id": owner_id,
        "attempt_id": attempt_id,
        "skill_slug": skill_slug,
        "result": result,
        "assistance_mode": assistance_mode,
        "artifact_digest": artifact_digest,
        "trust": "unverified",
        "can_award_skill": False,
    }
