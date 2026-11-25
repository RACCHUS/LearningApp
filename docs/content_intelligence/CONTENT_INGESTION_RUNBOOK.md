# Content ingestion from outside sources: runbook

How to take material from an outside source (a textbook, course, official guide or government page) and turn it into LearningApp content without breaking its license. This makes master plan v2.6 §8 (Path B) and §14.3 something you can follow step by step.

- **Source of truth for what we may do:** [`data/content_sources.json`](../../data/content_sources.json).
- **Enforcement:** [`tool/ci/verify_content_sources.py`](../../tool/ci/verify_content_sources.py) runs in CI.
- **Coverage plan:** [`CONTENT_SUPPLY_AND_REUSE_MAP.md`](CONTENT_SUPPLY_AND_REUSE_MAP.md).

> License readings here are the maintainers' reading of published terms, not legal advice. The owner decides what each source may be used for. When unsure, link only.

## Open content comes first in the app

When someone plans a lesson in *Create with your AI chat*, the Reuse Gate searches before any AI is offered. It looks, in this order, at:
1. our lessons
2. our Bridges
3. **sections of approved open textbooks**, from `assets/open_content/index.json`

A match shows "Free open content covers this", with a link to read the section. The learner can still choose *Make my own version* to go on to AI (copy and paste, free AI, or their own key). This is plan §4.3 steps 1–4 before step 6.

**To add a book to the index:**
1. Register it (step 3 below) with at least `link` allowed.
2. Add it to `BOOKS` in `tool/build_open_content_index.py`.
3. Run `python tool/build_open_content_index.py`.

The tool stops if the license the publisher reports differs from the registry. CI validates the committed index offline (`--check`).

## Bringing open textbook sections in as lessons

For approved CC BY books, `tool/import_open_textbook.py` turns whole chapters into a curriculum manifest (`content/open_<source>.yaml`):

```
python tool/import_open_textbook.py --source openstax-college-algebra-1e --chapters 1
```

| From the book | Becomes |
|---|---|
| Section text, subsections, lists, tables | Reading blocks, with math converted from MathML to `$…$` LaTeX |
| Notes ("The Product Rule…") | Call-outs |
| Worked examples | Reading blocks, with their solutions |
| Try It exercises | Practice prompts that reveal the answer from the book's answer key |
| Try It and end-of-section exercises whose answer is a single number | Graded `numeric_entry` questions (server-graded, exact value) |
| Defined terms | Glossary terms, with the book's definitions |
| Images | Not copied (they can carry separate rights); a note points to the original section |
| — | A closing "Source and license" block: book, link, CC BY 4.0, changes, "not reviewed by a person" |

**Built-in safeguards:**
- The tool imports only sources with `adapt` and `redistribute` allowed and status `approved`. Reading blocks stay close to the book's wording, so the manifest declares `use: redistribute` (owner decision D-7, 2026-11-24, for the three CC BY 1st editions).
- It stops if the license the publisher reports differs from the registry.
- It never turns an expression answer such as `(x-6)(x-1)` into a graded question: those stay as practice with the answer to reveal, so a correct but differently written answer is never marked wrong.
- A section with no answer that can be graded automatically is kept as a **teaching-only** lesson: tag `teaching-only`, a "No graded questions yet" note saying it doesn't count toward exam readiness, and its practice prompts with answers to reveal. The linter accepts an objective with no assessment items only when all its lessons carry that tag, and reports it as a warning to review before publishing. A section with nothing to teach is still left out and stays reachable as an open textbook link.

**Then:**
1. Run the step 7 checks; `test/content/open_textbook_math_test.dart` also checks that every formula parses.
2. Review a few lessons.
3. Have the owner ingest them (step 9).

**Freshness (plan §7.1–7.2):** give each manifest a `target.volatility_class`: `V0` timeless (36-month review), `V1` slow (24), `V2` software/UI (9), or `V3` regulated (also set `target.review_by` from the source release). V4 fast-moving content is linked, not authored. The ingestion step records it with the source pin. A daily workflow (`curriculum-freshness.yml`) raises review-due items and compares open-textbook pins with OpenStax's current release; see them at `/admin/freshness`.

