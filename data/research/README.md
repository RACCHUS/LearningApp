# Demand research and source discovery

Version-controlled research for the demand-driven content ingestion plan (v1.2 §4 and §5, slices 3 and 4). It is **aggregate, public, non-personal data only**, and it is not a reuse approval: the runtime source policy stays in `data/content_sources.json`.

- `opportunities/<id>.yaml`: one opportunity brief (§4.2) with its observations (§4.1), the six priority factors (§4.3), hard gates, effort and a recommendation.
- `sources/<id>.yaml`: one source candidate (§5.2) with its rights state, permitted actions and recommendation.

Check: `python tool/verify_research.py` (CI). Priorities: `python tool/verify_research.py --report`.

## Rules the checker enforces

- **Unknown is null, never zero.** A factor score (0-5) needs evidence and a rater. A demand score needs measured demand.
- **Observations** state their evidence class, metric, unit, geography, period, publisher, directness and the date checked. An observed value needs an https source; suppressed, missing and not-applicable values are null.
- `measured_comparable` needs two evidence classes and two comparable observations in one cohort. The high-demand lane needs measured demand.
- **Priority** (§4.3) uses only known weights (demand 25, underserved need 20, outcome value 20, cross-goal reuse 15, source feasibility 10, improvement potential 10). The report always shows the bounds, and a score is usable for allocation only with at least 70% of the weight known.
- **Hard gates come before scoring:** acquire, adapt and create need every gate passed.
- **Sources** without verified rights may only be discovered, linked or referenced. Any other action needs a `registry_source_id` in `data/content_sources.json` and must stay within its allowed uses.
- Defer needs a reason (`low_current_priority`, `rights_unknown`, `strong_external_alternative`, `no_reliable_source`, `high_maintenance`, `adapter_not_ready`) and a revisit trigger.
- No personal fields (emails, names, user ids, IPs).

URLs in these files are research leads and are **not** in the scope of `tool/check_external_links.py` (plan §5.2): a dead discovery link is a research finding, not a broken page.

Never invent demand, participation or job numbers. Leave them null until there is a source.
