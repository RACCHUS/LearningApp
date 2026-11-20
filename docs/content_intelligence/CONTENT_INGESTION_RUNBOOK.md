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
- The tool imports only sources with `adapt` allowed and status `approved`.
- It stops if the license the publisher reports differs from the registry.
- It never turns an expression answer such as `(x-6)(x-1)` into a graded question: those stay as practice with the answer to reveal, so a correct but differently written answer is never marked wrong.
- A section with no answer that can be graded automatically is left out and reported. It stays reachable as an open textbook link.

**Then:**
1. Run the step 7 checks; `test/content/open_textbook_math_test.dart` also checks that every formula parses.
2. Review a few lessons.
3. Have the owner ingest them (step 9).

**Pilot (2026-11-20):**
- College Algebra chapter 1: 4 lessons, 27 graded questions. 1.4 Polynomials and 1.5 Factoring were left out because none of their answers is a single number.
- Prealgebra chapter 6 (Percents): 5 lessons, 49 graded questions.

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
- `python tool/ci/verify_content_sources.py`: sources registered, uses allowed, licenses stated correctly
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
| Curriculum manifests (`content/*.yaml`) | **Owner only, with the service-role key:** `dart run tool/ingest_curriculum.dart --target … --version … --manifest … --apply`, then `--stage-review`, then `--publish` |
| Learner or community lessons | The public contribution flow (`content.public_contribution`), labelled unreviewed |

**Production status (2026-11-20):** the seven curriculum manifests pass the dry run, but none has been ingested into production.

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
2. **Psychology source:** `content/clep_introductory_psychology.yaml` records OpenStax Psychology 2e as CC BY 4.0, but 2e is now CC BY-NC-SA 4.0. Either re-point to Psychology (1st edition, CC BY 4.0) or keep 2e under NC-SA terms. The checker reports this as a warning until decided.
3. ~~Approve the CC BY sources for adapting~~: **approved by the owner on 2026-11-20** for OpenStax College Algebra, Prealgebra and Psychology (1st editions), including `adapt` and `ai_transform`.
4. **Unconfirmed AI claim:** the Bridges say OpenStax prohibits use for training large language models. No such statement was found on OpenStax pages on 2026-11-20. Keep the conservative note, or correct it.
5. **Production ingestion:** load the curricula (Excel and CLEP Algebra first) into production.

## Checklist for an AI agent

- [ ] The source is in `data/content_sources.json`, or you added it as `proposed` with evidence read today from the edition's own page.
- [ ] Your use is in its `allowed_uses`, and the status is `approved` for anything beyond link and reference.
- [ ] You wrote the text yourself; quotes are short and credited; no proprietary text was pasted into an AI chat.
- [ ] The credit uses the source's attribution template, including `Changes:` when adapting.
- [ ] The checks in step 7 pass, and `human_reviewed` is false unless a person reviewed it.
- [ ] You did not ingest, publish or deploy anything without the owner's go-ahead.