**Correcting lessons already published:** published versions cannot change. Fix the importer, bump `IMPORT_REVISION` in `tool/import_open_textbook.py` (the version code becomes `OPENSTAX-<book>-R<n>`), re-run the import, and run the ingestion workflow with `stop_after: published`, `retire_previous: true` and `replace_reason` naming the defect the new revision fixes (for example `IMPORT_REVISION 4: figure captions lost their numbers`). The reason is recorded as the champion/challenger decision (plan §7.3, migration `20261122060000`); the database refuses to retire an official published version without one. The new version replaces the old one in one step, and every decision is listed at `/admin/freshness`. Learners keep their place: lesson progress, placed resources, learning goals, resume points and device-local progress move to the same-title lesson in the new version (migration `20261121000000`). A section dropped from the new version keeps its history on the retired lesson, and its learning goal is archived.

**Pilot (2026-11-20):**
- College Algebra chapter 1: 4 lessons, 27 graded questions. 1.4 Polynomials and 1.5 Factoring were left out because none of their answers is a single number.
- **R4 published to production 2026-11-24** (workflow run 45306386606, owner-approved): 1.4 and 1.5 return as teaching-only lessons (8 practice prompts each, no graded questions); the other four lessons are unchanged. R3 was retired in the same step, with the replace decision "IMPORT_REVISION 4: sections 1.4 and 1.5 kept as teaching-only instead of dropped".
- **Prealgebra R5 and Excel EXCEL-PILOT-2 (published 2026-11-24, runs 45491098303 and 45491354159; R3 and PILOT-1 retired):** lessons unchanged (Excel gains `volatility_class: V2`), plus held-out checks from `content/held_out/open_openstax_prealgebra_1e_ch6.yaml` (30) and `content/held_out/excel_fundamentals.yaml` (6), approved by an independent AI review. Published with the workflow's `held_out` input and `retire_previous: true`; production shows full held-out coverage for both.
- **R5 published to production 2026-11-24** (run 45467496108, owner-approved; R4 retired): lessons identical to R4, plus 36 held-out checks from `content/held_out/open_openstax_college_algebra_1e_ch1.yaml`, approved by an independent AI review (D-16). Publish with the workflow's `held_out` input, `retire_previous: true` and `replace_reason: "IMPORT_REVISION 5: adds 36 independently AI-reviewed held-out checks (D-14, D-16); lessons unchanged"`.
- **R6 (College Algebra, Prealgebra) and EXCEL-PILOT-3 (published 2026-11-24, runs 45512927860, 45513107376 and 45513288592; R5, R5 and PILOT-2 retired):** 49 original practice questions from `content/practice/` (33 College Algebra, 12 Prealgebra, 4 Excel), approved by an independent AI review, bring every objective to at least 10 graded questions (D-14 bank depth). 1.4 and 1.5 are graded lessons again, no longer teaching-only. Lessons are otherwise unchanged. Published with each `held_out` file (held-out checks attach to one version, so they were added again) and `retire_previous: true`. In production every objective has 10 or more graded questions and all 72 held-out approvals match.
- Prealgebra chapter 6 (Percents): 5 lessons, 49 graded questions.
- Both published to production 2026-11-20 through the ingestion workflow; revision R2 fixed figure captions (repeated numbers) and replaced R1.

## The six uses

Every use of a source is one of these. The registry lists which ones each source allows.

| Use | Meaning | Example |
|---|---|---|
| `link` | Link to the source page. No text copied | A companion "Read OpenStax 6.1" link |
| `reference` | Name the source and section as alignment or citation metadata | `citation: OpenStax College Algebra 1e, Section 1.2` |
| `quote` | A short verbatim excerpt (one or two sentences), in quotation marks, with credit | A definition quoted from a public-domain glossary |
| `adapt` | Our own lesson built on the source's text, examples or exercises, with credit and a note of changes | Rewriting a worked example in plainer words |
| `redistribute` | Hosting a verbatim copy of a section or more | Rarely needed; avoid |
| `ai_transform` | Pasting the source's text into an AI chat to produce our content | Asking an AI to turn a CC BY section into practice questions |

