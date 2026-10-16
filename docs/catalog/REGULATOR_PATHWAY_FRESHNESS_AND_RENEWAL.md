# Regulator Pathway Freshness, Expiration & Renewal Protocol

**Document Version:** 1.0  
**Effective Date:** October 16, 2026  
**Audience:** Catalog maintainers, compliance reviewers, and database administrators  
**Scope:** Versioned regulator-sourced licensure pathway records in `public.catalog_license_pathway_versions`

---

## 1. Executive Summary & Purpose

A critical architectural invariant of Learning App is that **stale regulatory guidance must fail closed rather than mislead learners**. Professional licensing rules, statutory coursework requirements, examination providers, and application procedures change over time.

To enforce this invariant, the database and Row Level Security (RLS) policies enforce a **180-day source-freshness window**:
- Any pathway record whose `source_checked_at` timestamp is older than **180 days** is automatically hidden from anonymous and signed-in learner clients by RLS.
- Database triggers reject publication of any pathway whose verified source date is older than 180 days.
- In-place editing of timestamps on published pathways is strictly prohibited by database immutability triggers; refreshing source verification requires retiring the prior revision and publishing an auditable new revision.

This document establishes the official calendar, procedural audit checklist, and re-versioning runbook to ensure all published pathways are systematically recertified before the 180-day expiration window closes.

---

## 2. Technical Architecture & Fail-Closed Enforcement

### 2.1 The RLS Freshness Invariant
In `supabase/migrations/20261012000006_catalog_license_pathway_versions.sql`, the public `SELECT` policy is defined as:

```sql
create policy catalog_license_pathway_reviewed_public_select
on public.catalog_license_pathway_versions for select to anon,authenticated
using (
  publication_status='published' and review_status='approved'
  and source_checked_at >= now() - interval '180 days'
  and (effective_from is null or effective_from <= current_date)
  and (effective_until is null or effective_until >= current_date)
  and exists (
    select 1 from public.catalog_verified_destinations d
    where d.source_namespace=public.catalog_license_pathway_versions.source_namespace
      and d.source_key=public.catalog_license_pathway_versions.source_key
      and d.publication_status='published'
      and d.destination_type='professional_license'
      and d.jurisdiction=public.catalog_license_pathway_versions.jurisdiction
  )
);
```

If `now() - source_checked_at > 180 days`, the condition `source_checked_at >= now() - interval '180 days'` evaluates to `FALSE`, immediately hiding the record from all public queries without manual intervention or data deletion.

### 2.2 Immutability & Re-Versioning Requirement
The database trigger `trg_guard_catalog_license_pathway` enforces:
```sql
if tg_op='UPDATE' and old.publication_status in ('published','retired') then
  if old.publication_status='published'
     and new.publication_status='retired'
     and (to_jsonb(new) - 'publication_status')
         = (to_jsonb(old) - 'publication_status') then
    return new;
  end if;
  raise exception 'Published pathway versions are immutable; create a new revision';
end if;
```
**Key Operational Implication:** An administrator cannot execute an `UPDATE ... SET source_checked_at = now()` on a published row. Such an update will abort with an exception. To recertify a pathway, the publisher must execute an atomic transaction that:
1. Retires Revision $N$ (`SET publication_status = 'retired'`).
2. Inserts Revision $N+1$ with `supersedes_revision = N` and a refreshed `source_checked_at` timestamp.

---

## 3. Published Baseline & Expiration Calendar

The six currently published Florida regulator pathways were reviewed and verified in October 2026:

| Destination Identity | License Title | Source Checked Date | 180-Day RLS Expiration Date | Target Q1 2027 Review Window |
| :--- | :--- | :--- | :--- | :--- |
| `fl_bon:registered-nurse` | Florida RN initial licensure | 2026-10-12 18:08 UTC | **2027-04-10 18:08 UTC** | March 1 – March 15, 2027 |
| `fl_bon:licensed-practical-nurse` | Florida LPN initial licensure | 2026-10-12 18:08 UTC | **2027-04-10 18:08 UTC** | March 1 – March 15, 2027 |
| `fl_dfs:general-lines-2-20` | Florida General Lines (2-20) Agent | 2026-10-13 12:00 UTC | **2027-04-11 12:00 UTC** | March 1 – March 15, 2027 |
| `fl_dfs:life-health-2-15` | Florida Life & Health (2-15) Agent | 2026-10-13 12:00 UTC | **2027-04-11 12:00 UTC** | March 1 – March 15, 2027 |
| `dbpr_fl:certified-general-contractor` | Florida Certified General Contractor (CGC) | 2026-10-13 12:00 UTC | **2027-04-11 12:00 UTC** | March 1 – March 15, 2027 |
| `dbpr_fl:certified-building-contractor` | Florida Certified Building Contractor (CBC) | 2026-10-13 12:00 UTC | **2027-04-11 12:00 UTC** | March 1 – March 15, 2027 |

### 3.1 Alerting Schedule
- **Day 0–149 (Normal Operation):** All 6 pathways serve normally under RLS.
- **Day 150 (Warning Threshold — March 11–12, 2027):** Automated tool `tool/verify_published_pathways.dart` begins emitting `WARNING` notices alerting operators that fewer than 30 days remain before expiration.
- **Day 165 (Urgent Review — March 26–27, 2027):** Final cut-off for human reviewer recertification.
- **Day 180 (Hard Expiration — April 10–11, 2027):** If unrefreshed, RLS automatically hides the records.

---

## 4. Regulator Re-Audit Checklists

During the recertification window, a human reviewer must access the official regulator portals and perform the following checks:

### 4.1 Florida Board of Nursing (`fl_bon`)
- **Official Source:** [https://floridasnursing.gov/nurse-rn-lpn/](https://floridasnursing.gov/nurse-rn-lpn/)
- [ ] Verify that approved RN and LPN pre-licensure education program categories remain current.
- [ ] Confirm Practical Nursing Equivalency (PNEQ) requirements have not changed under Board rules.
- [ ] Confirm NCLEX-RN and NCLEX-PN testing requirements and registration paths.
- [ ] Confirm Livescan FDLE/FBI background screening instructions and electronic fingerprinting retain validity.
- [ ] Check for any newly enacted Florida statutes or Board rules affecting initial examination applicants.

### 4.2 Florida Department of Financial Services (`fl_dfs`)
- **Official Source:** [https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications)
- [ ] Confirm General Lines (2-20) 200-hour pre-licensing qualification course hours and statutory alternatives (1-year experience + 40 hours, degree with 18 credit hours, or CPCU/CIC designations).
- [ ] Confirm Life, Health & Variable Annuity (2-15) 60-hour pre-licensing qualification course hours and statutory alternatives (degree with 9 credit hours or CLU designation).
- [ ] Verify state examination provider remains Pearson VUE and passing threshold remains 70%.
- [ ] Check for changes to MyFloridaCFO portal application forms or electronic fingerprinting vendor procedures.
- [ ] Verify 48-month appointment maintenance rule under Florida law.

### 4.3 Florida DBPR Construction Industry Licensing Board (`dbpr_fl`)
- **Official Sources:**
  - CGC: [https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0605](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0605)
  - CBC: [https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0602](https://www.myfloridalicense.com/intentions2.asp?boardid=06&chBoard=true&professionid=0602)
- [ ] Confirm 4-year trade experience matrix alternatives (4 years field with 1 year foreman; 3 years field + 1 year college; 2 years field + 2 years college; 1 year foreman + 3 years college; 4-year degree + 1 year foreman; military equivalency).
- [ ] Confirm 3-part examination structure: Business & Finance, Contract Administration, and Project Management (70% passing threshold each).
- [ ] Confirm financial responsibility requirements: credit score $\ge$ 660, or licensing bond + 14-hour financial course.
- [ ] Confirm DBPR application forms remain CILB 5-A (CGC) and CILB 5-B (CBC).

---

## 5. Re-Versioning & Publishing Runbook

Once the regulator review is completed, execute the following promotion workflow:

### Step 1: Update the Manifest File
In `data/catalog/`:
- For Nursing: `florida_nursing_p2e_pathways_2026_10.json`
- For Insurance: `florida_insurance_p2f_pathways_2026_10.json`
- For Contractors: `florida_contractors_p2g_pathways_2026_10.json`

Set:
- `source_checked_on`: New audit date (e.g. `"2027-03-10"`).
- `reviewed_on`: New audit date (e.g. `"2027-03-10"`).
- `revision`: `2` (or $N+1$).
- `supersedes_revision`: `1` (or $N$).
- If requirements changed: update `pathway_tree` nodes and document changes in `review_note`.
- If requirements unchanged: maintain existing `pathway_tree` nodes and note that regulator text was re-verified with no modifications.

### Step 2: Validate Manifest & Run Unit Tests
```bash
python tool/catalog_p2e_pathways.py validate
python tool/catalog_p2f_insurance_pathways.py validate
python tool/catalog_p2g_contractor_pathways.py validate
flutter test test/tool/verify_published_pathways_test.dart
```

### Step 3: Render and Review Transactional SQL
The renewal transaction must retire revision 1 before inserting revision 2:

```sql
begin;
set local statement_timeout = '25s';

-- 1. Retire previous revision
update public.catalog_license_pathway_versions
   set publication_status = 'retired'
 where source_namespace = 'fl_dfs'
   and source_key = 'general-lines-2-20'
   and revision = 1
   and publication_status = 'published';

-- 2. Insert new revision citing refreshed source check
insert into public.catalog_license_pathway_versions
  (source_namespace, source_key, revision, supersedes_revision, jurisdiction,
   route_kind, title, overview, coverage, source_url, source_checked_at,
   reviewed_at, reviewer, review_status, publication_status, pathway_tree)
values
  ('fl_dfs', 'general-lines-2-20', 2, 1, 'US-FL',
   'examination', 'Florida General Lines (2-20) Agent: selected examination-route steps',
   ..., 'https://www.myfloridacfo.com/...', '2027-03-10T12:00:00Z'::timestamptz,
   '2027-03-10T12:00:00Z'::timestamptz, 'Learning App source review', 'approved', 'published', ...);

-- 3. Assert revision 2 is published and revision 1 is retired
do $verify$ begin
  if not exists (
    select 1 from public.catalog_license_pathway_versions
     where source_namespace = 'fl_dfs' and source_key = 'general-lines-2-20'
       and revision = 2 and publication_status = 'published'
  ) or not exists (
    select 1 from public.catalog_license_pathway_versions
     where source_namespace = 'fl_dfs' and source_key = 'general-lines-2-20'
       and revision = 1 and publication_status = 'retired'
  ) then
    raise exception 'Pathway renewal assertion failed';
  end if;
end $verify$;

commit;
```

### Step 4: Execute Transaction
Run the generated SQL script via an authorized database connection (Supabase SQL Editor or Management API database query endpoint).

### Step 5: Verify via Anonymous REST
Run the verification tool:
```bash
dart run tool/verify_published_pathways.dart
```
Confirm:
- Exactly 6 pathways returned with `publication_status = 'published'`.
- All `source_checked_at` timestamps are within the new 180-day window.
- Tool outputs `✅ PASSED`.

---

## 6. Automated Monitoring & CI Integration

The `tool/verify_published_pathways.dart` tool provides fail-closed health reporting:
1. **Missing or Unexpected Rows:** Exits with code 1 immediately.
2. **Expired Records (> 180 days):** Exits with code 1 immediately with detailed expiration age.
3. **Approaching Expiration (150–180 days):** Emits clear `⚠️ WARNING` notices indicating the exact number of days remaining until public visibility is cut off.
4. **Unit Tests:** `test/tool/verify_published_pathways_test.dart` runs in standard CI suites to prevent regressions in failure handling.
