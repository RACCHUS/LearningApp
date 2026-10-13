# P2f — Florida Insurance Licensure Pathways (DFS 2-20 & 2-15)

**Source review:** 2026-10-13. **Scope:** selected examination-route steps for Florida General Lines (2-20) and Life, Health & Variable Annuity (2-15) agent licenses. **Not** an exhaustive legal eligibility determination.

## Product distinctions

1. **State License vs. Exam**: A Florida insurance license (issued by the Florida Department of Financial Services) is state-granted regulatory authority to transact insurance. An exam (administered by Pearson VUE) or a pre-licensing training course is only one qualifying step, not the license itself.
2. **Partial Pathway Scope**: In line with the verified issuer directory, `requirements_status='not_verified'` remains true for comprehensive prerequisite audits, individual criminal/disciplinary background disclosures, non-resident reciprocity, and company appointments.
3. **Statutory Qualification Alternatives**: Florida law (Florida Statutes § 626.732 for 2-20 and § 626.785 / § 626.831 for 2-15) explicitly establishes multiple alternative paths (pre-licensing course, practical experience, college degree, or professional designation). Learning App represents these as an explicit `any` operator rather than collapsing them into a single course mandate.
4. **No License Issuance**: Neither Learning App nor any creator on the platform can issue an insurance license, grant an insurer appointment, or determine legal qualification.

## Regulatory Sources

- [Florida Department of Financial Services — Agent and Adjuster Qualifications](https://www.myfloridacfo.com/division/agents/licensing/agents-and-adjusters/qualifications), reviewed 2026-10-13.
- [Florida DFS Resident General Lines (2-20) Qualification Guide](https://myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-20-resident-general-lines.pdf?sfvrsn=a4426e2d_8).
- [Florida DFS Resident Health and Life (2-15) Qualification Guide](https://www.myfloridacfo.com/docs-sf/insurance-agents-and-agency-services-libraries/agents-docs/licensure/agents-adjusters/2-15-resident-health-life-agent-license.pdf).

## Technical Implementation

- **Data Manifest**: `data/catalog/florida_insurance_p2f_pathways_2026_10.json` models 2 versioned partial pathways, revision 1:
  - `fl_dfs` / `general-lines-2-20`: 4 statutory qualification alternatives (200-hr course, 1 yr experience + 40-hr course, 18-sem-hr college degree, or CPCU/CIC designation) followed by application, fingerprinting, state exam (Pearson VUE), license issuance, and insurer appointment within 48 months.
  - `fl_dfs` / `life-health-2-15`: 3 statutory qualification alternatives (60-hr course, 9-sem-hr college degree, or CLU designation) followed by application, fingerprinting, state exam, license issuance, and insurer appointment.
- **Validation Engine**: `tool/catalog_p2f_insurance_pathways.py validate` checks fixed identities, schema version 1, exact DFS URLs, 180-day review freshness, and tree validity (`all`/`any`/`step` operators).
- **SQL Generator**: `tool/catalog_p2f_insurance_pathways.py render-sql` emits guarded, transactional, idempotent SQL with fail-closed assertion checks against `catalog_verified_destinations`.
- **Test Suite**: `tool/tests/test_catalog_p2f_insurance_pathways.py` tests all invariants and negative edge cases (rejecting lookalike domains, unreviewed claims, missing URLs, flattened alternative trees, and illegal modifications).

## Production Deployment Gates

1. Validate manifest and tests:
   ```bash
   python tool/catalog_p2f_insurance_pathways.py validate
   python -m unittest tool/tests/test_catalog_p2f_insurance_pathways.py -v
   ```
2. Render deployment SQL:
   ```bash
   python tool/catalog_p2f_insurance_pathways.py render-sql > deploy_p2f.sql
   ```
3. Apply to Supabase production project `xzvkdwebtbxlrxagtzlv` with `service_role`.
4. Verify published pathway count increases from 2 (Nursing RN & LPN) to **4** (Nursing RN/LPN + Insurance 2-20 & 2-15).
5. Verify anonymous session sees all 4 approved pathways through the existing RLS policy `catalog_license_pathway_reviewed_public_select`.