## What each license allows

| License | Max uses | Commercial | Our derived lesson must be… |
|---|---|---|---|
| Public domain (U.S. federal work) | all | yes | anything (credit the agency anyway) |
| CC BY 4.0 | all | yes | credited, with changes noted |
| CC BY-SA 4.0 | all | yes | **CC BY-SA 4.0** itself |
| CC BY-NC-SA 4.0 | all, non-commercially | **no** | **CC BY-NC-SA 4.0** and non-commercial |
| Proprietary / all rights reserved | link, reference | no | our own text only, never close paraphrase |
| Unknown | link, reference | no | treated as proprietary until confirmed |

**Non-commercial is an open owner decision.** The sustainability plan includes sponsor placements, affiliate links and donations. Whether LearningApp counts as "non-commercial" with those is not settled, so every CC BY-NC-SA source (current OpenStax 2e books, MIT OCW) stays **link and reference only** until the owner decides.

**Share-alike is contagious.** A lesson adapted from a CC BY-SA or CC BY-NC-SA source must carry that same license. Our content files have no license field yet. Until they do, do not adapt share-alike sources.

**Trademarks are separate.** Names and logos (OpenStax, Rice University, MIT, Wikibooks, CLEP, CompTIA) are not covered by the content license. Name the source in credits; never use their logos or imply endorsement.

## Step by step

### 1. Find the source
1. Check `data/content_sources.json` first. If the source is there, its `allowed_uses` are already decided. Go to step 4.
2. Prefer, in order:
   - official or primary sources
   - openly licensed textbooks (CC BY first)
   - public-domain government material
   - other reputable sources, as links only
3. Pin the **exact edition**. The license can differ between editions of the same book. OpenStax first editions are CC BY 4.0, but its newer editions are CC BY-NC-SA 4.0 (OpenStax announced the switch on 2026-04-22).

### 2. Confirm the license
1. Open the license statement **on that edition's own pages** (preface, footer, "about" or terms page). A search result or summary isn't enough.
2. Record the exact URL, today's date and the sentence that states the license.
3. Look for extra terms: AI restrictions, non-commercial clauses, trademark notes and "third-party material" exceptions.
4. If no license is stated, the license is `unknown`, and only link and reference are allowed.

### 3. Register the source
Add an entry to `data/content_sources.json` with:
- `id`, `publisher`, `title`
- `url_prefixes`: specific enough to tell editions apart, such as `/books/college-algebra/` vs `/books/college-algebra-2e/`
- `license`, `license_evidence` and an `attribution` template
- `allowed_uses`: start with `["link", "reference"]`
- `status: "proposed"` and `decided_by: null`

Run `python tool/ci/verify_content_sources.py`.

**Owner approval.** Anything beyond link and reference (`quote`, `adapt`, `ai_transform`, `redistribute`) is used only when the owner sets `status: "approved"` and fills in `decided_by` (for example `"owner 2026-11-20"`). CI refuses those uses for unapproved sources.

### 4. Plan what to make
Add or update the target's row in the Content Supply Map:
- which concepts it covers
- which roles the source can fill: Teach, Example, Practice, Check, Bridge, Access
- what stays a gap

Search the catalog first (the Reuse Gate does this for AI-assisted creation) so nothing is duplicated.

### 5. Make the content
Choose the route by the allowed use:

| Allowed use | Where it goes | How |
|---|---|---|
| `link` | `content/companions/*.companion.json` (`rights_posture: "link_only"`), a Bridge `sources` entry, or a lesson link | Write our own focus note and check questions; link to the section |
| `reference` | Manifest `citation` fields and `source_releases` | Align objectives and concepts; write all text ourselves |
| `quote` | Lesson or Bridge text | One or two sentences, in quotation marks, with the attribution template filled in |
| `adapt` | Lesson, Bridge or manifest content | Write the lesson in our voice from the source, fill in the attribution template with a `Changes:` note, and set `rights_posture: "may_adapt"` on the source entry |
| `ai_transform` | Same as adapt | Paste only the needed section into *Create with your AI chat* or another AI chat, then treat the reply as an adapted draft. Never paste proprietary, unknown or non-approved text. Free AI tiers may train on what you paste, so check the AI provider's terms too |

