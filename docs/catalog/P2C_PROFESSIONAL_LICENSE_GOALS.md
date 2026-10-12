# P2c — Professional License Goals and Issuer Source Panels

**2026-10-12.** **Status:** implementation candidate until full CI and hosted verification.

## Product change

A professional license is a **regulator-issued permission**, not a certification or an exam. The Learning App now models `professional_license` as a separate `learning_targets.target_type` and requires a jurisdiction code such as `US-FL`. The first available reviewed source is the Florida DBPR Real Estate Sales Associate License.

A learner can use **Credentials & exams → Florida Real Estate Sales Associate → Create private goal**. The dialog prefills the title, Florida regulator and `US-FL`. On creation, the user-owned draft remains `is_official=false`, `is_public=false`, `review_status=unreviewed`; a separate private link associates the draft with the reviewed issuer identity. No exam or license is awarded. A direct Florida checklist link is available as **Regulator licensing checklist**, never as a training course.

## Authority and scope

- [Florida DBPR Sales Associate Initial Application (RE 1) Checklist](https://www.myfloridalicense.com/CheckListDetail.asp?XACT_DEFN_ID=744&clientCode=2501&sub_id=undefined&xactCode=1010) is the state regulator's current licensing checklist.
- [Florida Real Estate Commission Licensure Information](https://www2.myfloridalicense.com/real-estate-commission/licensure-information/) provides regulator context. Learners should check the source directly because laws, exemptions, prerequisites, fees and available study providers may change.
- This feature only verifies issuer/regulator **identity and the outbound source URL**. It does **not** re-state specific licensing requirements as separately verified structured facts, recommend a paid provider or guarantee qualification.

## Data protections

1. Additive migration `20261012000005_professional_license_goals_and_regulator_links.sql` updates the `learning_targets` allowed type set, requires a valid structured jurisdiction for new professional license goals, and expands the *private* goal-source INSERT RLS check to require exact reviewed type and exact jurisdiction.
2. A linked goal's type and regulator jurisdiction cannot be changed without first removing its source link. Do not quietly relabel a Florida license as an exam or infer authorization for another state.
3. An issuer-linked private goal is not an official award; changing it to `is_official` without detaching its source link is prohibited by a separate trigger. Community review/publishing can follow the independent existing community moderation workflow.
4. `reviewedIssuerForGoalProvider` first reads the owner's link under RLS and then fetches only a currently published public issuer destination. Signed-out users and unrelated users never see private goal associations, and revoked issuer sources are not displayed as current.
5. The saved target page displays the reviewed issuer, jurisdiction, explanation of verification limits, and a direct official link (browser with copy fallback). The app never queries private admin-only intake or demand-signal tables for these pages.
6. The reviewed link registry now includes a ninth outbound resource: the Florida RE 1 regulator checklist. Data are sourced and linked, never copied as third-party course content.

## Test and deployment gates

- Clean and incremental PostgreSQL migration and pgTAP test for the new target type, jurisdiction CHECK, owner-only link RLS and source-identity immutability.
- Flutter model tests for exact type serialization, source card navigation, and Florida-licensed goal prefill with state code; original career/certification flows still work.
- Existing official taxonomy download and ingest must still pass CI.
- Apply to the Learning App hosted Supabase `xzvkdwebtbxlrxagtzlv`, insert only the single new approved Florida checklist link, and check that existing rows are unchanged.
- Verify the original ten reviewed identity records, nine approved public resource links, 21 pending candidates, 17 learning targets, 7 lessons, 831 BLS observations, 13 users.
- Live creation and viewing of a user-owned Florida license draft still needs authenticated browser smoke testing; it should not be claimed solely from unit tests.

## Beyond the pilot

Check Florida DFS insurance licensing, DBPR contractor classifications, nursing professional licenses and other jurisdiction-specific license records **one by one** with official regulator citations and version dates before extending verified listings or adding substantive eligibility/fee rules.
