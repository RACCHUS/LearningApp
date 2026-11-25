# Parked features

Built (or partly built) features that are **not** wired into the app yet, and why. Parked means *kept for later*: none of these may be deleted without the owner's approval. "Never drop" marks features the owner has explicitly said will be kept.

Owner decisions of 2026-11-17. Slice numbers (W*n*) refer to `docs/engineering/LearningApp_Codebase_Simplification_AI_Context_Optimization_Plan.md` §14.

| Feature | Code | Why parked | Unblocks when |
|---|---|---|---|
| Marketplace | `services/marketplace/`, `widgets/marketplace/` | Real money: needs a payment provider, payouts and terms. Purchases are in memory only today | Owner chooses a payment provider and terms |
| BYOK and AI generation | `services/ai/byok_*`, `llm_client`, `curriculum_generator`, `item_evaluator`, `generated_content_models`, `widgets/ai/byok_settings_dialog` | Paid AI, and the BYOK release latch is hard-disabled by owner policy (FLAG-015) | Owner budgets for AI and lifts the latch |
| AI explanations, usage quotas (W16) | `community_ai_explanation_service`, `governance/usage_quota_service` | Paid AI calls; the quota check belongs with them | Same as BYOK and AI generation |
| Community resources (W4), **never drop** | `models/community/community_resource`, `community_resource_service`, `resource_card`, `resource_authoring_screen` | No backend: resources are kept in memory, and there is no `community_resources` table | Build the table, RLS and review flow; ship with Q&A |
| Word senses, bilingual vocabulary, case studies (W8–W10) | `words/word_sense_*`, `language/bilingual_*`, `casestudy/*` | Content is demo-sized (5, 5 and 1 items) | More content is authored |
| Long answers, checklists, video (W11–W13) | `rubric/long_answer_*`, `performance/*`, `video/*` | No content; checklists and video also keep attempts in memory. (Hands-on performance tasks now use the separate `performance_task` lesson block.) | Content plus a backend for each |
| Item statistics sheet (W14) | `widgets/analytics/item_psychometrics_sheet`, `elo_rating_engine` | The sheet shows IRT/Elo calibration, which nothing computes yet. Classical statistics are wired: `compute_item_analytics` (admins and moderators only since `20261124110000`) applies the plan v1.2 §16.4 rules and opens moderation reports; the numbers appear in each report. Graded answers from consenting learners feed it since `20261124120000` | IRT calibration, if wanted, plus enough consenting learners |
| Adaptive practice (W15) | `screens/assessment/adaptive_practice_screen` | Not yet wired. Browser grading is acceptable for practice (owner); still use only items whose keys are already client-visible, never hidden-key items | Wire to exam practice with public-key items |
| SEO metadata (W16), **never drop** | `community/seo_metadata_service` | Hard-codes `app.learningapp.io` (not the live domain), `seo.dynamic_endpoints` is OFF, and the hash-routed app is not crawlable | A separate SEO plan (domain, routing, pre-rendering) |
| LMS exports (W17) | `interop/lti_and_badges_service`, `open_standards_service`, `cmi5_course_service` | Needs external LMS or LRS partners | A partner integration |
| Q&A answer history, contributor profiles | Wired; keys `learning.answer_revisions`, `learning.educator_profiles` OFF | Depend on `learning.community_qa` (user-generated content), which is OFF | Owner turns on Community Q&A |