**Writing rules for every route:**
- Use our own sentences and examples.
- Keep numbers and facts traceable to the cited section.
- Don't copy exercises from proprietary exam guides.
- For Bridges, check items must use the allowlisted templates and numbers that don't appear in the worked examples (see `content/bridges/README.md`).

### 6. Show the credit
- **Bridges and companions** list their sources in the file, and the app shows them.
- **Adapted lessons** keep the filled-in attribution in the lesson's citation, plus a visible credits line.
- Format: *title, author or publisher, link to the section, license name and link, "Changes: …"*.

### 7. Check it
Run whichever apply:
- `python tool/ci/verify_content_sources.py`: sources registered, uses allowed, licenses stated correctly, and manifest pins real. A `sha256` must be computed from a copy you actually retrieved. If you have no such copy, leave `sha256` out and set `metadata.checksum_status: unverified_remote_document` with a `checksum_verification_note`. The checker rejects placeholders: repeated patterns, digests of common words, and values that share a long run with another source's pin.
- `flutter test test/models/bridge_lesson_test.dart`: Bridge rules and recomputed check answers
- `dart run tool/lint_manifest.dart --dir content/` and `dart run tool/ingest_curriculum.dart --dir content/ --dry-run`: manifests
- `"$CI_TEST_PYTHON" tool/clep_content_pipeline.py --manifest content/<file>.yaml --require-simulation`: CLEP manifests

### 8. Label honestly
- `evidence.human_reviewed` stays `false` until a named person has actually reviewed the content.
- "Source-attributed", "checked against the source", "deterministically checked" and "reviewed by a person" are separate claims (plan §14.0A). Make only the ones that are true.

### 9. Publish
| Content | How it reaches learners |
|---|---|
| Bridges and companions | Bundled with the app: add to `pubspec.yaml` and to `BridgeLibrary.assetPaths` / `ExternalCompanionLibrary.assetPaths`, merge, build and deploy |
| Curriculum manifests (`content/*.yaml`) | **Owner only:** the *Controlled curriculum ingestion* GitHub workflow (`.github/workflows/controlled-curriculum-ingestion.yml`). Run it from Actions on `main`, give the manifest path, choose how far to go (`dry-run`, `draft`, `review-ready`, `published`) and type the project ref; the run waits for your approval in the `supabase-production-deployment` environment. It reads target and version from the manifest, checks source licenses, dry-runs, then calls `tool/ingest_curriculum.dart` `--apply`, `--stage-review` and `--publish` with the repository secrets. The same commands still work locally with the key in your shell. |
| Learner or community lessons | The public contribution flow (`content.public_contribution`), labelled unreviewed |

**Production status (2026-11-20):** the seven **authored** curriculum manifests (adult literacy, BS Computer Science, CLEP College Algebra, CLEP Introductory Psychology, Excel, Security+, Software Engineer career) pass the dry run, but none has been ingested into production. The two **open-textbook** manifests (`open_openstax_college_algebra_1e.yaml`, `open_openstax_prealgebra_1e.yaml`) were published on 2026-11-20 (see "Pilot" above). Ingestion order, per decision D-13 of the [ingestion plan](../../LEARNINGAPP_DEMAND_DRIVEN_CONTENT_INGESTION_PLAN_V1_2_2026-11-23.md): Excel first: **published to production 2026-11-24** (`EXCEL-PILOT-1`, run 45324101664, owner-approved; 1 lesson, 6 practice questions, 5 flashcards). An earlier run, 45313227200, was rejected atomically because the simulation block had `fallback_body` instead of the required `body`, so it wrote nothing; the linter now checks this. The manifest has no `target.volatility_class`, so no review-by date is set. Add `V2` (software, 9-month review) in its next version, then CLEP College Algebra once it is reconciled with the imported textbook lessons; the other five wait.

