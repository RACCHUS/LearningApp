# Content Supply and Reuse Map

Master plan v2.6 §8.4. This is a planning view over the authoritative files (`content/*.yaml`, `content/bridges/`, `content/companions/`, `data/content_sources.json`). It is not a separate catalog. How to add content: [CONTENT_INGESTION_RUNBOOK.md](CONTENT_INGESTION_RUNBOOK.md).

**Roles:**
- **Teach:** explanation blocks
- **Example:** worked examples or call-outs
- **Practice:** lesson questions and flashcards
- **Check:** independent assessment items
- **Bridge:** prerequisite help lesson
- **Access:** audio, plain language and pictures

Counts come from the files as of 2026-11-20.

**Production status:** none of these curricula has been ingested into production. Learners see none of it until the owner runs the ingestion (runbook step 9).

## Excel Fundamentals (`software-excel-fundamentals`, EXCEL-PILOT-1)

| Objective | Lesson | Teach | Example | Practice | Check | Bridge | Sources (use) |
|---|---|---|---|---|---|---|---|
| SPREADSHEET-1.1 | Budget Totals in Excel | 2 blocks (sample data now in the lesson) | 1 call-out, 1 practice prompt with a worked answer, 1 simulation | 6 questions, 3 terms, 5 flashcards | none | 4 percent Bridges (fraction↔decimal, percent change, percent of a number, Excel percent format), each with a link-only companion | Microsoft Support (link, reference); OpenStax Prealgebra 2e (link) |

**Gaps:**
- There's only one lesson, so most Excel skills are uncovered: cell references, AVERAGE/COUNT, sorting and filtering, charts, IF.
- There are no independent check items, so readiness can't be shown for this target (plan D-14).
- **Prepared for ingestion 2026-11-24 (D-13):**
  - the sample data is now typed into the lesson (the CSV it used to point to was never downloadable in the app);
  - the call-out uses the field names the renderer reads;
  - the practice prompt has a worked answer (=SUM(C2:C9), total 440);
  - 4 more practice questions and 5 flashcards, all with stable IDs.
- The 4 percent Bridges are tagged `excel`/`spreadsheet`, so help in this SUM lesson offers percent topics. Scope them more tightly when more Excel lessons exist.
- **Sources:** Microsoft documentation is proprietary, so we write all text ourselves and link to it.

**Next supply:** more Excel lessons written in-house from Microsoft's documentation, used as references. Percent Bridges can build on OpenStax Prealgebra 1st edition (CC BY, approved for adapting).

## CLEP College Algebra (`clep-college-algebra`, 2026)

The source for every lesson is OpenStax College Algebra 1st edition, **CC BY 4.0**: approved for adapting (owner, 2026-11-20). The College Board CLEP guide is used for objective alignment only.

The per-lesson counts are the same in every row: 3 teach blocks, 2 call-outs, 2 questions + 3 flashcards, and 3 check items. No lesson has a Bridge yet.

| Objective | Lesson | OpenStax 1e sections | Prerequisite Bridge needed |
|---|---|---|---|
| 1.1 | Exponents, Radicals, Scientific Notation | 1.2, 1.3 | Exponents as repeated multiplication |
| 1.2 | Polynomial Operations, Factoring | 1.4, 1.5 | Negative numbers; distributive property |
| 1.3 | Rational Expressions, Domain | 1.6 | Fraction operations (the existing fraction↔decimal Bridge is related) |
| 1.4 | Absolute Value, Real-Line Distance | 1.1, 2.6 | Negative numbers; absolute value as distance |
| 1.5 | Logarithmic Expressions | 6.3, 6.5 | Exponents |
| 2.1 | Linear Equations and Inequalities | 2.1, 2.2, 2.7 | Solving one- and two-step equations |
| 2.2 | Quadratic Equations, Discriminant | 2.5 | Square roots; factoring |
| 2.3 | Radical, Rational, Absolute Value Equations | 2.6 | Fraction operations; absolute value |
| 2.4 | Systems of Equations | 7.1, 7.3 | Solving linear equations |
| 2.5 | Exponential and Logarithmic Models | 6.6, 6.7 | Percent change (existing Bridge); exponents |
| 3.1 | Functions, Domain, Range | 3.1, 3.2 | Evaluating expressions |
| 3.2 | Operations and Composition | 3.4 | Evaluating expressions |
| 3.3 | Graphs, Intercepts, Symmetry | 3.3 | Coordinate plane |
| 3.4 | Transformations | 3.5 | Coordinate plane |
| 3.5 | Inverse Functions | 3.7 | Solving linear equations |
| 3.6 | Rational Functions, Asymptotes | 5.6 | Fraction operations |
| 4.1 | Real Number System | 1.1 | Negative numbers |
| 4.2 | Complex Numbers | 2.4 | Square roots; negative numbers |
| 4.3 | Sequences and Series | 9.1, 9.2, 9.3 | Exponents |
| 4.4 | Combinatorics, Binomial Theorem | 9.5, 9.6 | Factorials and multiplication principle |

**Open textbook support (2026-11-24):** the College Algebra import (R4) now includes OpenStax 1.4 Polynomials and 1.5 Factoring as teaching-only lessons, which supports objective 1.2 above. They have practice with answers to reveal but no graded check: factoring answers are expressions, which need a safe symbolic grader (plan v1.2 §9.1).

**Gaps across all 20 lessons:**
- **Practice is thin:** 2 questions per lesson. Add worked examples and practice adapted from OpenStax 1st edition (approved), or use parametric families where the arithmetic is checkable.
- **No algebra Bridges:** the most-needed ones, by how many lessons need them, are negative numbers, solving linear equations, fraction operations, exponents and the coordinate plane. Bridges also need subject scoping so help offers only relevant Bridges (help is currently Excel-only); new check templates are also needed: signed arithmetic, absolute value, power, and one-step linear equations.
- **Access:** no audio scripts or plain-language variants are recorded for these lessons.
- **Not in production:** the curriculum still has to be ingested (owner).

## Other curricula in `content/` (summary)

| Curriculum | Source posture | Note |
|---|---|---|
| CLEP Introductory Psychology | OpenStax Psychology 1st edition (CC BY; adapt and redistribute approved) | Re-pointed from 2e on 2026-11-24 (owner decision D-5); check research-heavy sections against the current CLEP outline before relying on them |
| CompTIA Security+ SY0-701 | CompTIA objectives (proprietary, reference) | Write all text in-house |
| Software Engineer career | SWEBOK (proprietary, reference); BLS (public domain) | BLS text may be quoted or adapted |
| B.S. Computer Science | ACM/IEEE CS2023 (license unknown, reference) | Confirm the license before quoting |
| Adult Literacy Foundations | Kentucky Reading Research Center (unknown, reference) | Confirm the license before quoting |

## Candidate sources not used yet

| Source | License | Possible use |
|---|---|---|
| MIT OpenCourseWare | CC BY-NC-SA 4.0 | Link and reference; adapting waits on the non-commercial decision |
| Wikibooks | CC BY-SA 4.0 | Link and reference; adapting needs share-alike lessons |
| OpenStax Prealgebra 1st edition | CC BY 4.0 (approved) | Adapt for numeracy and algebra-prerequisite Bridges |
