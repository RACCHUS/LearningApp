# EXM-02B Reference-Practice Export — Final Acceptance Matrix

**Status:** Draft engineering acceptance plan. None of these checks authorize deployment,
hosted migrations, publishing exam content, or touching real production learner data.

This scope covers only owner-owned saved EXM R1–R4 steps and derived server grades.
It is not whole-account portability or a currently approved exam book list.

## Automated verification (one final CI run)

- Flutter analysis, all unit/widget tests, web release build
- Latest-main migration governance, incremental upgrade, clean installation,
  complete pgTAP and official taxonomy ingestion/integrity
- 5,001-event database owner/guest tests and grade-change digest detection
- 50,000 synthetic steps through the same allowlisted serializer with UTF-8,
  <=64 KiB byte parts, <=64 MiB total, and recorded elapsed time
- Service/UI tests for cancellation after a page, before initial inventory,
  and after an in-flight request finishes
- Browser request abstraction: explicit user confirmation, proper UTC filename,
  wrong-owner/stale payload refusal, cancelled dialog, failure reporting
- Fallback behavior where browser download is not available

## Manual browser checks (deferred until developer/user testing)

Run against **synthetic non-production accounts and fixtures**. Do not place
publisher-only keys or copyrighted book pages into export material.

| Scenario | Expected behavior |
|---|---|
| Chrome desktop, 1–5,000 events | Atomic one-statement export; confirm browser JSON request; file contains exact event count |
| Chrome desktop, 5,001 and 50,000 events | 250-row RPC paging, visible loaded/total progress, verified pre/post digest, chunked JSON file request |
| Safari, Firefox, Edge | Save/request UX observed; browsers may prompt, save or deny; never claim saved without evidence |
| Empty account | Valid 0-event export or no private step data; no fabricated grades |
| Simulated concurrent insert, delete, or new grade | Export preparation fails its inventory consistency check; no file enabled |
| Cancel immediately or while one RPC is in flight | Stop requesting further pages; no partial data becomes downloadable |
| Cross-account switch during prepare/confirm | Prior owner's old dialog never triggers download |
| Guest and signed-out account | Export controls hidden, no persistent owner RPC |
| Unicode and escaped characters | Download file is UTF-8 JSON; re-import in local JSON viewer and compare record_count |
| 64 MiB output limit exceeded | No download request and a visible error; existing prior data stays unchanged |
| User rejects second download confirmation | Browser receives no file request |
| Browser refuses download or user cancels OS save | UI says *requested* at most; it never asserts file was saved |
| Large clipboard alternative | Clearly disclose privacy and potential browser size limitations |
| Retired book edition | Historical evidence exported, without claiming edition still accepted |
| No service-role access | No raw answer token, reviewer evidence, scoring rubric, private reference text in JSON |

### Acceptance boundaries requiring human decisions

- Cross-browser real-download success and large-memory benchmarks require actual devices.
- Desktop/mobile platform projects are not currently checked into this repository,
  so native save dialogs are **not implemented or validated**.
- No account-wide archive, backup/log erasure, age-based retention schedule, or
  legally sufficient deletion guarantee has been approved.
- Official exam material, independent editorial review and external pilot gates
  remain unchanged by successful export tests.
- Never merge overlapping focused/integration PRs independently. Re-run CI on
  the latest final `main` once the user separately approves merge/release.