### Held-out checks (readiness)
Readiness is shown only when held-out checks cover enough of a target (plan D-14). Write them in `content/held_out/<manifest>.yaml`, originals only and never lesson practice, then run `python tool/verify_held_out_items.py`. An independent reviewer, either an AI that didn't write the items (named model, checklist, its own SymPy check) or a person, approves each item by adding a `review` block with `reviewer_kind` (decision D-16). Ingest approved items into a draft version with the workflow's `held_out` input. See [HELD_OUT_CHECKS_DESIGN.md](HELD_OUT_CHECKS_DESIGN.md).

### Importer adapter, fixtures and loss report
`tool/import_open_textbook.py` is the `openstax-archive` adapter (plan v1.2 §7.3). Useful options: `--sections 6.3 6.4` imports selected sections only; `--loss-report out.json` writes, per section, whether it became graded, teaching-only or left out, the exercises skipped for lack of an answer, unsupported math and figures not carried over, and whether the result is faithful rather than just parsed, plus an import key that identifies the run; `--record DIR` / `--replay DIR` save and replay archive responses so tests run offline (`--replay` never fetches); `--out PATH` writes the manifest elsewhere. Regression fixtures for two sections live in `tool/tests/fixtures/openstax/`, and a test requires replay to reproduce their `golden.yaml` exactly, so a change to the importer's output is always deliberate. A live re-import of both books after this change matched the committed manifests apart from `retrieved_at`.

### Declared operations (rights)
Every manifest source release states what it does with the source in `metadata.use`: `link`, `reference`, `quote`, `adapt`, `redistribute` or `ai_transform` (plan v1.2 §6). `tool/ci/verify_content_sources.py` checks it against `data/content_sources.json`; there is no silent default, because a reference citation must not hide an adaptation. Known open questions are frozen in `data/rights_discrepancy_allowlist.json` with the decision they wait on; a manifest listed there cannot be published (the ingestion workflow runs `--publish-check`). Resolve the question, declare the use, and remove the entry (a stale entry fails CI). To decide between `reference` and `adapt` for a book, run `tool/rights_overlap_audit.py <manifest> <book@version> [<later-edition@version>]`. It reports the share of the manifest's 8-word shingles found in the book, the longest matched run, the matched passages, and text found only in a later (for example CC BY-NC-SA) edition. Read the passages: standard terms and formulas are not adaptation. Record the result and decision in `data/rights_audits/`, and point `metadata.use_evidence` at it.

### Performance tasks (skill targets)
Plan §8.8: every skill target needs at least one hands-on task per major domain that produces real output. Write it as a `performance_task` lesson block with `title`, `brief`, `deliverable`, 2-20 `criteria` (each with `text` and a `how_to_check` the learner can do in the real application), an `exemplar`, a markdown `body` for older app versions, and `verification: self_check`. The learner ticks the criteria themselves: nothing is sent to the server or scored, and the app always labels the task as self-checked and not independently verified (it never counts toward readiness or skills). The database (migration `20261124040000`) and `tool/lint_manifest.dart` reject a task without these fields or with any other verification mode. Have an independent AI check every claim about the application's behaviour before publishing (D-16). First task: Excel `excel-budget-workbook-v1` (EXCEL-PILOT-4, published 2026-11-24, run 45524290448). Deploy the migration and the web build before or with the first task that uses a new block type; older app versions show the task's `body` until they update.

### Extra practice (bank depth)
Plan D-14 asks for at least 10 graded practice questions per objective. Where the book has fewer, write ORIGINAL items in `content/practice/<manifest>.yaml`, never copies of held-out checks, with the same `verify` blocks and the same independent `review` block as held-out checks. Then run `python tool/verify_practice_items.py`. For an open textbook, re-run `tool/import_open_textbook.py`, which merges approved items into their section and notes them in the credit. For a hand-authored manifest, copy approved items into the lesson's `questions`. The verifier fails if an approved item is missing or different, an unapproved one is present, or an objective has fewer than 10. Bump the version and publish.

