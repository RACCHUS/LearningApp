# P2f — Florida DFS Insurance Licensure Pathways (2-20 and 2-15)

**Revision 2 source review:** 2026-11-06. **Scope:** selected regulator-sourced steps for Florida resident agent licenses; not a complete eligibility determination.

## 2-20 General Lines

Revision 2 models six alternatives in the DFS resident guide: (1) 200-hour approved property/casualty course; (2) one year in the prior four years of full-time responsible insurance duties across all listed lines; (3) one year in the prior four years as a licensed and appointed 4-40, 20-44 or 0-55 representative **and** a 40-hour approved course; (4) accredited insurance degree with at least 18 semester hours in property, casualty, health and commercial insurance; (5) equivalent resident license held continuously at least one year before Florida residency, with Florida application within 90 days of becoming a resident; and (6) CPCU designation. The former CIC alternative is removed because the reviewed resident 2-20 guide identifies CPCU, not CIC.

Examination requirements are conditional: the first three routes require the state exam; degree, qualifying transfer and CPCU routes are exam-exempt. A passing exam from within one year can also remove the need to retake it. Appointment is required for validity; DFS states unappointed licenses expire after 48 months.

## 2-15 Life, Health and Variable Annuity

Revision 2 represents the combined route as (one of: 30-hour life/annuity/variable-contract course, ChFC or FLMI) **and** (one of: 40-hour health course, CEBS, ChHC, HIA, REBC or RHU). Other alternatives are a 60-hour approved course; a degree with at least nine credit hours specifically covering health, life, annuities and variable contracts; equivalent resident license held at least one continuous year with application within 90 days of Florida residency; equivalent license in a reciprocal state within the four years before application (prelicensing waiver but exam still required); or CLU (exam-exempt). A passing exam from within one year can also remove the need to retake it. Appointment is required for validity; DFS states unappointed licenses expire after 48 months.

## Versioning and safety

Revision 2 supersedes revision 1; revision 1 is never edited in place. Each step cites the relevant DFS resident qualification PDF; the record's canonical source URL remains the DFS qualifications directory to match the published issuer record. Fees and individual background/reciprocity determinations are not claimed as comprehensively verified. The generated SQL retires revision 1 and inserts revision 2 in one transaction; it is not executed against hosted Supabase in this PR.

## Validation

```bash
python3 tool/catalog_p2f_insurance_pathways.py validate
python3 -m unittest tool/tests/test_catalog_p2f_insurance_pathways.py -v
python3 tool/catalog_p2f_insurance_pathways.py render-sql
```
