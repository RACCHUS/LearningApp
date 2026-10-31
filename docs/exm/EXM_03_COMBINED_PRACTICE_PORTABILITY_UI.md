# EXM-03 — Owner-controlled combined practice archive and erasure UI

**Engineering draft only.** No merge, hosted migration, production data write,
automatic deletion or final browser acceptance has occurred.

## Delivered in this milestone

The **All Knowledge > Progress** section now contains an explicitly scoped
“Export or delete all EXM practice history” card for **permanent signed-in
learners only**. Its child widget is keyed by the authenticated account ID,
and the service separately verifies ownership before and after reads/deletion.
Guests see no controls.

- **Preview first:** Server `exm03_account_practice_inventory` must return a
  complete bounded, fingerprinted, owner-matching count of R1–R4 reference
  events/grades and EXM-03 issued assignments/scored attempt summaries.
- **Prepare safely:** Server `exm03_account_practice_export` returns one
  validated snapshot. Its fingerprint and all four counts must match the
  on-screen preview before the interface presents a download action.
  If they differ, both the preview and prepared archive are discarded.
- **Download only on an actual click:** A second dialog explains included
  records, official-result limits, privacy and browser save uncertainty.
  Its final button directly requests the browser file in that click. The
  filename has a distinct `learningapp-exm-combined-practice-...` prefix.
  The existing guarded 64-MiB UTF-8 chunker rejects an oversize archive
  *before* requesting the Blob/download, never claiming that a browser
  saved the file.
- **Delete explicitly:** A fresh preview, exact typed `DELETE ALL EXAM
  PRACTICE` phrase and separate review dialog are all required. The SQL
  transaction checks the fingerprint, erases both private stores and checks
  the absence of attempts and issued assignments. The UI never optimistically
  shows success, and any uncertain network response clears the old preview
  and asks for a fresh inventory.
- **Owner switch:** Current account controls the entire component identity.
  In-flight results, pending confirmation and prepared private JSON for the
  old account are discarded on account change.
- **Boundedness:** Accounts beyond 5,000 reference events or 5,000 part
  assignments are rejected by the combined SQL export/erasure. The UI states
  that these users need a separately verified larger export, and never calls
  an incomplete archive “complete.” The older R1–R4 large exporter remains
  unchanged, but cannot cover new EXM-03 assignments.

This archive is **EXM educational practice only**, not other learner data,
question text, protected correct answers, official scores or full account
history. The pre-existing R1–R4-only controls remain alongside it in
Progress and must not be misrepresented as including EXM-03.

## Tests and remaining gates

Widget tests exercise verified download payload, stale export inventory
blocking, typed and second deletion confirmation, guest account hiding,
and dropping in-flight previews after an account switch. The archive
encoder test verifies chunk output parses equivalently to the validated
JSON and omits secret fields.

Future gates: multi-page combined export beyond 5,000 with snapshot-safe
postflight counts and cancellation; real browser/platform save, logout and
interruption tests; verify prior R1–R4 erasure interactions; connect legacy
diagnostics/mock screen to the approved safe question issuer rather than
direct protected item reads; publisher and exam-edition verification; and
separate explicit merge/deployment approval.