### Source mappings (reconciling two courses)

When an authored manifest teaches what an imported source also teaches (CLEP College Algebra and the OpenStax College Algebra textbook), record where each objective's content lives before publishing either again (plan v1.2 §8.1, D-13). Use `data/concept_mappings/<manifest>__<source>.yaml`. Each section entry gives a match (`exact`, `partial`, `prerequisite`, `supplementary`, `unrelated`), depth, roles, locator, confidence and whether the section is imported in LearningApp. Never merge concepts on title alone. Check topic coverage in the section text, not the title. `tool/verify_concept_mappings.py` (CI) checks every objective is mapped and that the manifest's `Section X.Y: Title` citations agree with the mapping, and with the imported manifest's titles for imported sections. The ingestion workflow refuses to publish a manifest whose mapping is not approved (`--publish-check`). Approval is an independent review (an AI review by a different model is labelled as such; D-16), with the evidence in `data/concept_mappings/reviews/`.

### Notation profiles (one course, one notation)

Every curriculum manifest has a profile in `data/notation_profiles.yaml`: math markup (`latex` or `plain`), decimal and thousands separators, and Excel function casing (plan v1.2 §8.9). `tool/check_notation.py` (CI) flags LaTeX commands outside `$…$`, plain `x^2`, `<=` and `sqrt(` in a LaTeX course, lower-case Excel functions, decimal commas and space-separated thousands. Fix deterministic cases at the source: the CLEP generator wraps a bare LaTeX answer option in `$…$`, and the importer writes digit superscripts as Unicode (`ft²`). Remaining findings are frozen in `data/notation_baseline.json`, which can only shrink (`--write-baseline` after a cleanup; `--report <manifest>` lists them). Answer options render math like prompts do.

### 10. Keep it current
- Re-check each source's `license_evidence` at least yearly, and whenever the publisher announces changes. OpenStax relicensed its library in 2026; such changes affect only new and updated versions, so record the edition you used.
- **When a source's license gets stricter,** content already adapted under the older license may stay, but new adaptation must follow the new terms. Re-point to the older edition if it is still published.
- **Takedown or rights complaint:**
  1. Remove or replace the content.
  2. Set the source's `status` to `restricted` with a note.
  3. Re-run the checker.
- **Broken links:** fix or replace the URL and update `checked_at`.

## Open owner decisions

1. **Non-commercial status:** does LearningApp, with its sponsor, affiliate and donation plans, count as non-commercial for CC BY-NC-SA sources?
2. ~~Psychology source~~: **decided by the owner on 2026-11-24 (D-5).** CLEP Introductory Psychology now cites Psychology (1st edition, CC BY 4.0). Citations keep their section numbers; each cited 1e section was checked against its lesson topic, but lesson text was not re-verified line by line. 2e stays link and reference only. Edit `tool/curriculum_clep_psychology/` and `tool/generate_clep_psychology_course.py`, then regenerate; don't edit the YAML by hand.
3. ~~Approve the CC BY sources for adapting~~: **approved by the owner on 2026-11-20** for OpenStax College Algebra, Prealgebra and Psychology (1st editions), including `adapt` and `ai_transform`; `redistribute` added on 2026-11-24 (D-7).
4. **Unconfirmed AI claim:** the Bridges say OpenStax prohibits use for training large language models. No such statement was found on OpenStax pages on 2026-11-20. Keep the conservative note, or correct it.
5. **Production ingestion:** load the curricula (Excel and CLEP Algebra first) into production.

## Checklist for an AI agent

- [ ] The source is in `data/content_sources.json`, or you added it as `proposed` with evidence read today from the edition's own page.
- [ ] Your use is in its `allowed_uses`, and the status is `approved` for anything beyond link and reference.
- [ ] You wrote the text yourself; quotes are short and credited; no proprietary text was pasted into an AI chat.
- [ ] The credit uses the source's attribution template, including `Changes:` when adapting.
- [ ] The checks in step 7 pass, and `human_reviewed` is false unless a person reviewed it.
- [ ] You did not ingest, publish or deploy anything without the owner's go-ahead.
