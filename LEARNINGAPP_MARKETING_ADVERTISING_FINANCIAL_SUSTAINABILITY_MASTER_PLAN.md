# LearningApp — Marketing, Advertising, Business & Financial Sustainability Master Plan

**Version:** **1.6 — final source/code review and implementation handoff** (supersedes v1.5; retains zero-cost/MCP, build-dark/feature governance and owner decisions)  
**Prepared:** November 10, 2026  
**Repository:** https://github.com/RACCHUS/LearningApp  
**Status:** Final reviewed implementation proposal, **not a claim of deployment or passed CI**. Repository `main` HEAD independently rechecked at `8fe54cb01a1f35a9ee6937233674a4f2e5998279` on November 10, 2026; key code paths were read again, but live hosting/database behavior was not tested. **BYOK OFF** is an explicit target implementation state, **not confirmation that live BYOK has already been disabled**. No code, migrations, flags, payments, ad accounts or production settings were changed by this document update.  
**Primary constraints:** Sustain and grow LearningApp without harming learning, speed, accessibility, privacy, or trust. **Target $0 owner-funded recurring cash expense** with audited quotas and no surprise billing. **Build approved new capabilities dark** and retain independently reversible controls. **Keep TEL Fast available** with an **Experimental** label wherever evidence is incomplete; **disable BYOK for all production users until remediation and verification**; **never remove a still-needed, unreplaced legacy capability**. Do not build the prohibited patterns in §17.

### v1.6 decisions and final-review change record

This master plan retains the consolidated v1.5 owner decisions: **Fast stays available but unverified behavior is labeled Experimental; BYOK must be turned OFF until repaired and approved; and useful legacy capabilities cannot be deleted without verified replacement or explicit retirement approval.** The v1.6 review further checks the current repository HEAD, clarifies SEO structured data and external ad-spend boundaries, and adds concrete release gates (§22).

| Change | Consolidated location |
|---|---|
| Build approved capabilities, ship dark, enable only after gates pass | §0.1; §9; §14; §19.4 |
| Correct source audit of `FeatureFlagsCore`, `TelFeatureFlags`, `public.is_admin()` and existing admin routes | §2.1; §20.1 |
| Concrete registry seeds and inherited/default decisions | §20.3a |
| Mandatory build-dark contract and off-path testing | §20.5a |
| Expand FLAG-001 and add FLAG-011 through FLAG-013 | §20.9 |
| Resolve the three previous owner decisions (Fast, BYOK, legacy features) | §16.1; §20.3a; §20.9 |
| Define experimental maturity labels and evidence requirements for any enabled but unverified feature | §16.2; §20.3b; §20.5a |
| Enforce a no-capability-loss legacy retirement contract | §16.3; §20.9 |
| Recheck main HEAD and audit high-risk code, SEO QAPage eligibility, external spending controls and release acceptance | §2; §4; §14; §19; §22 |

The latest source review is **read-only repository evidence**, not confirmation of production deployment. Relevant free-tier rules, SEO eligibility and Cloudflare deployment guidance were checked against current official documentation on November 10, 2026; prices and quotas remain subject to change. *Built* means merged and testable code; *enabled* means permitted for eligible real users. These are distinct milestones. **Owner policy does not itself operate a production feature switch.**

---

## 0. Executive decision

LearningApp should **not** become an ad-supported learning app in the conventional sense. Its differentiator is moving someone efficiently from a real-world goal through useful resources, gap-filling, practice, evidence of understanding, and a real outcome—even when the best educational content is elsewhere.

Use a **free-first, diversified, low-interruption sustainability model**:

1. **Organic discovery** through indexable, high-value public goal/exam/career pages and practical tools.
2. **Voluntary support** through discreet one-time and optional recurring contributions.
3. **Secure, eventually re-enabled BYOK; MCP interoperability; cost-efficient AI.** The required production state is **BYOK OFF until fixes are implemented, verified and approved**; completion of the shutdown still needs deployment verification. After approval, users may bring their own model/API or connect a compatible external AI assistant while LearningApp provides reviewed educational tools. MCP itself does not subsidize model usage, and third-party AI subscriptions have distinct access and billing rules.
4. **Directly approved sponsorships** on appropriate adult-oriented public discovery/resource pages, not during learning.
5. **Clearly disclosed affiliate relationships**, only when the recommended destination genuinely serves the learner.
6. **Build a programmatic display-ad capability dark**, limited to eligible public-page HTML, and enable it only for a small controlled test after all legal, policy, financial and user-experience gates pass. Do not add ad SDKs to the core Flutter study experience.
7. **Build approved optional paid-value capabilities dark** (e.g., higher-cost managed AI capacity, institution/creator features); only activate them when costs, demand, legal and user needs are measured. Never monetize a learner's weakness or restrict essential learning just to sell upgrades.

**Permanent product rule:** Learn, active lessons, quizzes, simulations, assessments, flashcards, accessibility workflows, and Progress must remain ad-free. Do not sell learner data or use learning evidence as an advertising target. A valid result can be a learner spending *less* time in LearningApp because they found the right resource and completed their goal.

### 0.1 Build everything approved, ship dark, enable on gate

**Owner direction:** Build and retain approved new capabilities in a safe disabled state until their gates pass. **Do not retroactively disable established useful features just because the new registry is being introduced.** TEL Fast remains available; an incomplete evidence base is shown honestly through an **Experimental** label. BYOK is the explicit exception: it must be switched **OFF for everyone in production** pending remediation and approval. A feature can be switched off again later through the Feature Control Center without a redeploy once that control plane has been implemented. Before then, any emergency shutdown may require a narrow code/config deployment.

**What "built" and "enabled" mean:**

- **Built** means the code, tests and off-path are merged. Building costs engineering time only, not cash.
- **Enabled** means the feature is live for real users. Every gate in this master plan (legal, privacy, consent, performance, owner approval) still applies at enable time, not build time.
- Where earlier recommendations said "defer", "do not build" or "conditional experiment" about a capability in the §0 decision table, read it as **"build dark; do not enable until the gate passes."** The gates themselves are unchanged.
- §17 ("What we should definitely not build") remains binding. Those items break the plan's principles (ads in study flows, selling learner data, dark patterns) and are not on the build-dark list.

**Cost rules that make this still $0:**

1. A dark feature runs no code on the hot path, makes no network request, loads no script and calls no paid service. This is tested (§20.5a item 3).
2. Anything that can spend money (paid acquisition spend, platform-funded AI inference, extra paid capacity) is built with a **server-enforced spend cap that defaults to 0**. Raising it requires an explicit owner action recorded in the audit log. No auto-upgrade, no overage, no silent fallback to a platform-billed model (as required by §19.3).
3. Display-ad code lives only in the static public-page layer. It is never added to the Flutter app, so the study experience carries no ad code whether or not ads are enabled.
4. Dark code in the Flutter app must stay within a bundle-size and startup budget checked in CI (see §20.5a item 6), so keeping features does not slow the app.

### Decision table

| Workstream | Recommendation | Priority | Production enablement gate |
|---|---|---|---|
| Site-wide Feature Control Center / kill switches | Audit the currently unwired `FeatureFlagsCore` and runtime-in-code `TelFeatureFlags`; build one audited, live, server-enforced registry with admin UI and required disabled behavior | **P0 foundation / P1 panel** | Safe OFF prevents direct RPC/MCP/side effects, preserves work, leaves learning usable; no full redeploy; every future feature passes CI flag contract |
| Public SEO / search discovery | Build an independently crawlable, lightweight static/SSR layer; link to Flutter | P0 | Verified 200/404, metadata, structured data, Search Console, real public content |
| BYOK hardening and cost control | **Production OFF pending remediation**, then secure rebuild/verification before any re-enable | **P0 immediate disable + remediation** | Verified no current call can initiate with a user key; security, CSP, provider-flow, privacy and no-key-leakage tests; owner approval |
| MCP integration and user-owned AI distribution | Reuse existing local Dart MCP server; build safe, independently authorized public read-only MCP surface before any personal/write capability | P0 audit / P1 pilot | Cross-user RLS/authorization tests; no service-role key exposure; real production evidence; per-tool quotas |
| Voluntary support | Hosted checkout with one-time and optional recurring support | P1 | Legal/tax language, verified payment webhooks, refund/support process |
| Marketing measurement | Search Console + approved privacy-safe acquisition events | P1 | Consent, eligibility, retention, deployment gates; no behavioral tracking of minors |
| Direct sponsorships | Human-reviewed, fixed placement on public adult-oriented discovery content | P2 | Sponsor policy, disclosure, age/context gates, no influence on results |
| Affiliate partnerships | Sparse, useful links only; ranking independent of commission | P2 | Clear nearby FTC-style disclosure; destination/quality review |
| Display ads / AdSense | **Build dark** on public pages only; activation is optional and separately gated | P3 | Audience, legal/consent, measurable economics, UX and network-policy review |
| Paid acquisition / Google Ads | **Build spend-capped tooling dark**; owner spends $0 by default | P3 | Verified activation/funnel/retention, explicit owner spend cap, positive economics |
| Creator marketplace / premium services | **Build approved capabilities dark** in future phases; not required to sustain initial app | Future | Separate product, licensing, tax, payments and moderation design |

**Build-versus-launch rule for every row:** The implementation and its disabled-state tests may be merged without enabling production behavior. Every risky/new capability remains OFF unless the specific enablement gate is verified and an authorized owner activates it. Dark means no network/script/model/paid-side-effect/startup overhead. Retain §17's prohibitions: "build everything" is not permission to add harmful features.

---

## 1. Non-negotiable user-experience rules

### Allowed by default

- A small **Support LearningApp** entry under About, Settings, Help, or a public footer; user-initiated only.
- Clear public **Sponsored** resource cards or sponsor acknowledgments in eligible discovery contexts, subject to approval and caps.
- Clear nearby disclosure for a specific educational affiliate link.
- A user-initiated **Use my AI provider / Manage API key** setting, with transparent billing and security implications.
- A secondary **Connect your AI assistant** help/settings option with capability, data-sharing, and cost disclosures; never a mandatory onboarding step or fourth primary navigation destination.
- Optional, dismissible first-party product announcements **only if materially useful** (e.g., a course relevant to an explicitly chosen learning goal), without aggressive animations.

### Disallowed

- Interstitials, forced video ads, audio ads, autoplay, ad-based unlocks, rewarded ads, popups, sticky overlays, floating ads, dark patterns, countdowns, ad refresh loops, or notification spam.
- Any ad on active study/exam/simulation screens or progress reporting.
- Sponsored answers masquerading as expert explanations, paid manipulation of readiness scores, or commercial influence over source trust/official-vs-community status.
- Unmarked affiliate results, paid recommendations shown as the best academic choice, sale of personal learning information, or retargeting based on exam scores, grades, disabilities, age, private questions or learning struggles.
- Monetization that changes the locked Learn / Library / Progress navigation baseline without an approved architecture change.
- Advertisement scripts injected into lesson iframes, simulations, sandboxed resources, or offline study.

### Ad inventory boundaries

| Context | Sponsor / affiliate | Third-party ad network | Rationale |
|---|---|---|---|
| Public marketing / goal overview (adults, verified policy eligibility) | A discreet sponsor acknowledgement may be acceptable | Conditional, one reserved slot at most in a later test | Discovery, not learning execution |
| Public informational articles / comparisons | Relevant labeled sponsorship or affiliate link | Conditional later | User can distinguish commercial material |
| Public catalog result pages | Only separately labeled secondary cards; never rank boosts | Initially no | Search quality and fair routing |
| Learn home, Library app, Progress | No | No | Core UX should remain neutral |
| Lessons, assessments, simulations, flashcards | No | No | No disruption of cognitive focus or measurement |
| Minor, child-directed, school or unresolved-age contexts | No commercial placement by default | No | Privacy, safety, legal and trust risks |
| User-created content / private dashboards / external embeds | No | No | Privacy, consent and editorial control |

**Default sponsor density:** zero. If eventually enabled on eligible pages, one clearly labeled placement per page, below the primary task and never adjacent to assessment answers or critical navigation. These are LearningApp's voluntary UX caps, not a claim of legal sufficiency.

---

## 2. Source-grounded codebase audit (November 10, 2026)

This is a **targeted review of repository files**, not a full production audit. Existing documents can describe proposed or previously merged work; actual server deployment, domain access and analytics activation were not verified.

### 2.1 Existing strengths to reuse

- **Flutter PWA, Supabase, Firebase Hosting, Riverpod and GoRouter** are established. Navigation is locked to Learn / Library / Progress; changes belong in existing utility surfaces, not new tabs.
- **BYOK already exists:** `lib/services/ai/byok_provider.dart`, `lib/services/ai/llm_client.dart`, and `lib/widgets/ai/byok_settings_dialog.dart` support Gemini, OpenRouter, OpenAI and mock mode. This is **not a greenfield feature**.
- **A local MCP prototype already exists:** `tool/mcp_server/` (Dart stdio JSON-RPC implementation, tools/resources/prompts and setup guidance), including `search_catalog`, `get_target_outline`, `get_learner_state`, `get_due_items`, `explain_item`, `submit_review`, `validate_lesson`, and `propose_item_fix`. Its README identifies Claude/Cursor/ChatGPT use cases; this is **not proof of a deployed public remote service or tested host compatibility**.
- **SEO scaffolding exists:** `web/robots.txt`, `web/sitemap.xml`, `lib/services/community/seo_metadata_service.dart` and curated FAQ metadata. The community roadmap already acknowledges Flutter canvas/SPA indexing limits and recommends dedicated crawlable public pages.
- **Privacy-conscious analytics exist in code:** `lib/services/analytics/product_analytics_service.dart` defaults to disabled/no-op. `docs/analytics/ANA_102_PRIVATE_EVENT_PIPELINE.md` describes PR #212's private event storage and admin overview. This remains **not equivalent to verified live collection**; consent, adult/school eligibility, retention execution and guarded deployment are explicit gates.
- **Creator/community architecture exists:** `docs/product/COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md` anticipates reviewed contributions and eventual marketplace features. Monetization must reuse trust/provenance vocabulary rather than create competing ranking authority.
- **Cost and observability patterns** already exist and should be expanded for revenue, rather than installing an expensive SaaS analytics suite.
- **Two different feature-flag implementations exist, neither a site-wide production control plane.** `FeatureFlagsCore` (`packages/learning_core/lib/src/models/brand_config_core.dart`) defines eight named flags and `customFlags`, defaulting to true. The supplied read-only `8fe54cb` audit did not identify consumers of these values outside the model/tests, despite `lib/config/brand_config.dart` exposing them; **FLAG-001 must confirm with a complete consumer audit before treating them as functional.**
- **TEL has a distinct, actively consumed flag system.** `TelFeatureFlags` (`lib/models/learning_strategy.dart`) defines `overviewEnabled` and `fastEnabled` (default true) and target allowlists. `telFeatureFlagsProvider` exposes a code-default `StateProvider` that is not sourced from a server or operator config. The reported `isFastEnabledForTarget` implementation permits any exam target when `isExamTarget` defaults true, potentially bypassing the intended slug allowlist; reproduce this in a failing test and correct under **FLAG-012** rather than silently changing behavior.
- **Admin and analytics foundations are reusable.** `public.is_admin()` is defined via the October 17 moderation migration, and the Cost & Observability governance console links to `/admin/analytics`. Add `/admin/features` as a sibling, not a new learner tab. The separate `analytics.product_release_gate` remains authoritative for privacy approval and collection; the unified registry must not override it.

### 2.2 Specific gaps and risks discovered

| Finding | Evidence | Proposed fix | Severity |
|---|---|---|---|
| Browser BYOK keys persist as JSON in SharedPreferences | `ByokConfig.toJson()` includes `apiKey`; `ByokStorageService.saveConfig()` writes JSON to preferences | Stop promoting persistent browser-key mode until reviewed; provide secure, revocable design | P0 security |
| AI calls are client-side, including Gemini API key in URL query | `GeminiLlmClient`, `OpenAiCompatibleLlmClient` | Evaluate backend mediation / short-lived sessions / sanctioned provider auth; avoid logs and query-string secrets | P0 security |
| Arbitrary custom API endpoint can be configured | `customEndpoint` in BYOK model/dialog | Allowlist or explicitly isolated expert mode; prohibit accidental credential exfiltration to untrusted hosts | P0 security |
| API failure strings may include upstream response body | `LlmException('... ${response.body}')`, dialog displays exception | Redact secrets, user content and raw provider bodies from UI/logs | P0 security |
| Current Hosting CSP appears to allow `connect-src` only self + Supabase, not listed external LLM APIs | `firebase.json` | Validate effective deployed headers and browser tests before assuming BYOK works in production; don't broadly weaken CSP | P0 compatibility |
| Public URLs point to one Flutter index file by catch-all rewrite | `firebase.json` rewrite to `/index.html`; basic head in `web/index.html` | Route actual public content to independently rendered HTML; leave app at its normal route/origin | P0 SEO |
| Static sitemap lists only a few canonical/example FAQ URLs | `web/sitemap.xml` | Generate from actually published, accessible canonical pages; avoid unverified/fake pages | P0 SEO |
| `robots.txt` attempts `Disallow: /#/moderation` etc. | `web/robots.txt` | Hash fragments are not sent in HTTP crawler requests; protect private data by auth/RLS/noindex and real paths, not hash-based robots rules | P0 privacy/SEO |
| `QAPage` schema is emitted for curated seed FAQs | `SeoMetadataService.generateQaPageJsonLd` | **Do not use QAPage on one-answer editorial FAQs without genuine user-submitted alternatives**; use suitable WebPage/Article markup, and allow QAPage only when actual user answer submission is available and eligibility is reviewed | P0 schema quality |
| No verified dedicated donation, sponsorship or display-ad implementation identified in targeted search | Targeted default-branch searches | Build small modular services instead of inserting ad tech across the app | P1/P2 |
| Existing MCP server is a local CLI with optional Supabase credentials, including service-role key support; tools accept caller-supplied `user_id`, can expose correct answers, and readiness code can produce synthetic fallbacks | `tool/mcp_server/bin/learningapp_mcp.dart`, `src/mcp_tools.dart`, `src/learning_data_source.dart`, `tool/mcp_server/README.md` | Treat as developer-only until reviewed; separate production remote implementation, user-bound auth, no privileged client keys, answer-bank isolation and no simulated evidence | **P0 security/accuracy** |

**Deployment caution:** This review did not perform a live browser/network audit of `app.learningapp.io` (nor a production Supabase inspection). This does **not** prove it is down. Validate DNS, deployment, HTTP response body, indexability and canonical domains in a real browser before making launch claims.

---

## 3. Growth positioning and audiences

### Brand promise

> **Know your goal. Find what works. Fill your gaps. Prove your progress.**

LearningApp should present itself as a practical learning navigator, not merely an AI-generated course site. The strongest differentiators are:

1. **Goal-to-path:** Explain what the learner must accomplish, what rules/requirements apply, where the best available materials are, how to sequence them, and what they cost.
2. **External-resource intelligence:** Evaluate YouTube, Coursera, public resources, official sources, textbooks, trade materials and third-party courses without requiring copying/hosting all their content. Respect terms and copyright.
3. **Gap completion:** Add original explanations, accessible material, simulations, tutoring/community help, practice and feedback when existing resources fall short.
4. **Evidence-based verification:** Determine weak areas and readiness using honest practice/diagnostics and clear provenance, not clicks or watch time.
5. **Practical affordability:** Compare legitimate education paths, free alternatives, tests, licensing fees, scheduling and credential steps. No hidden commercial preference.

### Initial discovery segments

**Segment A — Exam and college-credit learners:** CLEP psychology and algebra, GED, study plans and practice gaps. Messaging: *know what is covered and whether you are ready.* Never suggest official endorsement by exam bodies.

**Segment B — Career/trade credential learners:** HVAC, EPA certification, OSHA/safety, real estate, contractor and other state-specific pathways. Messaging: *see valid requirements, trustworthy sources, cost-efficient next steps and practice.* Display location/date/version where material.

**Segment C — Adult foundational learning:** literacy, civics, practical life skills, accessible reading and oral practice. Messaging: *usable, patient, accessible learning without pressure*. Keep entirely ad-free where vulnerable contexts warrant it.

**Segment D — Guardians, children and school settings:** Potential long-term value, but commercial/analytics policies must remain default-deny until legal and product suitability is established. No targeted promotions to minors.

**Recommendation:** Begin organic growth with 2–3 demonstrably useful segments where content and test evidence already exist. Do not publish thousands of empty career pages just because the taxonomy contains many nodes.

---

## 4. SEO and public acquisition architecture — highest-leverage engineering

### Architecture

**Proposed split, not a forced full app rewrite:**

- `www.learningapp.io` (or another chosen canonical public domain): **Astro static pages** or equivalent lightweight SSR/static layer with semantic HTML, crawlable navigation, canonical URLs, Open Graph metadata, XML sitemap, robots, lightweight assets and a few server-side endpoints only if necessary.
- `app.learningapp.io`: existing Flutter PWA; preserve current app routing, accessibility, offline behavior and core UX.
- Both may read **reviewed, public, non-personal** catalog snapshots through a controlled build/export or read-only public API. Private learning history, draft questions, school data and protected assessment items are never exported.
- Deep links from public pages to real app destinations (goal, diagnostic, content, resource) with a graceful unauthenticated path.
- Can be hosted alongside existing Firebase static serving where feasible, with explicit rewrite precedence; alternatives may be evaluated for total cost, CSP and deploy simplicity. **Do not buy a new hosting service before confirming a real need.**

### Public templates to build

| Template | Value to searcher | Example (editorial, not necessarily a live URL) |
|---|---|---|
| Goal/career route | Requirements, steps, budget, source links, next action | How to become EPA Section 608 certified |
| Exam blueprint | Official domain coverage, version dates, resources and readiness checks | CLEP Introductory Psychology study roadmap |
| Resource comparison | Comparison methodology, free/paid options, quality evidence, price and license disclosure | Best free alternatives for a specific learning goal |
| Gap/diagnostic explainer | Show which skills need checking and sample original practice | Check your algebra gaps before enrolling |
| Practical tool | User-initiated transparent computation | Compare exam-credit cost against course alternatives |
| Reviewed topic Q&A | Real answer with citations and optional discussion | One scoped, curated question with trustworthy answer |
| Product landing / about | What LearningApp does, benefits, privacy and signup/open app | Learn, verify, and choose what to study |

### Technical acceptance criteria

- Each indexable URL returns actual useful **HTML in the initial response**, HTTP `200`, unique title/meta description/H1, canonical and helpful internal links **without requiring Flutter hydration**.
- Missing/removed content returns `404`/`410`, not app-shell `200`; redirects preserve canonicals.
- Sitemap generated from **published and accessible** content, updated on publish/depublish; `lastmod` only when genuinely changed; Search Console verified and sitemap submitted.
- Private draft, pending community review, account, admin, answer-bank and learner pages are not indexable; authorization and RLS remain the real protection, not robots.txt.
- Source provenance and review/freshness dates are visible; sourced facts must be supported, with jurisdiction/version where relevant.
- Schema.org uses `Organization`/`WebSite`, `BreadcrumbList`, `SoftwareApplication`, and editorial `WebPage`/`Article` as appropriate. `Course` only if the actual page qualifies for the specific Google feature. **Do not label fixed curated FAQs `QAPage` merely because a seed has an accepted answer:** Google requires a real way for users to submit alternative answers. Ordinary FAQ rich results were retired in Google Search in May 2026; schema does not guarantee special display. No fabricated testimonials, reviews, ratings, prices or course attributes.
- **Course Info** rich-result support was retired in 2025; do not confuse it with the separate **Course List** structured data feature still documented by Google. Verify eligibility before adding either.
- Social sharing cards and previews render for non-JavaScript crawlers; no private content in preview snippets.
- Accessibility: readable semantic HTML, keyboard/focus flow, language tag, contrast, alt text, mobile-first, low bandwidth.
- Search Console impressions/clicks/indexing and Bing Webmaster Tools are used to diagnose actual demand. SEO rank promises are not made.
- No SEO-only doorway pages, scraped article farms, unreviewed AI-generated bulk pages or misleading “free exam” claims.

**Content quality gate:** Publish a page only if it adds unique utility such as an official requirement map, better comparison, original practice, actionable cost information, corrected source gaps, or transparent quality assessment. A 10-page excellent launch is preferable to 10,000 thin taxonomy pages.

---

## 5. Voluntary contributions / supporter flow

### Recommended product behavior

- Put **Support LearningApp** in About, Help, Settings and the public footer. Do not put it into lesson completion, error states, quiz results or every app visit.
- Show a brief statement: “LearningApp is built to make effective learning easier to access. Optional support helps cover hosting, accessibility improvements and ongoing maintenance.”
- Provide suggested one-time amounts such as **$5 / $10 / $25 / custom**, with a lower amount if processing economics and user research support it. Optional recurring support may be **$3 / $5 / $10 monthly**. These are **design proposals**, not established prices.
- Checkout opens a **hosted payment page**; no card data entered in Flutter. Favor Stripe Payment Links/Checkout as a first evaluation because it can avoid custom payment UI, subject to merchant availability and fees. Evaluate PayPal second if audience/payment preferences justify it.
- No paywall, no “supporter advantage” in learning evidence, no thank-you popup after every purchase. Optional receipt/thank-you page only after a verified payment; cancellation and billing controls easy to find.
- Admin sees verified gross, fees, net, refund/chargeback and recurring status; audit and export supported. Payment provider webhooks signed and idempotent; never trust front-end redirect or client callback as proof of payment.
- Protect against minors making unsupported payments; define a guardian/age eligibility policy and service support flow before launch.

### Legal and accounting language

Use **“Support LearningApp”**, **“voluntary contribution”** or **“tip”** rather than claiming a tax-deductible charitable gift. **Unless a legally eligible charitable entity receives it**, do **not** call it tax-deductible or represent LearningApp as a charity. Legal entity, terms, tax treatment, refund policy, sales-tax implications and merchant-account name need review before accepting funds.

An unrelated nonprofit fiscal-sponsor arrangement, forming a nonprofit, and a for-profit company simply accepting contributions have different obligations. **Google Ad Grants requires eligible nonprofit status**; do not assume an educational mission alone qualifies.

### Rough processing illustration—not a forecast

Stripe publicly lists **2.9% + $0.30** as a standard domestic-card rate at review time; actual fees may vary by product, country, international card, subscription billing and taxes. On that simple basis, a $5 one-time contribution nets approximately **$4.56** before any additional fees, refunds or platform costs. Small $1 donations lose a disproportionate share to fixed transaction charges. This is why starting suggested amounts around $5 may make sense while allowing choice.

---

## 6. BYOK and AI cost-control program — high priority, but treat key safety as P0

### What exists

The repository already offers browser-side BYOK settings for Gemini, OpenRouter and OpenAI, plus a mock client. It currently persists `apiKey` in JSON via SharedPreferences, allows a `customEndpoint`, and executes direct external API calls from the Flutter client. The settings dialog tells users keys stay in browser storage.

**Owner decision (November 10, 2026): Production BYOK must be disabled until security and provider compatibility fixes are implemented, tested and explicitly approved.** Do not offer key-entry, provider test calls, AI generation via a user key, or cached-key use to production learners during the shutdown. This is a **required action**, not a claim the currently deployed application is already disabled. Because the legacy flag is not believed to have a runtime consumer, use a narrow feature-specific hotfix and backend admission guard where applicable if the unified Feature Control Center is not ready. Preserve existing user preferences/configuration without exposing keys, silently migrating them, or deleting data; decide retention/revocation after a privacy review. Offer a truthful unavailable message and the deterministic/non-AI alternative. **Do not advertise this as a fully secure, generally production-ready feature without a separate audit.** Client-side persistence is not secret storage. Browser XSS, extensions, shared devices, malware, backup/export, raw error rendering and key reuse can cause compromise. A BYOK user pays their own provider and may incur charges outside LearningApp.

### Safer design choices to evaluate explicitly

**Option A — session-only experimental BYOK (limited):** Do not persist the key; hold it in memory only for the session, clear on logout/reload, warn clearly that browser execution cannot guarantee secrecy, and restrict to explicitly provider-supported safe workflows. *This still does not satisfy providers that prohibit exposing their secret keys to browsers; do not offer it for those providers.* Useful only as a narrow expert-mode bridge.

**Option B — recommended for ordinary public BYOK, subject to provider terms and user consent:** Use authenticated, rate-limited **server-side request mediation**. Receive a user's key only by explicit opt-in; encrypt at rest using independently managed key material/secret service if persistence is offered, or hold only ephemerally for a single authorized request. Never log or return it, never expose it to the Flutter bundle, never forward it to arbitrary destinations, and offer immediate revoke/delete. Enforce per-user requests, model and token limits, response caps, billing warnings, egress allowlist, tenant isolation and no service-role leakage. **This changes the existing “never uploaded to LearningApp backend” promise and therefore requires explicit UX, privacy and security change approval; do not silently migrate keys.**

**Option C — provider-authorized sign-in / ephemeral provider tokens:** Prefer when a provider actually supports a sanctioned, scoped end-user delegated authorization flow; verify provider terms and SDK requirements per integration, rather than claiming generic OAuth supports all LLM APIs.

### Product requirements

- Public non-AI learning pathway works with **zero API key, zero paid subscription and no platform-funded AI call**.
- A small explanation of “Use free/non-AI mode” vs “Use your own AI provider” vs any later “Platform-funded AI” option, with actual cost/limits.
- Only validated providers/models and narrowly allowed endpoint domains by default. Update obsolete default model names through a reviewed compatibility matrix; configuration test should not incur a large surprise request.
- User owns provider charges, with link to their provider's pricing and budget controls. Do not promise “free AI” because LearningApp does not charge.
- Rate limit, tokens-per-request ceiling, generation-size cap, timeout, cancellation, and fallback on API failure.
- Never include provider credentials, prompt content, private diagnoses, learner free text, or assessment secrets in analytics, support logs or crash data.
- Preserve verified grading server-side; an AI model must not bypass confidential assessment banks.
- CSP reviewed for exact approved providers or backend intermediary; never broadly add `connect-src *` to make tests pass.
- Threat-model custom endpoints, shared-device sessions, XSS, CSRF, browser extensions and user-submitted content with prompt injection before launch.
- Confirm provider usage policies for user-supplied credentials and whether direct browser calls are permitted, particularly for OpenAI.

### AI economic policy

- Use deterministic educational logic and reviewed reusable content wherever possible; call models only when useful.
- Cache *public, rights-cleared, versioned* non-personal generation output safely when appropriate, not private learner data indiscriminately.
- Prefer smaller capable models for classification, drafting and extraction where quality meets tests; reserve expensive models for justified tasks.
- Measure model-specific request volume, input/output tokens, errors, user-visible outcome and server cost **without** collecting sensitive content.
- Admin-configurable operational caps and kill switches. Provider outage must never block core study flows.

---

## 6.5 MCP interoperability and user-owned AI — add as a first-class sustainability pillar

### Business thesis and accurate cost attribution

**MCP (Model Context Protocol) is an interoperability standard, not an AI provider and not a substitute for BYOK.** LearningApp can publish safe educational capabilities as tools/resources that a compatible **external AI host** (such as a user's AI assistant or coding agent) calls. In that workflow, the external host typically performs model reasoning under *its own* subscription, enterprise allowance or separately billed API arrangement; LearningApp still pays for authentication, MCP function execution, bandwidth, datastore queries, storage, moderation, support and security operations.

This is strategically valuable for LearningApp **even without an in-app chat interface**: the learner can stay in the AI application they already use, discover the right curriculum, obtain reviewed official blueprint facts, find a learning gap, schedule useful practice, and return to LearningApp for independently evaluated evidence. This is a *distribution and retention integration*, not a reason to make LearningApp dependent on AI vendors. External assistants must never be able to invent official accreditation, assessments, certificates, verified proficiency or grades.

Distinguish these operating models explicitly:

| Model | Who supplies AI? | What LearningApp supplies | Practical cost effect |
|---|---|---|---|
| Free LearningApp without AI | None | Catalog, lessons, practice, evidence | No model inference, ordinary app costs |
| In-app BYOK | User's separately authorized API provider | LearningApp interface and orchestration | Learner generally funds inference; app still carries mediation/support costs |
| External assistant + LearningApp MCP | The compatible host, subject to **its own** account limits and billing | Safe catalog/resource/tools; later authenticated personal learning functions | Potentially avoids platform-funded inference and app-embedded AI UI; pays MCP/API ops |
| User-run local AI + MCP | The user’s device and locally operated model, if their host supports MCP and appropriate tool use | Same approved educational interface and optional learner-authorized features | No third-party inference bill for that workflow; user bears hardware/power costs, LearningApp still pays hosted tool costs |
| Platform-funded AI | LearningApp's API account | Same features plus managed inference | LearningApp pays model usage; requires hard quota and product justification |

**Optional local-model path:** Learners with capable hardware may use compatible local assistants, subject to model quality, tool-use capability and host support. This is an optional expert workflow, not a substitute for the accessible, simple default product; do not force downloads of model weights into the Flutter PWA.

**Important commercial truth:** ChatGPT subscriptions and OpenAI API billing are separate. A paid AI subscription does not mean an unlimited API key, universal access to remote MCP servers or guaranteed model calls from a third-party product. External-host connection availability, approval and usage limits vary by provider, client, account and plan. Never promise that MCP makes any particular subscription or model free.

### Present codebase: reuse, but do not ship the prototype publicly as-is

Repository `tool/mcp_server/` has a real **developer-oriented local stdio server** (the package README and Dart sources were reviewed November 10, 2026). It already implements catalog discovery, outline/blueprint queries, a learner-state shape, due items, answer explanations, review submission, lesson validation, psychometrics and moderation proposals. That is a valuable prototype and reason **not** to start the MCP design from zero.

However, existing code has publication blockers:

1. The CLI can accept `--supabase-key`, or use `SUPABASE_SERVICE_ROLE_KEY`. **Never distribute a service-role key or a user's database key as an end-user MCP client configuration.** The public remote service must enforce short-lived, user-bound access; backend secrets remain server-only.
2. Tools such as `get_learner_state`, `get_due_items`, and `submit_review` take `user_id` from model-controlled input. **Never infer authorization from such arguments.** Derive identity from a validated authenticated access token, authorize every object, and disallow cross-tenant reads/writes even when supplied IDs are forged.
3. `explain_item` can return question answers and rationales. Exclude protected summative banks, secure simulation questions, answer keys and anti-cheat-sensitive materials; a tutor tool may expose only approved formative explanations and released content.
4. The local readiness implementation can fall back to **synthetic readiness scores/weaknesses** if a live RPC is absent. This must be removed from any production-connected agent tool; return explicit `not_measured`, `unavailable` or typed errors instead. Never turn an LLM response or fabricated fallback into scored evidence.
5. Existing MCP error handling emits stack traces. Public tools need safe, redacted errors. Enforce pagination, small output limits, query budgets, request timeouts, throttling and bounded result cardinality; source data and tool results must be treated as untrusted input by external models.
6. Existing custom protocol code should be reconciled with the **2026-07-28 MCP specification**, its current SDKs and OAuth guidance. Prototype stdio examples do not establish a modern compatible remote HTTP service. The 2026 spec has evolved transport and authorization significantly. Do not design a new dependency on **MCP sampling**, which the 2026 spec deprecated, just to borrow a host model for server-side inference.

### Recommended public architecture (zero-paid-service ambition)

**A. Public read-only MCP preview (P1):** Provide only approved published reference content such as `search_catalog`, `get_target_outline`, non-sensitive official syllabus requirements, program cost checklist and vetted resource metadata. Start with unauthenticated public data if exposed, strong rate limits and no unreviewed UGC. Avoid customer account access, writes and confidential test-item disclosure. Publish a concise tool capability manifest and source/version citations.

**B. User-authorized personal MCP (P1/P2):** For personal learning state or account information, add a separate production remote MCP endpoint, *not* a publicly exposed developer CLI. Prefer existing Supabase Auth **OAuth 2.1** and properly implemented remote MCP protected-resource discovery. Supabase documents OAuth-backed MCP servers and user-bound RLS on its Edge Function stack. The server must validate JWT audience/issuer/client, execute only in the authenticated learner's context, enforce user+client-specific RLS, and ensure `client_id` restrictions are reflected in RLS or an equivalent per-tool authorization layer. Supabase's standard OIDC scopes do **not**, by themselves, restrict database table access; sensitive operations need additional server and RLS enforcement. Request minimal permissions, surface meaningful consent, and allow grants to be revoked.

**C. Explicit write-capability pilot (later):** A small subset of learner-requested state changes, only when verified server-side, with independent evidence checks, tight quotas and idempotency. Require clear confirmation for irreversible or costly writes. Never let the model self-report validated proficiency, publish content, insert graded answers directly, change pricing/entitlements, or act as an admin simply because it can call an MCP tool.

**D. Integrate without a bloated Flutter client:** Put "Connect your AI assistant" inside Settings/Help or public docs, with copyable setup instructions and a clear disconnect option. A first-class API-key configuration should remain separately labeled BYOK; do not confuse an MCP authorization token with a provider API key. No MCP SDK, ad script or AI model is required at app boot. If a user never opts into MCP, zero MCP calls should appear in their study journey.

**E. Distribution and discoverability:** Use high-quality public pages explaining supported learning tasks and showing examples (“Ask your assistant to find an approved Florida licensing pathway”; “Have your assistant retrieve which concepts you need to review”). Link to tested host-specific setup instructions. Treat third-party host/app directory listing as **conditional on approval and availability**, not a guaranteed marketing channel.

### MCP tool proposal / phases

| Capability | First public release | Later stage | Safety invariant |
|---|---|---|---|
| Catalog search, goal exploration | Yes, published-only | Improve filtering, versioned citations | No private drafts, no invented credentials |
| Official exam/career pathway facts | Yes, source-backed and current | Time-sensitive freshness and localization | Explicit provenance, effective date, no exam affiliation claims |
| Review quality of external content | Public metadata or user-submitted non-sensitive references only | Personal evaluation with permission | Copyright terms and prompt-injection defenses |
| `get_learner_state`, `get_due_items` | No | Opted-in authenticated learner only | Derive user from token; no synthetic progress; no child-account leaks |
| `submit_review` / save a practice attempt | No | Narrow user-confirmed write with genuine attempt receipt | Server verified evidence, nonce/replay protection; not AI-certified |
| Generate teaching suggestions / tutoring | The user's own assistant outside LearningApp | Optional structured suggestions via reviewed tools | Model output unverified; no answer-key exposure |
| `explain_item` for protected exams | No | Never publish confidential key content | Approved formative explanations only |
| Administrative/financial tools | No | Deliberately out of learner-facing MCP scope | No admin key, payment state writes or sponsor manipulation |

### Economics and measurement requirements

- Count **MCP active connections, approved distinct users, read-only tool calls, authenticated calls, tool error rates, median/p95 latency, bytes returned, database query cost, hosting function invocations and support burden**; privacy-review and suppress small cohorts as appropriate. Do not retain arbitrary learner prompts or external conversation transcripts.
- Keep **MCP costs separate from BYOK and platform-funded model costs**. Record model cost to LearningApp as $0 **only for calls where LearningApp actually made no paid model inference**, not as a blanket statement that MCP is free.
- Estimate an *effective avoided model spend* only if measured usage of a comparable platform-funded model is documented. It is not revenue or verified cash savings when LearningApp would not have funded that inference anyway.
- Hard cap tool output sizes, per-user request rates and budget per account; apply denial/kill switches by version or host. Reject bulk extraction and scraping. Public catalog access must not create uncapped Supabase egress or billable database work.
- Do **not** introduce MCP or an AI-provider SDK into the main Flutter startup path. Test zero idle network activity, zero additional critical-path loading and zero study-flow dependency.
- A successful integration should bring **useful learner actions and verified learning follow-through**—not simply lots of AI calls, tokens or minutes of engagement.

### Acceptance tests before public availability

1. Cross-user account-ID tampering fails at the database/RPC layer and at MCP entry. A model cannot access another learner by passing a different `user_id`.
2. No service-role, service account, admin credential or other privileged key appears in distributed configuration, tool results, logs, exception messages or client bundles.
3. Confidential exam answer keys, protected simulation questions and moderation data are inaccessible, including through indirect prompt injection and read-only tool composition.
4. Offline/failure paths return honest `not_measured` or `unavailable` rather than synthetic scores or mock data labeled as real.
5. New user authorization is explicit, audience- and client-bound; disconnect/revoke blocks future calls. Standard OIDC scopes are not falsely treated as data authorization.
6. Rate limits, pagination and budgets stop accidental infinite agent loops, tool recursion, bulk scraping and concurrent abuse without degrading the app's learner traffic.
7. Host/client compatibility is demonstrated on concrete supported versions; no claim that ChatGPT, Claude or any other host universally supports the connector for every user.
8. Performance tests show no added startup script, no extra network request for disconnected users, and predictable bounded p95 endpoint latency under limited pilot load.

**Recommended first MCP increment:** audit and secure the existing Dart tool catalog; expose a tiny published-content-only, read-only, low-cost remote endpoint; validate one real compatible external host end-to-end; only then consider an OAuth-authenticated learner-state pilot. Monetization, ads or paid API access are **not** prerequisites for this experiment.

---

## 7. Direct sponsorships — better early fit than generic ad networks

### Why direct sponsorships can work

One transparent, relevant partnership can be simpler to control and may be economically preferable to earning fractions of a cent per occasional display impression. This is a **business hypothesis**, not a guaranteed sponsorship market.

**Candidate partners:** verified credential prep providers, trade schools, bookstores, tutoring services, test prep tools, adult education programs or employers offering genuine pathways. Screen each for licensing/approval, actual relevance and student harm. Avoid payday finance, gambling, misleading accreditation, predatory courses, fake certifications, debt traps or claims of guaranteed jobs/pass rates.

**Placement:** small static cards on public goal/resource/comparison pages, placed after the useful first-party information. Clearly label “Sponsored” and the paying entity. Sponsor does not determine default ranking, verification badge or diagnostic recommendation. If a destination is educationally worse, it should not be recommended just because it pays.

**Simple implementation:** first-party reviewed metadata with sponsor ID, contract dates, approved asset, destination allowlist, topic/context scope, age restrictions, disclosable payment relationship, start/end, locale and manual admin activation. Prefer static first-party images/text, no third-party script and no pixel until a compliant opt-in architecture is approved.

**Measurement:** monthly aggregate eligible page views and sponsor-link clicks where permitted; do not profile individuals or attach study performance. Contracts can start fixed-fee; do not invent CPM or pricing benchmarks before real traffic data and sponsor discovery. Include cancellation, takedown and no-results-guarantee clauses.

**Guardrail:** exactly zero sponsors until review/contract/privacy gates pass; then maximum one per eligible public page in the pilot, with a centralized kill switch and no layout shift.

---

## 8. Affiliate partnerships — useful referrals without corrupting rankings

LearningApp's external resource recommendation capability naturally intersects with publishers and partners. It is acceptable to receive compensation from genuinely useful referrals **only if the comparison and recommendation are independently defensible**.

- Store independent quality score, suitability and provenance separately from any affiliate metadata. Affiliate rate must never enter the educational ranking algorithm.
- Show non-commission alternatives (including free and official sources) when better for the user's goal.
- Add **clear, nearby language** such as: “If you buy through this link, LearningApp may earn a commission at no additional cost to you.” Do not assume an ambiguous “affiliate link” label is enough.
- Review terms, trademark rules, pricing, disclosure, deep-link permission and actual affiliate relationship. Never suggest an affiliation with exam or credential providers that does not exist.
- Maintain an easily searchable conflict-of-interest and partner policy; log approved link changes.
- Track verified payout/refund/return, not just outbound click count.
- Avoid affiliate programs for child-directed or school pages unless specialist legal review establishes a suitable lawful approach; default is no commercial referrals.

---

## 9. Programmatic display ads — build dark, optional last-resort activation

**Build policy:** Implement and test the ability to display one reserved, controlled contextual ad slot in the **static public-page layer only**, with `marketing.display_ads` OFF by default and no third-party script loaded while OFF. This is a build commitment, **not** a commitment to run ads. **Never integrate AdSense or any generic ad network into Flutter study routes.** If enough eligible adult public traffic exists and the gates pass, consider a small measured pilot.

**Activation gates (not prerequisites for writing the disabled code):**

1. Demonstrate enough original public content and an eligible owned domain; Google AdSense has site/content approvals, not automatic eligibility just because a PWA exists.
2. Review exact Google placement rules and policies. They prohibit deceptive navigation, accidental clicks, auto-refresh and certain application contexts. **AdSense for web pages is different from AdMob for native/mobile-app use**; do not treat a Flutter web/PWA ad SDK as equivalent.
3. Resolve age/child-directed and school-account classification. **No ad SDK or identifiers for minors or unresolved-age environments by default.**
4. Resolve region-specific notice and consent. Google requires a certified CMP/TCF for relevant EEA/UK/Swiss advertising cases; choose a minimally intrusive lawful solution rather than blanket banners everywhere.
5. Use a single static public-page ad slot with reserved height, lazy loading where permitted and no popups, autoplay, scroll hijacking or promotion near navigation controls.
6. Check real-user page speed, CLS, bounce, page completion, support complaints, brand perception and realized net ad revenue. **Remove ads if UX regression or marginal revenue**.
7. Confirm published page doesn't simply aggregate or frame other people's content, which may cause AdSense content policy issues.

**Pilot enablement decision rule:** Leave the built feature OFF if plausible net revenue cannot meaningfully offset ongoing engineering, privacy/compliance and UX cost. A hypothetical 5,000 monetizable public pageviews at a $2 *page RPM* would yield just $10; that is an illustrative calculation, **not a LearningApp traffic estimate or market rate**.

---

## 10. Marketing execution: low-cost acquisition system

### Stage 1 — search and useful content

Build public paths around topics where LearningApp already has reviewed expertise, rather than generic “learn anything with AI” marketing. For each selected goal, produce:

1. An accurate goal/credential overview (official requirements, sources, versions).
2. A transparent options comparison (free and paid; financial and time trade-offs).
3. An original sample gap check/practice utility if rights, scoring and quality support it.
4. A clear next step: **Build my plan**, **Check what I know**, or **Find the best resource** — never force account signup just to read the page.
5. A sensible post-click path to the Flutter app and, where appropriate, back to useful external content.

### Stage 2 — trust and partner distribution

- Publish original, genuinely useful reference guides in community-relevant discussion spaces **only when welcome**, not spam or covert promotion.
- Reach adult-ed educators, librarians, career counselors, credible teachers, trade groups and career/college-prep communities with a concise explanation and usable links.
- Offer freely usable, attribution-friendly widgets or public resources (subject to licensing) that educators can share.
- Collect consented learner feedback on **outcomes**, not just engagement, and publish accurate case studies only with permission and appropriate privacy.
- Produce short demonstrations showing an actual end-to-end task: locate the right credential path, select a free source, close a gap, verify readiness.
- Establish an identifiable contact, About page, author/reviewer credentials, editorial/source update policy and a simple press/partner page.

### Stage 3 — referral mechanics without growth manipulation

- One-tap copy/share of a **public, non-personal goal page**, not grades, history, private weak areas or credentials.
- Optional learner-controlled shareable plan summary only after explicit privacy review and consent, with expiry/unlisting and revoke.
- Deep-link return-to-app after external resources, but never misrepresent third-party watch/completion data as observed.
- Avoid referral rewards that pressure students to promote the app or send spam.

### Stage 4 — paid acquisition only after proof

Start **$0 ad spend**. When there is evidence of eligible adult activation/retention and a durable conversion path, the owner may authorize a small, **fixed, stop-loss** campaign to a focused goal page (for example, adult CLEP or HVAC). Prioritize intent-based search over broad display, retargeting or aggressive video ads. Measure *qualified starts and useful outcomes*, not raw app installs or pageviews.

Before any campaign: legal ad policies, appropriate claims, mobile performance, landing-page relevance, negative keyword list, regional scope, per-day and total cap, conversion definition, consent/measurement design and cancellation plan. No paid campaign until the owner explicitly approves spend.

---

## 11. Financial model and admin capability

### What to track monthly

**Operating costs** (verify with actual invoices and metered usage): hosting/bandwidth, Supabase/Postgres/Auth/storage, domain, monitoring/security, provider-funded AI tokens/audio/media, **MCP hosting/function invocations, tool queries, network egress and support**, payment processor, content/source review and professional/legal costs. Record accrued commitments, hard limits and alerts.

**Revenue**: one-time/recurring support actually paid, direct sponsorship receipts, confirmed affiliate payout, any later paid services; subtract processor charges, refunds, chargebacks, partner commissions and taxes when applicable. Do not count a donation pledge, click, invoice draft or Stripe redirect as received funds.

**Core dashboard**:

| Metric | Definition | Source of truth |
|---|---|---|
| Verified support revenue | Settled payments less reversals and fees | Signed payment webhooks + reconciled provider ledger |
| Sponsor recognized revenue | Earned/received per signed agreement | Agreement + invoices + bank/payment reconciliation |
| Verified affiliate revenue | Payouts accepted less reversals | Partner statement/payout ledger |
| Direct cash operating cost | Actual paid recurring and usage charges | Provider invoices + bank reconciliation |
| Monthly net cash contribution | Net received revenue minus actual cash operating costs | Reconciled finance ledger |
| Cost per qualified learner outcome | Eligible operating cost / verified successes; mark unavailable without reliable denominator | Cost ledger + authorized learning evidence |
| Organic search acquisition | Impressions, clicks, landing paths | Search Console and lawful aggregate acquisition metrics |
| Content-to-useful-action conversion | Public page leads to relevant action (not just signup) | Approved, privacy-safe product events |
| Effective public ad revenue | Net ad receipts / eligible pageviews × 1,000 | Ad network reconciliation + verified eligible pageviews |
| MCP operational cost / active authorized user | Actual MCP-specific usage cost / measured authorized MCP users | Bounded platform telemetry + provider bill; only when privacy/consent allows |
| Platform-funded model cost per useful outcome | Verified app-funded model spend / valid outcomes | Provider billing + independently verified learning/outcome evidence |

### Illustrative scenarios, not forecasts

- **Support-first:** 25 contributors giving $5 each in a month means $125 gross and about **$113.88** after *only* a hypothetical 2.9% + $0.30 card fee per transaction. Other fees/taxes may apply.
- **One direct sponsor:** a negotiated fixed monthly payment may cover a meaningful share of a small hosting bill even when display ads don't; **do not assume any sponsor will pay or what a fair rate is**.
- **Ads-first:** small public traffic usually does not justify third-party script, consent and support overhead. Model page RPM with a low/base/high range only after actual compliant eligible-page traffic is known.

**Break-even calculation:** `monthly cash sustainability = verified net revenue - actual monthly cash operating cost` (target ≥ 0). Track annualized maintenance, legal, and founder time as separate disclosures; cash break-even does not mean the founder's work is fairly compensated.

**Sustainability target:** Cover essential platform costs first, then build a reserve (for example, 3–6 months of known recurring cash costs if cash flow allows), and only then consider growth spending. No one should confuse optional support and sponsor estimates with reliable funding.

### Recommended administrative modules

- Existing Cost & Observability area gains **Revenue & Sustainability** (admin-only; not a learner tab).
- The same area gains **Feature Control Center** at `/admin/features`: searchable switches, effective states, dependencies, emergency shutdown, staged releases, audit and explicit recovery checks. See §20.
- Components: cost by service, verified payments, net monthly runway, sponsor contract roster/status, partner payouts, marketing funnel health, SEO Search Console summary, privacy/consent coverage, and experiment kill switches.
- Distinguish `verified`, `estimated`, `missing`, `suppressed`, `pending provider settlement`, and `not deployed`; never convert unavailable into zero.
- RLS and role checks on the backend, no banking credentials or gateway secrets in Flutter, smallest viable data scope, no private learner text in ledgers.

---

## 12. Measurement, privacy, accessibility and compliance

### Reuse existing analytics correctly

- PR #212's private product analytics is not automatically on: preserve **default-deny**, adult/school eligibility checks, explicit opt-in, bounded event properties, small-cohort suppression and privacy/retention gates.
- Search Console is a lower-complexity first source for organic discovery; no need for third-party invasive tracking scripts.
- A partner click or outbound video open is **not proof** of course consumption or learning success.
- Attribute campaigns using simple scoped UTMs and opt-in/aggregate metrics; avoid collecting raw search texts, grades, diagnosis, learner prompts or private resource URLs in commercial analytics.
- For payment conversion, rely on signed backend provider events, deduplication, reconciliation, retention policy and minimal user identifiers.

### Rules to review with qualified counsel before commercialization

- **COPPA and child-directed/under-13 products:** FTC guidance emphasizes control of advertising vendors and persistent identifiers, with additional parental consent obligations where applicable. The 2025 amended rule increases protections around disclosures for targeted advertising. Default to **no targeted ads and no commercial tracking for minors**.
- **School/educational records:** establish suitability and obligations for any school-managed accounts, and review FERPA/contract rules as applicable before promoting school deployment or commercial referrals.
- **FTC endorsements:** affiliate/sponsored relationships need prominent, understandable disclosure near the relevant claim or link, not just a buried legal page.
- **Google ads consent:** region-specific CMP/TCF requirements can apply in EEA, UK and Switzerland. Consent UI needs a legal review, accessible equal options and no dark patterns.
- **Privacy notice:** update before collecting new commercial tracking or processing payment identifiers, and explain changes in BYOK server processing if chosen.
- **Nonprofit/tax status:** only qualified organizations are eligible for deductible charitable contributions and nonprofit ad grants. Do not assume LearningApp qualifies.
- **Content rights and brand claims:** external resource licenses, embedded content permission, exam trademarks, claims of official endorsement, sponsor claims and learning-outcome promises need review.

### Accessibility and trust

- All support controls work with keyboard/screen reader and do not obstruct core functionality.
- Never block accessible learning features behind a donation.
- Sponsor disclosures plainly readable; no low-contrast tiny disclaimers.
- Prefer users' real needs and independent learning outcomes over dark patterns, streak pressure or retention metrics as a target in themselves.

---

## 13. Performance budgets and mandatory test gates

### Engineering performance invariants

1. **No new third-party ad, marketing or donation JavaScript at Flutter app boot.** Hosted contributions use deliberate navigations.
2. **No monetization network requests on lesson/quiz/simulation/Progress routes**, including during idle and focus modes.
3. Sponsor cards on public pages use first-party static assets, bounded dimensions, native links and no third-party beacons.
4. On approved public pages, benchmark p75 **LCP ≤ 2.5s**, **INP ≤ 200ms**, **CLS ≤ 0.1** on real-user field samples, segmented mobile/desktop. These are Google's Core Web Vitals thresholds; budget for no degradation from sponsor features.
5. Every significant optional feature has a documented independent emergency kill switch, route/backend enforcement, relevant eligibility restrictions and a safe disabled path. Fail safe for security, privacy and paid side effects; preserve unaffected learning, and never falsely claim data was saved. See §20.
6. Never slow a page waiting for analytics, ad approval, payment reconciliation, sponsor metadata or an external resource provider.
7. Test on slow mobile devices, throttled network, offline state, screen reader, ad blocker, consent refusal, signed-out user and minified production build.
8. CSP stays least-privilege. Changes to connect/script/frame sources require an explicit review of the domain, key exposure and sandbox boundary.
9. Performance validation runs against before/after baselines with reproducible Lighthouse/Playwright and actual metrics; no claimed pass until tests execute.

### Automated checks to add

- Public SEO route returns semantic HTML, correct status/canonical/meta, safe schema, no private data and valid sitemap inclusion only when published.
- Unsupported/ineligible QAPage or Course schema rejected by content lint.
- Robots rules tested, but RLS/auth tests prove private content inaccessible independently of robots.
- Support/sponsor not rendered in core learning areas or underage/unresolved-age contexts.
- Sponsor disclosure always visible when sponsor appears; sponsor cannot alter organic order.
- Affiliate link and nearby disclosure are paired; disclose brand/compensation and use correct `rel` attributes where required.
- Payment webhook signature, replay safety, refunds, idempotence and role isolation.
- BYOK key is never logged, present in URL where avoidable, serialized to unapproved browser persistence, sent to arbitrary endpoint, or included in telemetry; reject unsafe inputs.
- No added startup JS/network requests to core app, and no layout shift from sponsor slot.

---

## 14. Prioritized implementation program

### Phase 0 — Audit, decisions and safety baseline (0 spend, first)

**NEW P0 dependency:** Before enabling broad commercialization, remote MCP or new significant production features, complete FLAG-001 through FLAG-004 in §20: inventory, registry, trusted backend gates and direct-call enforcement. The admin panel is P1, but a generic toggler that cannot stop backend work does not qualify as operational control.

**MKT-001 — Current deployment and unit cost inventory (P0).** Inspect actual production domain response and Search Console state; map hosting/CSP/routes; verify live expense baselines and revenue absence. No assumptions from historical documents.

**MKT-002 — BYOK production disable, security remediation spec and fix (P0).** First block user-key entry, test/inference calls and cached-key invocation for **all production users**, verify via an off-path and direct-request negative test, and show a concise unavailable state. **Disabling does not automatically erase locally stored user keys:** provide a safe local-clear path and advice to rotate any potentially exposed keys; do not upload, log or silently migrate them. Where the unified registry does not yet exist, deliver a narrowly scoped code/config hotfix without waiting for FLAG-005. Then threat-model `byok_provider.dart`, `llm_client.dart`, settings UI, CSP, shared devices, external domains and error redaction. Choose an approved mode, align privacy promise, prove provider compatibility, add negative tests. **Do not silently migrate raw browser keys to a server.**

**MKT-002B — MCP threat model and capability audit (P0).** Inventory `tool/mcp_server` tools, caller-supplied identifiers, privileged Supabase credential flows, confidential answer exposure, synthetic readiness fallbacks, output/error handling and protocol compatibility. Mark every tool `public_read`, `authenticated_read`, `conditional_write` or `never_external`; block public launch until risk tests are green.

**MKT-003 — Public SEO architecture decision (P0).** Reuse existing catalog export and provenance. Evaluate static Astro vs equivalent SSR and Cloudflare Workers static assets versus Pages/Firebase, using total cost, quotas, rollback, and hosting simplicity. Cloudflare currently recommends Workers for new projects, but **do not migrate the existing Flutter app without evidence**. Preserve Flutter nav and deep links.

**MKT-004 — Monetization policy / eligibility (P0).** Decide legal payee, allowed age contexts, ad-free surface whitelist, sponsor categories, affiliate disclosure, data retention and approval responsibilities. Public-facing policy reviewed before money changes hands.

**Phase 0 exit:** Evidence-backed deployment audit; **BYOK confirmed unavailable in production** until all remedial verification gates pass; approved SEO architecture; explicit owner sign-off on payments and commercial policy. Re-enabling BYOK is a separate later authorization, not an automatic consequence of merging a fix.

### Phase 1 — Organic discovery and optional support (prioritize before ads)

**NEW P1 item:** FLAG-005 through FLAG-008 in §20 deliver `/admin/features`, lightweight runtime snapshots, real kill-switch tests and the disable/re-enable drill. No commercial or risky feature should depend on untested toggle-only UI.

**MKT-101 — SEO public frontend (P1).** Launch a small number of genuinely useful goal/exam/resource pages with real HTML; canonical URLs, sitemap/robots, Search Console verification, Open Graph and appropriate schema. **Add negative tests prohibiting static seeded FAQs from claiming QAPage eligibility** unless the real page permits alternate user-submitted answers. Respect published-only export.

**MKT-102 — Editorial content pipeline (P1).** Reviewed goal templates, source dates, cost comparison and content quality lint; open app/deep link, external-resource handoff and return-to-practice flows. Avoid mass-generated filler.

**MKT-103 — Voluntary support checkout (P1).** Minimal first-party link to vetted hosted payment page, no in-app SDK, no prompts in study; signed webhook + verified admin ledger + cancellation/refund support.

**MKT-105 — MCP public read-only pilot (P1).** Reuse source-backed catalog metadata to expose a small hosted, no-model-inference MCP endpoint; publish capability setup docs; rate-limit, meter and compatibility-test one external AI host. Strictly no privileged keys, private learner data, confidential bank answers, writes, fabricated evidence or required app startup code.

**MKT-104 — Private conversion model (P1).** Extend existing opt-in analytics only after deployment/privacy gates; supplement Search Console, not replace it. **Do not silently widen collection or bypass `analytics.product_release_gate` through generic feature flags.** Track useful user actions where lawfully available, not only site traffic.

**Phase 1 exit:** Crawlable real public pages, stable no-ad Flutter app, support payment reconciliation, baseline organic funnel with honest measurement and no unapproved data collection.

### Phase 2 — Build partnerships and authenticated MCP dark; enable on gate

**MKT-201 — Sponsor review and creative registry (P2).** Build and merge dark with `marketing.sponsor_cards=OFF`: first-party admin approval, context allowlist, sponsor dates, disclosure, no rank manipulation, age/region controls, kill switch. Enable after its own disclosure/policy gates.

**MKT-202 — Affiliate metadata and policy (P2).** Build and merge dark with `marketing.affiliate_links=OFF`: editorial ranking independence, link disclosure and payout reconciliation. Enable only after review where the learner benefits.

**MKT-203 — Outreach toolkits (P2).** Build shareable guides, educator/partner resources, reference pages, press/contact assets and opt-in feedback; keep optional distribution/automation inactive until approved. No automated spam outreach.

**MKT-205 — OAuth learner MCP pilot (P2).** After the published-only pilot, build and merge scoped, revoked, user-derived authenticated tools **dark** (`ai.external_mcp`, `mcp.remote`, `mcp.personal_read` OFF), with Supabase Auth OAuth 2.1/RLS and positive/negative cross-user tests; keep writes separately gated. Enable only after security and host-compatibility gates. Document connection support per host and avoid coercive consent.

**MKT-204 — Business dashboard (P2).** Build and merge the optional, access-controlled module dark within admin Cost & Observability: verified revenues, operating costs, sustainable cash coverage and sponsor/partner performance. Reveal only after authoritative payment/source reconciliation is verified.

**Phase 2 build exit:** MKT-201 through MKT-205 merged with default-OFF or suitably bounded admin-only states, zero dormant overhead and passing off-path tests. **Activation exit:** each independently passes the existing legal, quality, security and economics gates; no monetization contamination of study.

### Phase 3 — Build dark, spend-capped; experimental activation only after gates

**MKT-301 — Public display ad pilot (P3).** Build a single reserved public-page slot dark, with `marketing.display_ads=OFF`, zero loaded ad script while OFF and manual shutdown. Enable only after sufficient eligible adult traffic, network/account/consent approval and page-quality/UX checks.

**MKT-302 — Paid search acquisition (P3).** Build campaign-preparation/reporting tooling dark, with `marketing.paid_acquisition=OFF` and **no live advertiser API credentials or active campaigns by default**. A server-enforced `max_spend=0` can protect *LearningApp-initiated* purchases, but **cannot stop spending from a separately enabled Google Ads or other advertiser account**; require provider-side paused campaigns, hard account/campaign budgets, billing review and explicit owner approval as independent controls. No behavioral targeting of vulnerable learners or minors.

**MKT-303 — Optional managed AI plan (P3).** Build the optional managed-AI routing, quota and accounting capability dark, with `ai.managed=OFF` and **server-enforced `max_spend=0`**. Enable only if measured BYOK friction, legitimate funding, risk approvals and pricing justify it; transparent quotas and lawful payments, never fake “unlimited” promises.

**Phase 3 build exit:** MKT-301 to MKT-303 can be merged **OFF**, with zero spending and negligible dormant overhead. **Activation/retention exit:** Features stay ON only when verified incremental revenue or qualified learning outcomes outweigh cost, trust and performance impact; otherwise turn OFF in the control panel and retain their tested code/data for safe future re-enablement.

---

## 15. Development dependencies and likely file ownership

| Area | Existing relevant files / integration points | Expected work |
|---|---|---|
| BYOK | `lib/services/ai/byok_provider.dart`, `lib/services/ai/llm_client.dart`, `lib/widgets/ai/byok_settings_dialog.dart`; `firebase.json` | Security architecture + tests, provider allowlist/compatibility, hardened errors and persistence, config UX |
| MCP interoperability | `tool/mcp_server/README.md`, `bin/learningapp_mcp.dart`, `src/mcp_tools.dart`, `src/learning_data_source.dart`, `ARCHITECTURE_REVIEW.md` | Privileged-key removal from distribution, auth/RLS design, confidential-bank guard, no synthetic readiness, bounded outputs, modern spec compatibility and hosted read-only pilot |
| SEO | `web/index.html`, `web/robots.txt`, `web/sitemap.xml`, `firebase.json`, `lib/services/community/seo_metadata_service.dart` | Separate public render/export, metadata lint, canonical sitemap, hosting route handling |
| Content | `data/seed_faqs`, `docs/product/COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md`, catalog source/provenance pipeline | Publish-reviewed content snapshots only, content freshness tracking |
| Product analytics | `lib/services/analytics/product_analytics_service.dart`, `docs/analytics/ANA_102_PRIVATE_EVENT_PIPELINE.md`, PR #212 | Gated compliant activation, acquisition and meaningful action event extension |
| Support and commercial | No confirmed dedicated feature in reviewed default-branch search | Payment link + signed webhook + admin finance reconciliation; separate minor/ad contexts |
| Admin | Cost & Observability, `/admin/analytics` | New administrative sustainability module behind server-side role checks |
| Feature governance | `packages/learning_core/lib/src/models/brand_config_core.dart`, `lib/config/brand_config.dart`, `lib/screens/governance/cost_observability_screen.dart`, `docs/analytics/ANA_103_ACTIVATION_AND_RETENTION_RUNBOOK.md` | Confirm currently unwired legacy flags; typed registry, server-authoritative gates, audited change RPCs, `/admin/features`, off-path CI requirements; preserve dedicated analytics latch |
| TEL release flags | `lib/models/learning_strategy.dart`, `lib/providers/learning_strategy_provider.dart`, `lib/providers/next_action_provider.dart`, `lib/widgets/overview/` and related route consumers | Consolidate active `TelFeatureFlags`; fix/document Fast target allowlist behavior; preserve current rollout defaults until owner choice |
| Tests | Flutter tests, Supabase pgTAP, GitHub CI, browser/Lighthouse workflows | Security, page crawlability, policy, payment replay, performance and age-gate regressions |

**Source control rules:** Separate additive PRs; do not rewrite existing Supabase migrations. Production database changes require the repository's guarded migration deployment workflow and owner approval. Do not turn on collection, monetization, payment or ads merely by merging a branch.

---

## 16. Decisions to close before implementing specific money flows

The plan can proceed on SEO and hardening without these, but production monetization cannot:

1. Which legal entity owns LearningApp, receives the money and issues receipts? Is it a for-profit company or qualified nonprofit? **Unknown during this review.**
2. Which countries and age segments will be served, and are there school-operated accounts? **Requires policy review.**
3. Is the owner willing to allow users to transmit their keys to a LearningApp backend for secure mediation? A consent and privacy change is required; do not assume yes.
4. What are actual monthly costs and traffic, by service and content type? **Not measured in this review.**
5. Which public domains and hosting architecture are final? `app.learningapp.io` appears in code, but actual live deployment was not independently verified here.
6. Does the organization want voluntary recurring contributions, one-time only, or both? Default design supports both without pressure.
7. Who approves sponsor categories, school/child exclusions, affiliate conflicts and refunds? Make this an explicit administrator role before live contracts.

These are owner/operational decisions; none should block improving security, crawlability or the free study experience now.

### 16.1 Explicit owner decisions before a feature-registry migration changes existing behavior

The owner has **resolved all three decisions** in the previous v1.4 §16.1 list on November 10, 2026. These decisions govern the plan and must be recorded in the implementation ADR; they **do not confirm any production change has occurred**.

1. **TEL Fast stays available.** Preserve current effective public access to Fast Mode during migration, with no blanket move to admin/tester-only. Where technical behavior, learning effectiveness, scope or eligibility is not yet verified, display a clear, non-alarming **Experimental** label in the relevant entry/surface and admin registry. Make the limitations discoverable in Help. Preserve existing Overview availability as well unless separately reviewed; the owner explicitly mentioned **Fast**, so do not infer an Overview rollback. An experimental designation does not override legal, security, privacy, cost or verified-scoring gates.
2. **BYOK must be OFF in production until repaired.** Disable the entire user-key pathway for all production users, including existing saved configurations, key entry, test connection and inference; do not merely hide the menu. Maintain non-AI alternatives. Do not auto-enable after a merge. Re-enable only after MKT-002 evidence, provider/CSP testing, safe credential treatment, privacy-text alignment and explicit owner approval. A staging environment may run controlled synthetic tests without real learner keys.
3. **Legacy capability preservation with conditional retirement.** Audit and classify each legacy *feature and its flag*, not just whether the flag has a caller. **Retire obsolete code only when the capability is truly no longer part of the product, or when a replacement has verified functional parity and safe migration.** If a useful legacy capability has not been replaced, **retain it** even if the implementation is old, undocumented, or not exposed in current navigation; improve and flag-control it rather than delete it. Unused/duplicate **flag definitions** may be cleaned up only after proving they control no live needed behavior and have a safe replacement in the registry.

**Migration rule:** Existing useful functionality should not silently disappear when flags change from hard-coded defaults to server settings. BYOK is the one explicitly owner-approved exception requiring shutdown. New risky integrations remain OFF until independently approved. See §16.2–16.3 for verification and retirement contracts.

### 16.2 Experimental labeling and verification evidence (owner policy)

**Scope:** Any user-visible capability with a meaningful unverified claim (technical reliability, target compatibility, educational effectiveness, readiness calculation, source accuracy, accessibility, etc.) must **accurately show `Experimental`** until the specific claim is substantiated. This includes TEL Fast wherever relevant evidence remains incomplete. Do not label a whole app or safe, already verified feature experimental merely because some unrelated feature is not ready.

- **Two independent dimensions in the feature registry:** `availability` (`OFF`, `INTERNAL`, `COHORT`, `ON`) controls access; `maturity` (`EXPERIMENTAL`, `VERIFIED`, `RETIRED`) and a separate evidence ledger describe confidence. **Experimental can be ON** when lower-risk learning UX is useful and the hard safety/privacy/legality gates are satisfied. **Experimental must remain OFF** if a mandatory security, privacy, grading-integrity, billing or eligibility gate is unverified.
- **What the label means:** The feature is available but parts of its reliability, coverage or benefit have not yet been fully validated. Show a small accessible text label **Experimental**, not a full-screen warning or repeated modal; offer an optional Help explanation identifying what is and is not verified. Do not imply a learner's score or predicted readiness is official when it is not.
- **Evidence-driven graduation:** Define test/evidence requirements per feature; for Fast, include target eligibility coverage, deterministic path correctness, impact on assessment integrity, representative usability/accessibility tests, rollback behavior and any effectiveness claims being made. Record last verified date, reviewer, limitations and acceptance criteria in admin registry. Never equate passing unit tests with proven learning effectiveness.
- **No misleading status:** Use `Not verified` or `Insufficient evidence` in admin evidence fields when appropriate. Do not automatically show public `Experimental` on a feature that is **OFF**; use `Unavailable` on its disabled fallback. No made-up evidence or silent graduation.
- **Safety wins:** Experimental status is never a substitute for protection against secret exposure, invalid scoring, privacy violations, fraud or unpredictable bills. BYOK stays OFF despite having useful existing code.

### 16.3 Legacy feature retirement and no-capability-loss rule (owner policy)

Treat a legacy flag, implementation, UI entry and user capability as **different assets**. An unused flag is not proof its corresponding capability is obsolete; a feature not currently discoverable in navigation can still support imports, external integrations, offline use, accessibility or saved user data.

**Mandatory sequence before deleting any legacy feature or implementation:** (1) inventory routes, callers, data, offline flows, admin tools and users; (2) document the distinctive user capability and whether the product still needs it; (3) identify the replacement and prove **functional parity** for required workflows, including accessibility, stored data, exports, permissions and edge cases; (4) test migrations, rollback, links, saved work and interactions with current features; (5) obtain owner approval for any genuine removal or deliberate reduction in capability; (6) only then retire code/flags/schema via reviewed, reversible steps where feasible. Never drop user data merely because UI code was retired.

**Retain and maintain if:** The capability is still needed and nothing adequately replaces it, even if the old implementation is messy, unused by a new screen or hidden by a broken flag. **Remove when:** The capability is genuinely no longer part of the agreed product, or its full required function has been replaced and verified with a safe migration. **If uncertain, preserve it, document the ambiguity and postpone deletion.** Cleanup must not be used as an excuse to reduce feature coverage or learner utility.

---

## 17. What we should definitely **not** build

- A monetization engine based on forcing more app time; an education navigator can be successful even when users leave to complete a course elsewhere.
- A generalized ad placement SDK attached to Flutter widgets or lesson/simulation containers.
- Pop-ups asking for money after failure, low grades, repeated wrong answers, or emotionally vulnerable moments.
- A system that ranks paid providers as superior without independent evidence.
- A bulk AI content farm pretending to provide unique researched advice.
- Retargeting pixels or third-party tracking based on learner weaknesses or minor/school data.
- A subscription paywall for fundamental access, simply to avoid building a sustainable business.
- A custom payment-card collection interface when a hosted compliant checkout suffices.
- An elaborate ad bidding stack, customer data platform, affiliate network or marketing analytics SaaS before actual users/revenue justify it.
- Fake traction metrics, fabricated testimonials, ad-click incentives or “official partner” claims without real agreements.
- A fundraising claim that contributions are charitable tax-deductible without verified eligibility.
- Automatic deployment of code, consent collection, analytics or production migrations as a side effect of creating this plan.

---

## 18. Success criteria and business review cadence

**First 30 days after Phase 1 launch** (relative, not a deadline): verify that public pages return correct indexable HTML, Search Console can crawl, users reach useful content, support payments settle correctly if enabled, no BYOK key leakage, no unsolicited ad requests during learning, and no measured performance regression.

**At 60–90 days**: inspect which public goal pages yield qualified actions and actual learning-related follow-through; create more of what works, revise or retire pages that don't. Compare revenue vs operating cost. Seek direct partners only with credible traffic/audience data. Review what users say about interruptions—not only raw conversion rates.

**Monthly thereafter**: small owner-facing report on real operating cost, net voluntary support, confirmed partner receipts, SEO traffic, qualified outcomes, failures, privacy issues and performance. End or roll back experiments that add cost or harm the educational experience.

The success metric is **net sustainable learner benefit**, with cash break-even as a necessary supporting goal—not maximum ads, dwell time or conversion at any cost.

---

## 19. Hard $0 owner-funded operating architecture (v1.2 amendment, November 10, 2026)

**Owner constraint:** Aim for **$0 recurring out-of-pocket cash** to operate the product; preserve free core learning, SEO, contribution acceptance, optional commercial discovery, BYOK, local/external MCP, privacy-safe analytics, and the ability to enable advertising. Do not silently substitute a paid vendor for a free component. **This is a capped launch architecture, not a promise of unlimited free-scale service.** Paid advertising spend, card-processing fees, custom-domain renewal, taxes, legal services, human labor, and extra capacity cannot literally be made free by architecture.

### 19.1 Separate three financial goals

1. **Zero fixed platform subscription expense**: use free hosting/database limits, no paid model API, no premium analytics SDK, no ad-network SDK in the learning shell. Technically plausible at launch if users and workloads stay within quotas.
2. **Zero LearningApp-paid AI inference**: require the user's explicitly selected BYOK provider, local model or compatible external AI assistant as the AI inference host. **MCP by itself does not supply inference**; it exposes data/tools to a compatible client. Offer deterministic, pre-reviewed content, flashcards and practice when no model is available. Do not imply an ordinary chatbot subscription supplies unrestricted API calls.
3. **Zero owner-funded costs once growing**: only possible if net collected revenue covers necessary paid capacity. Advertisements, sponsorships and contributions are *possible revenue*, not guaranteed revenue. Operational expenses can exist even when paid from revenue rather than the owner's money.

### 19.2 Strict-zero deployment option

| Capability | First implementation | Hard $0 condition | If free limit is reached |
|---|---|---|---|
| Public website and Flutter PWA | Pre-rendered HTML + Flutter static assets on Cloudflare Pages/Workers | Static asset delivery only; use free included deployment tier | Keep existing published pages; suspend nonessential dynamic work; do not silently activate a paid plan |
| Search indexing | Generated real HTML, canonical sitemap, structured metadata, Search Console | No paid SEO software | Manual auditing, static generation, slow publishing rather than paid crawling |
| Server-side dynamic endpoints | Cloudflare Workers/Pages Functions *only when needed* | Free tier (currently 100,000 requests/day shared with relevant Workers quota); avoid function invocation for static content | Return controlled rate-limit/error response, prefer cached result; avoid blocking core learning |
| Auth, learner progress and database | Current Supabase Free project | Currently 500 MB DB per project, 50,000 monthly active users, 5 GB egress, 1 GB file storage, 500,000 Edge Function calls/month; additional limits apply | Soft-limit optional/nonessential queries; prioritize durable learning writes; owner decides funded upgrade before hard stop |
| BYOK | Hardened user-supplied credentials, provider-native delegated login where possible; consented security architecture | Zero LearningApp-funded model requests, no paid proxy required | Always allow non-AI path; never fall back silently to a platform-billed model |
| MCP local | Current stdio Dart server for power users | Process runs on user's device, not LearningApp's infrastructure | Retain read-only local/offline features |
| MCP remote | Public safe read-only endpoint, then scoped OAuth-protected learner endpoint using RLS/least privilege | Runs under free serverless quota, per-user and per-client quotas, explicit rate limits, bounded results; no bundled service-role key | Defer/rate-limit nonessential MCP calls, prioritize app itself, user can use local workflow |
| Lessons/media | Text-rich static content; external links/approved embeds, not self-hosted high-volume video | Do not replicate expensive media, meet rights/consent rules | Keep originals on licensed external platforms; no automatic ingestion of large files |
| Analytics | Existing consent- and eligibility-gated Supabase product events plus Search Console | No external paid analytics service or third-party profiling; minimal retention and capped events | Aggregate/sampling where appropriate, stop optional telemetry before learner paths suffer |
| Contributions | Provider-hosted payment page (e.g. standard Stripe Payment Links) | $0 monthly setup/platform fee; **processor takes per-transaction fees out of receipts** | Contributions remain optional; if payment provider unavailable, keep the app functioning |
| Sponsor cards | Manual-first static first-party content in reviewed eligible pages | No ad network script and no server-side paid vendor | Omit sponsor if unavailable; never inject into core study |
| Publisher advertising | AdSense *if later eligible/approved* on permitted public pages only | $0 AdSense publisher participation fee; UX/legal performance gates still apply | Disable ad slot, never block content |
| Paid acquisition | Prepare campaign assets/UTM tracking and measurement, but do not purchase impressions/clicks | **$0 only while actual media spend is disabled**; ad credits, if any, are neither automatic nor guaranteed | Do not activate without independent external funding or explicit owner approval |
| Domain | Free `*.pages.dev` URL if absolute zero cash is required | A custom `learningapp.io` domain has a renewal charge; it may be previously paid but is not free forever | Remain on included subdomain or fund renewal from revenue |
| Transactional email, backup, moderation | Existing free allowances/owner-run encrypted restore-tested backups, low-volume moderation | Verify the real quotas and security requirements; *do not assume* free-tier auth email or backup suffices forever | Disable optional mail, throttle abuse, protect data and provide a clear recovery/funding decision |

**Provider references verified November 10, 2026:**
- Cloudflare Pages/Functions free static and request allowance: https://developers.cloudflare.com/pages/functions/pricing/ ; https://developers.cloudflare.com/pages/platform/limits/
- Supabase Free quotas and project inactivity suspension: https://supabase.com/docs/guides/platform/billing-on-supabase ; https://supabase.com/pricing ; https://supabase.com/docs/guides/platform/free-project-pausing
- Stripe standard domestic-card processing and Payment Links: https://stripe.com/pricing
- AdSense publisher account participation fee: https://support.google.com/adsense/answer/32850
- GitHub Pages **cannot** be used as the primary commercial SaaS hosting alternative: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits

### 19.3 Hard spending rules and graceful degradation

- **No auto-upgrade, pay-as-you-go overage, platform-funded LLM fallback or automatic purchase of ad inventory.** Any such action requires owner authorization and an actual available funding source; never charge the owner by default.
- Define per-user/per-client/per-IP/per-route quotas for remote MCP and all expensive back-end functions, including anonymous abuse controls. Do not expose `SUPABASE_SERVICE_ROLE_KEY` to end users, local MCP distribution, client bundles or third-party agents.
- Critical learning operations have priority over analytics, ads, SEO re-generation and optional external MCP. When a limit nears, **shed noncritical workload first**, not user progress or verified assessment writes.
- Proposed operating signals, not provider thresholds: **70%** of a resource budget => owner alert; **85%** => minimize/disable optional ingestion and expensive MCP; **95%** => stop nonessential server work and present polite rate-limit/temporary-unavailable explanations. Hard-capped free plans may still stop before these alerts can protect essential services.
- No invented uptime guarantees. Supabase Free may **pause after 7 days of inadequate activity**, and automatic backups are not included at the same level as paid plans. If data cannot be backed up and restored with verified zero-cost tools, that feature is **not production-grade at $0**; escalate before accepting irreplaceable user data.
- Account data and progress should not vanish when a free tier quota is hit. If persistence cannot be guaranteed, disable new writes/registrations transparently before corruption; retain cached/offline learning where safe and sync later, without claiming successful server persistence.
- The server's free request allowance is not an unlimited compute or database budget. Cache versioned public curriculum read endpoints, use payload caps/pagination, avoid polling, and disallow AI-agent recursive loops.
- Keep operator alerts and metrics lightweight and mostly self-hosted/included. Maintain hard evidence of monthly resource utilization, actual invoices, donations net of fees, and days of remaining budget. A goal of $0 is **not proof** the bill is $0.

### 19.4 Explicit feature tradeoffs under hard $0

**Build and retain (enable after their own gates):** free core Flutter studying and local practice, static SEO, quality external-resource routing, donations, hardened BYOK, local MCP, narrowly scoped remote MCP within free quotas, disclosure-based static sponsor placement, affiliate links, and privacy-safe basic analytics. Existing safe functionality should not be disabled merely because the new registry is introduced; preserve effective defaults until the owner resolves §16.1.

**Build dark, not automatically active:** paid acquisition tooling (**buying ads costs money**), third-party ad placement on eligible public pages (approval, legal consent and UX validation required), managed AI inference (requires user funds or a verified funded budget), and any higher-cost optional capacity feature. Their server-enforced cash-spend cap defaults to **0**. Retaining inactive capabilities does not create entitlement to unlimited video streaming, MCP, database writes/storage, enterprise backups or SLAs.

**No-code-execution requirement for dark features:** No expensive widget mount, SDK/script initialization, optional network request, background admission or paid-provider invocation while OFF; require CI proof and bundle/startup-size budgets (§20.5a).

**Financial guardrail:** if annual domain renewal, backup tools, legal requirements or excess infrastructure usage become necessary, options are (a) fund them **entirely from verified net donation/sponsor/affiliate receipts**, (b) reduce/disable the feature, or (c) obtain explicit owner permission to incur cost. Do not treat potential future revenue as cash on hand. Contributions to a for-profit project must not be described as automatically charitable/tax-deductible.

### 19.5 Additional backlog and acceptance gates

- **ZERO-001 (P0):** Inventory real current invoices, domains, Supabase bandwidth/storage/MAU, Firebase hosting traffic, email usage, backups and monthly spending. Record verified $0 baseline or exact blockers. Do not use an invented $0 dashboard.
- **ZERO-002 (P0):** Add a read-only operating-budget report to the existing Cost & Observability console with limits, current measured usage and warnings; no vendor analytics charges or new client SDK.
- **ZERO-003 (P0):** Audit BYOK security and remove silently-funded AI fallback. Introduce explicit `external_mcp` / `byok` / `local` / `deterministic` capability routing; every action reports which path paid for model inference (without recording sensitive prompts or credentials).
- **ZERO-004 (P0):** Protect current MCP server before any public exposure: forbid service-role credentials, bind identity to authenticated token instead of caller `user_id`, block release of protected item answer keys, remove synthetic readiness values from production paths, allowlist tools and writes, and negative-test cross-account access.
- **ZERO-005 (P1):** Build and measure first-party static SEO pages alongside Flutter. Static publication should require zero per-visit dynamic requests and no extra study-shell JavaScript.
- **ZERO-006 (P1):** Add hosted one-time contribution link and optional recurring support only after a verified legal payee, truthful non-charitable wording, fee disclosure and operational payment reconciliation. No custom card-handling UI.
- **ZERO-007 (P1):** Run user-scale load tests for dynamic MCP and Supabase limits, quota-triggered graceful degradation, offline caching and restore from backup. Test fail-closed on ads/analytics and fail-safe for learning.
- **ZERO-008 (P2):** Add the sponsor and affiliate features as static content with no external ad scripts, no algorithmic favoritism, and no protected audience segmentation.
- **ZERO-009 (P3):** Keep display-ad and paid-acquisition connectors disabled until explicit legal/performance and funding approvals. Ads displayed to users and ads purchased to acquire users are different cost models.
- **ZERO-010 / FLAG cross-cutting (P0/P1):** The Feature Control Center must be implemented on existing free infrastructure with no paid feature-management service, no extra client SDK at startup and no per-interaction flag lookups. Enable hard shutdown of new cost-incurring requests and rollouts while preserving core study (see §20).

**Decision:** Make **$0 owner-funded recurring cash** an approval gate for every merge/deployment affecting monetization or AI usage. If a feature requires spending, record the tradeoff and preserve a safe reduced-cost mode rather than automatically billing the owner.

---

## 20. Site-wide Feature Control Center: reversible feature releases, emergency shutdowns and permanent governance (v1.3 foundation, v1.4 consolidated update)

**Decision: REQUIRED FOUNDATION, P0/P1.** Build a first-party, zero-additional-subscription Feature Control Center. The owner/admin must be able to switch a feature or subfeature **on/off without rebuilding or redeploying the entire site**, while retaining the code, schema, content and saved user data. The same controls apply to all significant **future** user-facing or operational features. This is a *release and safety control plane*, not a substitute for secure code, access checks, migrations, backups, or proper incident response.

### 20.1 Why this matters and what is already present

**Source review described in the supplied v1.4 amendment:** `RACCHUS/LearningApp`, `main` at `8fe54cb` (TEL v0.5 / #215). This is repository-level evidence, **not** a deployed-site test or an independent confirmation of the reviewer’s full scan.

1. **`FeatureFlagsCore` appears unread by application consumers.** `packages/learning_core/lib/src/models/brand_config_core.dart` declares BYOK AI, hands-free, offline sync, adult literacy, performance assessments, taxonomy explorer, QTI export and community Q&A, plus custom flags; named defaults are true. `lib/config/brand_config.dart` exposes `BrandConfig.features`. The amendment reports that a search of `lib/` and `packages/` found no consumers outside the model/unit test. **FLAG-001 must verify this with a complete consumer audit** before wiring or retiring any definition. A stored/configured value without a consumer is not a working switch.
2. **`TelFeatureFlags` is a second, actively used implementation.** `lib/models/learning_strategy.dart` defines `overviewEnabled` and `fastEnabled`, both default true, and per-target slug allowlists. `telFeatureFlagsProvider` (`lib/providers/learning_strategy_provider.dart`) holds code defaults in a `StateProvider`; the amendment found no operator/server config setter. Consumers include next-action and learning-strategy providers, overview tour, quick-overview entry and learning-approach selector. It therefore does not yet provide a persistent production control panel or staged server-verified rollout.
3. **Fast target allowlist appears ineffective as written.** The amendment identifies `fastEligibleTargetSlugs.contains(normalized) || isExamTarget`, with `isExamTarget` default true and empty slugs enabled. Add a failing test first; fix the restriction or explicitly rename/document the intended generic exam behavior under **FLAG-012**. Do not silently redefine intended user eligibility.
4. **Admin authorization exists.** `supabase/migrations/20261017000000_moderation_trust_and_safety.sql` defines `private.is_admin()` and a narrow `public.is_admin()` wrapper, with public/anon execution revoked and authenticated/service-role execution granted. Reuse the existing admin check as a prerequisite, but require narrow mutation RPCs, audit trails and additional policy constraints (§20.3).
5. **Admin placement:** `/admin/analytics` already exists as a sibling integration point under Cost & Observability. Implement `/admin/features` in the existing routing/governance pattern, never as a fourth learner tab.
6. **Reuse opportunities requiring follow-up:** Review `lib/services/governance/usage_quota_service.dart` and `moderation_service.dart` for compatible quota, rate-control and audit paths before creating new structures. This is a candidate, not a claim they already implement generic flags.
7. **The dedicated analytics release latch must remain authoritative.** `analytics.product_release_gate` already has a privileged, default-off consent/privacy release process. A generic feature switch must not override eligibility, approval, consent or retention rules.
8. **Adjacent BYOK/MCP constraints remain:** BYOK serializes `apiKey` in browser JSON; `firebase.json` `connect-src` appears to allow self/Supabase, likely blocking direct external AI requests in the reviewed configuration; local MCP code can read `SUPABASE_SERVICE_ROLE_KEY` from its environment. Validate actual deployed headers, key-handling and production behavior before any public-facing claim.

**Migration rule:** Existing verified functionality must have an explicit, reviewed **effective default**, not be unexpectedly disabled by introducing the registry. All new/risky/unfinished/cost-incurring integrations default **OFF**. The new control plane is only complete after backend-side enforcement is tested; a Flutter toggle that merely hides UI does not satisfy §20.10.

### 20.2 Operator experience: one central panel

**Placement:** `/admin/features`, linked inside the existing **Cost & Observability / Governance** console. Admin-only, responsive on desktop and mobile. Not a fourth Learn/Library/Progress destination and no new learner-facing SDK/UI burden at startup.

**Main table / controls** (illustrative interface specification, not live data):

| Column / control | Behavior |
|---|---|
| Feature | Human-readable name, stable ID, description, affected routes, owning team |
| State | `Off`, `Admin/testers`, `Partial rollout`, `On`, or `Emergency off` |
| Effective availability | Shows state *after* safety gates, prerequisites, product eligibility and operator overrides; never claims a toggle made a blocked integration live |
| Scope | Production / staging / development, and optional server-authorized adult/tester cohorts |
| Dependencies | Required upstream services/features; conflicts and mandatory privacy/security prerequisites |
| Health | Relevant failures, recent changes, quotas and measured readiness; `Not measured` when unknown |
| Actions | **Disable now** (fast), **Configure rollout**, **Enable after checks**, **View audit**, and **Revert last change** |
| Change log | Operator identity, timestamp, reason, previous/new values, revision, approval status and request ID |

The admin landing page should show counts of *active, off, staged and emergency-off* features; surface warnings only for material incidents, not a constant barrage of colors, badges or status animations. Support search, filters, grouping by domain and a detail drawer with prerequisite explanations. A simple toggle is sufficient for routine reversible switches; dangerous global enable actions require an explicit confirmation and checklist. **Emergency OFF must remain fast** and must not require a second admin when an active incident needs containment; enabling sensitive features can require extra approval if appropriate.

**Representative feature families to register early:**

| Group | Feature IDs / examples | Safe off-state behavior |
|---|---|---|
| AI and integrations | `ai.byok`, `ai.managed`, `ai.external_mcp`, `ai.local`, `ai.generate_practice` | Disable request initiation and server-side costly or sensitive tools; deterministic learning remains available |
| MCP | `mcp.remote`, `mcp.personal_read`, `mcp.write_review`, `mcp.answer_explanation` | Stop MCP tool admission at trusted server; local offline-only tooling may remain if independently safe and not misleading |
| Learning / content | `learning.simulations`, `learning.community_qa`, `learning.creator_submissions`, `learning.experimental_catalog`, `learning.external_resource_eval` | Show saved work/alternatives where appropriate; no broken links or destructive data changes |
| Assessment / progress | `assessment.new_simulation_sessions`, `assessment.external_ai_feedback`, `progress.optional_analytics` | No new sessions or unsafe writes; preserve existing attempts and authoritative scores; avoid losing already accepted progress |
| Growth / money | `marketing.sponsor_cards`, `marketing.affiliate_links`, `marketing.display_ads`, `support.donations`, `growth.referrals` | Omit widgets and third-party loads; public content and study stay usable |
| Data / telemetry | `analytics.product_events`, `analytics.optional_experiments`, `notifications.marketing` | Stop new collection/dispatch; **do not** override existing dedicated privacy/legal release latches or user consent |
| Cost protection | `ops.nonessential_background_jobs`, `ops.remote_mcp`, `ops.media_uploads`, `ops.external_ai` | Graceful rate limit, offline fallback or temporary unavailability; no silent owner-funded bypass |

**Differentiate global off vs. audience restriction:** An `Admin/testers` release is not equivalent to `On` for all users; only authenticated, server-verified tester identities qualify. A public web user's self-asserted role, URL query parameter or local storage value must never be able to override a production off switch.

### 20.3 Technical architecture and source of truth — zero added SaaS

Use **existing Supabase/Postgres**, lightweight Flutter admin UI, an in-repository feature registry and narrowly scoped RPCs. No LaunchDarkly, Firebase Remote Config, paid flags platform, third-party tracking SDK or continuous per-user network stream is needed for the initial design.

**Recommended components:**

1. **Versioned code registry / manifest** `config/feature_registry.yaml` (proposed) and typed Dart registry/generated constants. Every feature has: `key`, `owner`, `purpose`, `kind` (`release`, `operational`, `kill_switch`, `experiment`, `privacy_gate`, `entitlement`), `safe_default`, `environment`, `client_visibility`, `server_enforced`, `dependencies`, `fallback`, `rollout_policy`, `max_cache_age`, `deprecation_review_date`, `risk_level`, `maturity`, `evidence_status`, `evidence_last_reviewed`, `known_limitations` and `replacement_parity_reference` (when relevant). Registry includes intended affected routes, RPCs, jobs and MCP tools. CI rejects duplicate or unregistered keys and missing off-path tests.
2. **Private authoritative operational state**: additive Supabase schema with `ops_feature_settings`, `ops_feature_revisions` (append-only audit), and optional authorized cohort membership. Public/authenticated roles have **no raw update privilege**. Prefer private schema or tightly protected tables and narrowly exposed functions, not direct frontend writes to settings.
3. **Admin read and mutation API**: `public.get_admin_feature_controls()` and `public.set_feature_control(...)` (illustrative names), authenticated, server-derived admin identity, explicit allowlisted keys/states, revision precondition/CAS, validation against registry and policy, reason required, idempotency key and audit record in the same transaction. `public.is_admin()` is a prerequisite, not the whole authorization policy. Consider step-up authentication for financial, privacy, or broad enable operations. No service-role credential sent to Flutter.
4. **Small public configuration snapshot**: `public.get_effective_public_features()` or a prebuilt public-safe JSON snapshot containing only non-sensitive effective UI switches, version and expiry. No confidential cohort membership, admin reasons, private URL, credentials, billing values, policies or secret targeting predicates. Fetch once after app startup or on meaningful navigation/focus; cache in memory with bounded expiry and ETag/revision. Do not block the first lesson render on feature-flag retrieval; offline mode uses a **safe bounded fallback**.
5. **Server-enforced gates**: Every sensitive RPC, Edge Function, remote MCP tool, webhook-triggered optional activity and background job checks its effective operational gate *inside the trusted execution boundary* before performing work. Hiding a widget/route alone does not stop direct API requests. Keep RLS and domain authorization active regardless of flag values.
6. **Optional out-of-band incident override**: Define an owner-only emergency procedure if Supabase and/or the admin panel cannot be reached. A protected static hosting config/redeploy can stop optional client entry points, while backend failures already deny sensitive writes. Never claim this is an instantaneous remote kill switch for a database or tool host that cannot be reached; document the fallback's latency and limits.

**Proposed effective availability resolution order, highest precedence first:**

```
1. Mandatory legal/privacy, authentication, RLS and exam-integrity rules (cannot be weakened by flags)
2. Trusted emergency OFF override (always wins)
3. Required dependency unavailable/off or safety/zero-cost cap exceeded => OFF/degraded
4. Runtime production setting (OFF / ADMIN / COHORT / ON)
5. Validated product eligibility and server-authenticated rollout cohort
6. Approved build/fork default only when no runtime setting exists and that default is safe
7. For all unknown new keys, invalid configs, or uninitialized high-risk features => OFF
```

Use *parent/child* switches with one-way dependency resolution. Turning `mcp.remote` OFF disables `mcp.personal_read`, `mcp.write_review`, etc.; turning the parent back ON **does not auto-enable** children still deliberately off. Avoid cycles; reject a registry with cyclic dependencies in CI. A global emergency override wins over all cohorts.

**Critical exception:** Essential login/security checks and persistence integrity cannot simply be switched off. Define **maintenance/degraded modes** rather than allowing an owner toggle to bypass authorization, storage, grading or privacy. Core no-network study assets should continue where technically safe; if server progress persistence is unavailable, label it truthfully as pending/offline rather than saved.

### 20.3a Initial registry seed and proposed effective defaults

Starting set for FLAG-002. "Cost" means the feature can incur cash cost or third-party load when enabled. **The v1.5 owner decisions resolve Fast/BYOK/legacy policy**; actual deployment behavior must still be independently audited before writing runtime defaults. This document is not itself an executable flag change. Maturity is tracked separately from availability (§16.2, §20.3b).

| Key                                                           | Kind         | Proposed default           | Server gate needed                                                | Cost                       | Notes                                                                           |
| ------------------------------------------------------------- | ------------ | -------------------------- | ----------------------------------------------------------------- | -------------------------- | ------------------------------------------------------------------------------- |
| `support.donations`                                           | release      | OFF                        | Checkout link visibility; webhook processing                      | Fees only per payment      | Existing payments/commitments handled at the provider, not by the flag (§20.4). |
| `marketing.sponsor_cards`                                     | release      | OFF                        | Sponsor registry read                                             | No                         | Static first-party content, no scripts.                                         |
| `marketing.affiliate_links`                                   | release      | OFF                        | Link registry read                                                | No                         | Disclosure paired with every link (§8).                                         |
| `marketing.display_ads`                                       | release      | OFF                        | Public-page layer only                                            | Third-party script when ON | Never in Flutter. Requires approvals in §9.                                     |
| `marketing.paid_acquisition`                                  | operational  | OFF, `max_spend = 0`       | Spend adapter refuses when cap is 0                               | Direct ad spend            | Owner-approved cap only.                                                        |
| `ai.byok`                                                     | release      | **OFF for all production users until MKT-002 gates pass** | UI, provider requests and mediation  | User pays provider         | **Immediate shutdown target; no automatic re-enable.** Current legacy flag may be unwired: implement and verify real guards. |
| `ai.managed`                                                  | operational  | OFF, `max_spend = 0`       | Every model call                                                  | Direct model spend         | No silent fallback (§19.3).                                                     |
| `ai.external_mcp`                                             | release      | OFF                        | MCP tool admission                                                | MCP hosting only           | Parent of the MCP keys below.                                                   |
| `mcp.remote`                                                  | kill_switch  | OFF                        | Remote endpoint                                                   | Edge calls, egress         | Parent of the next two.                                                         |
| `mcp.personal_read`                                           | release      | OFF                        | Token-derived user only                                           | Same                       | Child of `mcp.remote`.                                                          |
| `mcp.write_review`                                            | release      | OFF                        | Same plus idempotency                                             | Same                       | Child of `mcp.personal_read`.                                                   |
| `analytics.product_events`                                    | privacy_gate | OFF                        | **Existing `analytics.product_release_gate` remains authoritative** | Supabase writes            | Generic flag must not weaken the dedicated latch (§20.1).                       |
| `tel.overview`                                                | release      | **Preserve effective current availability** | Any server-backed parts | No | No owner-directed rollback; mark Experimental wherever relevant verification is missing. |
| `tel.fast`                                                    | release      | **ON / publicly available, preserve existing scope** | Any server-backed parts | No | Owner decision: keep Fast available; show **Experimental** until relevant evidence is verified; resolve allowlist ambiguity under FLAG-012 without silently removing access. |
| `learning.community_qa`                                       | release      | Keep current behavior      | Community write RPCs                                              | Supabase writes            | Legacy `enableCommunityQa`; wire or remove per FLAG-013.                        |
| `learning.simulations` / `assessment.new_simulation_sessions` | release      | Keep current behavior      | Session start RPC                                                 | Supabase writes            | Existing features: audit before assigning defaults.                             |
| `seo.dynamic_endpoints`                                       | operational  | ON once built              | Worker/function endpoints only                                    | Free-tier requests         | Static pages stay up when OFF; they are never taken down by this flag (§20.4).  |
| `ops.nonessential_background_jobs`                            | kill_switch  | ON                         | Job admission                                                     | Supabase/Edge usage        | Shed first at the 85% and 95% thresholds in §19.3.                              |

Dependencies resolve parent to child per §20.3. The other families in §20.2 (hands-free, offline sync, adult literacy, QTI export and so on) are registered in FLAG-002 after FLAG-001 shows what each one actually controls. **Existing useful features remain available unless their independent safety gate fails, or the owner expressly orders shutdown (BYOK).** All new high-risk features still default OFF.

### 20.3b Admin maturity status and learner-facing Experimental badge

The Feature Control Center must show **two independent statuses** for every feature: **availability** (ON/OFF/INTERNAL/COHORT) and **verification maturity** (Experimental/Verified/Retired), with a link to the evidence checklist, scope of coverage and reviewer. A feature with `availability=ON` and `maturity=EXPERIMENTAL` can operate when safe while displaying an unobtrusive, accessible **Experimental** label at the relevant user-visible entry point. It must not fabricate confidence, present simulated readiness as verified, hide unresolved coverage gaps or alter official assessment-scoring contracts.

- For `tel.fast`, **preserve availability** while the registry is wired. Verify target eligibility/allowlist semantics under FLAG-012; do not automatically restrict the existing user population as a side effect of repairing a test. Any intentional eligibility change is a separate owner-reviewed decision.
- For `ai.byok`, **force availability=OFF** in production until the remediation release gate passes; maturity cannot turn it back on. Unverified security/credential handling is not a situation where merely displaying Experimental is sufficient.
- For retired/legacy entries, store a **capability inventory and replacement-parity record**. Do not use a `RETIRED` label as authorization to delete a useful feature, data or working integration. Owners approve capability removal after the §16.3 checklist.

### 20.4 What OFF means: stop the capability cleanly, not just the visible UI

Every flagged feature must declare **all** affected surfaces and an explicit disabled-state contract:

- **Navigation:** Hide or label feature entry as temporarily unavailable. Direct links, bookmarked routes and deep links resolve to a safe, accessible explanation or nearby alternative, never a blank screen or infinite redirect.
- **Frontend:** Do not mount costly widget trees, initialize provider SDKs, load ads/media/AI models, perform optional background polling or schedule further feature-specific calls after effective OFF. Unsubscribe or cancel safe in-flight work when possible; do not tear down the core application.
- **Backend:** Reject *new* sensitive RPC/Edge/MCP work before expense or state change. Recheck state inside the transaction before sensitive writes and at task boundaries. A kill switch cannot retroactively undo a committed transaction; audit and compensating operations are separate concerns.
- **Long jobs / queued work:** Stop admission and retries for the affected workflow. Keep or discard queued records according to a documented data-safety/consent policy (e.g., withdrawing analytics consent deletes analytics telemetry; disabling offline sync must not erase legitimate learner edits). Resume only when versions/schema still match.
- **Persisted user data:** Preserve existing lessons, learning evidence, scores, drafts, configurations and entitlements unless a legally required deletion or security remedy applies. Disabled does not mean drop tables, overwrite data, clear account state or unpublish official content.
- **Visibility / labels:** For an elective feature, prefer quiet omission; for a feature the learner is actively using, give a short neutral explanation, preserve accessible navigation and explain whether any work was saved.
- **Paid or external operations:** OFF prevents new hosted AI inference, ad requests, paid acquisition spend adapters and remote MCP work. Billing providers, recurring payments, refunds and legal retention obligations may need separate provider-side controls; hiding a donation link does **not** automatically cancel a recurring payment contract.
- **SEO:** A disabled optional CTA or dynamic feature must not turn every crawlable page into a 404, strip useful static content or break search indexing. Only deliberately unpublished/ineligible content should change its indexability.

Feature flags **do not** replace database rollback, content migration, dependency management, authentication policies or emergency secret revocation. Never couple flag disable with destructive schema drops.

### 20.5 Rollout and re-enable lifecycle — reversible by design

**States:** `registered` (code present), `off` (default for new/risky), `internal` (admins/testers), `cohort` (server-selected pilot), `on` (eligible public), `emergency_off` (temporary containment). Store operator state separately from actual *effective* state. `emergency_off` requires a documented incident and takes precedence; only a reviewed explicit recovery clears it.

**Lifecycle for every future feature:**

1. **Register before code merge:** Stable namespaced key, owner, dependencies, data migrations, server endpoints, consent requirements, safe fallback, error budget, cost cap and disabled tests. If not registered, CI fails for new substantial routes/services/integrations; an exemption requires documented review (for immutable core security/learning primitives).
2. **Ship dark:** Code, additive compatible schema, approved tests and help/docs can be merged while the production effective flag remains off. Disabled paths must have negligible startup/network overhead.
3. **Internal verification:** Enable for server-verified admins/testers only; verify permissions, accessibility, route redirects, progress persistence, offline mode, performance and $0 cash spend.
4. **Pilot:** Expand 1% -> 5% -> 25% -> 100% **only if** there are enough eligible users to make percentage stages meaningful. Stable privacy-preserving cohort assignment on the **server**; do not profile minors or collect unnecessary attributes to target rollouts. Small populations can use named opt-in testers instead. These percentages are a suggested sequence, not a mandatory schedule.
5. **Monitor and stop:** Monitor latency/error rate, database/Edge quota, unexpected financial liabilities, privacy incidents and learning-flow regressions. An admin can disable instantly on the authoritative backend, with a bounded client refresh delay. On safety, legal or cost violations, the off path wins.
6. **Recover:** Fix underlying issue; test with current production-compatible schema and historical data; verify policy consent, backups and quotas; enable internal first, then staged cohorts, then full. Preserve audit of why/how the feature was restored. The system must not silently resume old queued work or stale ad campaigns.
7. **Review and clean flags:** Keep permanent operational kill switches for expensive/risky integrations. For completed temporary release/experiment flags, schedule a deliberate cleanup **without removing the lasting emergency circuit breaker**. Remove obsolete flags only after validating references, tests and historical audit retention.

**Must-have admin workflows:**

- **Disable now:** Choose feature -> confirm emergency OFF with short reason -> server saves new revision and rejects new gated work -> admin sees authoritative revision/time -> verify a forbidden backend request fails -> optional user-facing service notice if necessary.
- **Re-enable safely:** Review incident and readiness checklist -> dry-run prerequisites -> internal or tester cohort first -> monitor and advance. Clearing `emergency_off` alone does not bypass another OFF state or a privacy/legal gate.
- **Undo accidental routine change:** Restore previous *valid* state using optimistic concurrency; never undo audit rows, consent revocations, billing ledger events or safety incidents by reversing a flag alone.
- **Feature temporarily unavailable to users:** Safe alternative and accurate save status; user can continue learning through unaffected content.

### 20.5a Mandatory build-dark contract (merge gate)

Every feature in the registry meets all of these before merge. This expands the "register before code merge" step in §20.5 and applies to **every approved capability**, including marketing and optional paid capacity.

1. **Registered key** with owner, kind, risk level, dependencies, safe default and disabled-state contract (§20.3).
2. **Default OFF** for new, risky, unfinished or cost-incurring features; preserve safe existing features and specifically **keep TEL Fast ON**. Production BYOK is **OFF**. Label otherwise safe ON features **Experimental** where evidence is incomplete, without treating the label as a security exemption (§16.2).
3. **Off-path test:** with the flag off, a test proves no feature widgets mount, no SDK initializes, no network request fires, no script loads and no background job is admitted.
4. **Server gate at the side-effect boundary** for anything touching RPCs, Edge Functions, MCP tools, webhooks, jobs or spend (§20.3, §20.4). Hiding UI does not count.
5. **Disabled-state behavior:** deep links and bookmarks resolve to a short accessible explanation or alternative, never a blank screen.
6. **Size and startup budget:** feature code beyond a small stub is lazy-loaded or lives in the public site, and CI reports the bundle-size delta. Budget thresholds to be set in FLAG-002 from a measured baseline; none are invented here.
7. **Data preserved when OFF:** no drops, no deletions, no overwritten state (§20.4).
8. **Re-enable checklist** recorded in the registry entry (prerequisites, consent, quotas, who can approve).
9. **Verification label test:** Any ON but meaningfully unverified feature displays the correct accessible **Experimental** label, and no unsupported learning outcome/readiness claim. Tests cover the clean transition to Verified only after evidence review.
10. **No-capability-loss check:** A refactor or legacy cleanup cannot remove an unreplaced useful workflow, stored progress, interface or entitlement; require a capability-parity matrix and owner-approved decommission record where relevant.

### 20.6 Minimum viable panel versus later enhancements

**MVP: implement early, zero incremental subscription spend:** Registry, one global environment, safe `off/on/internal` states, **separate Experimental/Verified maturity**, admin-only list + toggles, server enforcement for top risky paths, audit and reason, prerequisite explanation, live refresh/caching, and a small test suite. Include first-party disable of AI, MCP, ads, donations UI, analytics emitters, community writes and simulations. Add only those subfeature splits needed for safety. Integrate cost alerts from the existing console.

**Later, only when justified:** Percentage cohorts, scheduled rollouts, richer health dashboards, automated circuit breakers, multiple maintainers/approvals, flag expiry cleanup bot, institution-specific overrides and per-feature traffic traces. Do not require a paid feature-management vendor; integrate a standard flag abstraction if future scale demands it. Complexity, database load, and monitoring cost must remain below the value of the flags.

**No-toggle anti-patterns:** Avoid one giant global `features_enabled` Boolean, hundreds of one-off local `if` checks without registry, direct client-editable settings tables, self-service user toggles for admin controls, shadow features that skip RLS, and boolean flags that also carry arbitrary secrets or billing configuration.

### 20.7 Budget, reliability and performance requirements

- **$0 owner-funded cash:** Use existing Supabase Free, existing app admin UI and ordinary repository CI; zero extra vendor SDKs/subscriptions and no new paid control-plane infrastructure. Monitor actual Supabase reads, storage and Edge requests; $0 is conditional on quotas, not free at infinite scale.
- **Control path resilience:** No flag fetch per frame, widget build, flashcard, swipe or question. Favor a tiny, versioned snapshot and local memoization. For sensitive backend operations, the server gate cannot rely solely on a potentially stale browser cache. Cache any server-side lookup only where a tested invalidation/emergency-off mechanism bounds risk.
- **Latency objective (engineering target):** Admin-triggered stop should block new protected backend operations as soon as the authoritative change commits. Active client screens should refresh their UI on a bounded interval/focus event (target <=60 seconds online; measure, do not promise exact instant updates offline). Critical changes can use explicit refresh rather than long-lived realtime subscriptions for every learner.
- **Failure modes:** If configuration is unavailable, **optional monetization, AI, remote MCP, experimental features, telemetry and unsafe writes fail closed**; verified offline core content may remain usable, and valid already-saved local work stays intact. Essential progress writes must never be falsely acknowledged. Re-enablement during an outage is prohibited until authoritative state and data consistency are verified.
- **Keep the system observable without personal surveillance:** Count feature activation failures, backend denials, and cost/health metrics in aggregate; do not record raw search queries, assessment answers, or sensitive personal behavior just to support rollouts.

### 20.8 Security threat model and required tests

| Test scenario | Required result |
|---|---|
| Non-admin / anonymous user calls toggle RPC or updates settings table directly | Denied by grants/RLS/RPC authorization; no audit forgery |
| Learner forges `is_admin`, tester or cohort membership in browser | Still off at protected backend; server derives identity and eligibility |
| `mcp.remote` OFF while remote tool invoked through direct HTTP or external assistant | Request denied before query, scoring or cost; no sensitive data returned |
| Ads/AI/telemetry OFF while UI route is deep-linked | No third-party script/request, server collection, paid model call or broken page |
| Core study flows while optional feature OFF, offline, or config endpoint down | Learn/Library/Progress remain usable where safe; no hanging spinner or false persistence claim |
| Parent disabled but child explicitly ON; unknown flag key; stale revision or corrupt payload | Parent blocks child; new unknown high-risk keys OFF; stale/corrupt updates rejected |
| Two admins edit same feature simultaneously | Revision/CAS protects against silent overwrite; rejected write is visible |
| Emergency OFF during in-flight job, pending offline write, or active assessment | New work blocked; current transaction integrity preserved; explicit resume/finish policy; no lost accepted attempts |
| Emergency OFF during recurring donations | Hide new checkout; existing commitments/refunds managed via actual payment provider, not silently abandoned |
| Restore after schema drift or changed privacy notice | Enable blocked until compatibility checks, consent and required approvals pass |
| CI adds a new user-facing feature without feature key, off-state handler or backend tests | CI fails or explicit scoped exception is reviewed |
| Operator mistakenly disables login/security/data integrity or tries to turn on unapproved telemetry | Not allowed by generic feature control; dedicated security/consent release rules stay authoritative |
| Control panel failure or DB unavailable | Documented emergency operating path; backend sensitive writes fail safe, unaffected cached lessons stay available |

**Security and privacy:** Use least-privilege grants and RLS on exposed tables, fixed `search_path` for privileged definer RPCs and explicit authenticated admin checks. Avoid exposing sensitive targeting logic in public configuration. See Supabase documentation: https://supabase.com/docs/guides/database/postgres/row-level-security and https://supabase.com/docs/guides/database/functions .

### 20.9 Concrete development backlog (add to prioritized roadmap)

- **FLAG-001 — P0: feature inventory and blast-radius matrix (expanded in v1.4).** Confirm by full consumer audit whether `FeatureFlagsCore` has any live application readers; map each named/custom legacy flag. Inventory `TelFeatureFlags` and **every actual consumer**, particularly the Next Action and Overview/Fast routes. Enumerate features without flags, critical/optional routes, RPCs, Edge Functions, MCP tools, schedulers, network SDKs, privacy gates, payment webhooks and storage paths. Review `usage_quota_service.dart` and the server `check_and_record_usage` RPC for reuse; **the client wrapper alone does not prove an authoritative global dollar cap**. Classify OFF consequences and real startup/runtime load. **Do not label either preexisting flag system a functioning global control panel.**
- **FLAG-002 — P0: freeze standard and registry.** Add versioned typed feature IDs, owner, defaults, dependencies, cost/risk classification, **independent availability + maturity/evidence fields**, rollout/disabled contracts, data preservation, and a CI convention requiring registration for all substantial future additions. Preserve existing useful functionality including public TEL Fast (Experimental where not verified); default new risky integrations OFF, and BYOK OFF in production.
- **FLAG-003 — P0: trusted backend control schema/RPCs.** Add append-only migrations via **guarded deployment only**; private settings and audit with least-privilege access, compare-and-set revisions, server admin authentication, no direct browser DML, and negative pgTAP tests.
- **FLAG-004 — P0: enforce at actual side-effect boundaries.** Gate existing remote MCP, paid/external AI, telemetry, community writes, sponsor/ad delivery and new simulation starts; do not rely only on Flutter widgets. Keep dedicated analytics privacy gate intact and respect all existing auth/RLS and exam scoring restrictions.
- **FLAG-005 — P1: Flutter admin Feature Control Center.** Add `/admin/features` to existing governance console, list/search/categories, **availability and separate maturity/evidence status**, quick OFF, prereqs, reason and history, reliable confirmation/revert flows and accessibility. Server verifies every action. Show owner-approved public Fast ON and BYOK production OFF explicitly.
- **FLAG-006 — P1: lightweight client flag snapshots + graceful disable.** Centralized effective flag provider, bounded in-memory cache, refresh on focus/navigation, route/deep-link fallback, zero optional SDK init when off, offline behavior and static SEO compatibility.
- **FLAG-007 — P1: end-to-end kill-switch tests.** Cover real backend denial, in-flight sessions, cached stale UI, fail-closed expensive work, uninterrupted learning, data retention, quota failures and concurrent admin changes. Add smoke test to CI.
- **FLAG-008 — P1/P2: owner runbook and trial exercise.** Document emergency OFF, escalation when DB/panel unavailable, staged re-enable, incident note and expected provider-side steps; conduct a synthetic kill-switch drill before launch.
- **FLAG-009 — P2: targeted rollouts and improved admin diagnostics.** Only when needed, add server-verified cohorts/percentages, health thresholds and cost-triggered disable; keep extra queries and telemetry negligible.
- **FLAG-010 — Ongoing: mandatory future-feature policy.** Every new PR for a substantial feature identifies its registry flag, server/client guard points, default OFF behavior, backward-compatible schema, impact on cost/privacy, safe alternatives and tests; protect via review/CI, and maintain flag lifecycle documentation.

- **FLAG-011 — P1: migrate TEL release flags into the trusted registry.** Replace code-default `telFeatureFlagsProvider` as effective runtime source with versioned server-authoritative controls, explicit precedence, eligibility and disabled/off-path tests (§20.5a). **Preserve current TEL Fast public availability**; keep Overview's current effective behavior pending a separate rollout decision. Set/maintain `tel.fast` maturity **Experimental** wherever validation is incomplete and display it without disrupting use. Changing coverage or access is a separate reviewed change, not a consequence of flag migration.
- **FLAG-012 — P0: Fast target-allowlist behavior regression.** Code review reproduced the logic: `fastEligibleTargetSlugs.contains(normalized) || isExamTarget`, with `isExamTarget=true` by default, accepts any nonempty exam-target slug and permits null/empty slugs. Write explicit tests for `TelFeatureFlags.isFastEnabledForTarget` with allowed/disallowed exam target slugs and null/empty slug. Clarify whether the method deliberately permits all exam targets or should enforce a strict allowlist; **do not silently restrict Fast for current eligible users**. Repair accidental logic while preserving approved public availability, or propose a separately owner-approved scope change if the verified fix changes user access. Keep affected paths labeled **Experimental** until behavior and educational reliability are verified.
- **FLAG-013 — P1: resolve legacy `FeatureFlagsCore` entries and protect capabilities.** After FLAG-001, inventory the **actual legacy capability** behind each flag and any other old code; build a use/replacement/parity matrix. **Keep any still-needed capability with no verified replacement**, wiring it into the new registry or modernizing it. Remove truly obsolete functionality only after owner approval, or retire duplicated implementation only after functional parity, saved-state migration, links, accessibility and rollback tests. Remove inert/duplicate flag definitions only after proving no loss of behavior; eliminate misleading no-op configuration. Do not delete data because code is cleaned up.
- **FLAG-014 — P0/P1: experimental maturity and evidence coverage.** Create a reusable, unobtrusive user-facing **Experimental** marker and Help explanation plus admin evidence checklist. Apply to Fast and any other ON feature whose meaningful behavior or educational claim lacks verification. Prove safety/consent/score gates still block where needed; do not turn experimental markers into clutter.
- **FLAG-015 — P0: BYOK emergency-off release verification.** Until the general Feature Control Center is operating, ship a narrow production-off gate for BYOK, test the existing settings/deep links/key invocation and server paths, confirm no BYOK provider requests occur, and retain non-AI study paths. Later migrate that real gate into `ai.byok` without an exposure window. **Do not mistake the plan update for the production shutdown.**
- **FLAG-016 — P1: legacy capability retirement audit/CI contract.** Before deletion, require a reviewed inventory of user functionality, capability replacement parity or explicit owner-approved obsolescence, affected data and exports, accessibility, offline flows, regression tests, compatibility and rollback. **Fail or block cleanup PRs lacking this evidence** rather than automatically removing files from an old subsystem.

### 20.10 Definition of done for this amendment

This is complete **only when** a privileged owner can, from `/admin/features`, disable a deliberately broken optional feature without redeployment; a direct API/MCP invocation is actually refused; Study/Learn/Library/Progress remain functional where safe; persisted learner work is preserved; audit identifies who changed the setting; rollback/re-enable is available after checks; and CI ensures the same control for significant future features. A demo toggle that merely hides a menu item does **not** satisfy the requirement.

**Explicitly NOT performed by this v1.6 reviewed plan:** No production BYOK shutdown, TEL status-label release, legacy deletion, admin panel, table, RPC, feature switch, schema migration, CI check or production behavior has been implemented or enabled. The work above is a proposed implementation roadmap and must respect LearningApp's guarded deployment, review and zero-spend requirements.

---

## 21. Research references and review notes

**v1.6 source and verification boundary:** Retains v1.5 owner decisions and **rechecked GitHub `main` HEAD at `8fe54cb01a1f35a9ee6937233674a4f2e5998279`**. Reviewed `FeatureFlagsCore`, `TelFeatureFlags`, the TEL provider, current admin route, `UsageQuotaService`, BYOK persistence and client, SEO metadata and static assets, and MCP runtime/readiness fallbacks. No Flutter/pgTAP build, CI execution or live production audit was run; no code, migration or runtime flag changed. Earlier plan text was consolidated from the supplied "LearningApp Marketing, Advertising, Business & Financial Sustainability Plan — v1.4 Amendment" (November 10, 2026), which reports a read-only clone review of `RACCHUS/LearningApp` `main` at `8fe54cb` following TEL v0.5 / #215. This plan update integrated its claims and tasks; it did **not** rerun the repo audit, verify hosted production, validate actual provider fees or deploy anything. Technical observations in the amendment should be independently reproduced during FLAG-001 and FLAG-012 before changes to live behavior.

**Official resources checked November 10, 2026 (policies and prices can change):**

- Google Search Central — JavaScript SEO, static/server rendering: https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics ; https://developers.google.com/search/docs/crawling-indexing/javascript/dynamic-rendering
- Google Search Central — people-first content and spam policies: https://developers.google.com/search/docs/fundamentals/creating-helpful-content ; https://developers.google.com/search/docs/essentials/spam-policies
- Google Search Central — structured data for Q&A, course lists and software: https://developers.google.com/search/docs/appearance/structured-data/qapage ; https://developers.google.com/search/docs/appearance/structured-data/course ; https://developers.google.com/search/docs/appearance/structured-data/software-app
- Google Search Central — sitemap, documentation changes: https://developers.google.com/search/docs/crawling-indexing/sitemaps/overview ; https://developers.google.com/search/updates
- Google AdSense eligibility/content and placement rules: https://support.google.com/adsense/answer/9724 ; https://support.google.com/adsense/answer/7299563 ; https://support.google.com/adsense/answer/1346295 ; https://support.google.com/adsense/answer/48182
- Google AdSense EU/UK/Swiss consent requirements: https://support.google.com/adsense/answer/13554116
- Google Ad Grants — only eligible nonprofits: https://www.google.com/nonprofits/find-solutions/ad-grants/
- Stripe published US pricing and Payment Links: https://stripe.com/pricing ; https://docs.stripe.com/api/payment-link/object
- FTC affiliate and endorsement disclosure guidance: https://www.ftc.gov/business-guidance/resources/ftcs-endorsement-guides-what-people-are-asking
- FTC COPPA ad guidance and amended rule: https://www.ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions ; https://www.ftc.gov/news-events/news/press-releases/2025/01/ftc-finalizes-changes-childrens-privacy-rule-limiting-companies-ability-monetize-kids-data
- IRS Publication 526, qualified deductible charitable contributions: https://www.irs.gov/publications/p526
- OpenAI API key security: https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety
- MCP protocol official July 28, 2026 release and authorization hardening: https://blog.modelcontextprotocol.io/posts/2026-07-28/
- MCP official SDK host/client/server architecture: https://py.sdk.modelcontextprotocol.io/get-started/first-steps/
- MCP sampling deprecated in 2026-07-28 protocol: https://py.sdk.modelcontextprotocol.io/handlers/sampling-and-roots/
- Supabase OAuth 2.1 and MCP Auth: https://supabase.com/docs/guides/auth/oauth-server ; https://supabase.com/docs/guides/auth/oauth-server/mcp-authentication
- Supabase MCP Edge Function deployment guide: https://supabase.com/docs/guides/ai-tools/byo-mcp
- Supabase OAuth scope/RLS warning: https://supabase.com/docs/guides/auth/oauth-server/token-security
- OpenAI ChatGPT versus API subscription billing: https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform
- Web Vitals thresholds: https://web.dev/articles/vitals
- OpenFeature flag evaluation-context and targeting guidance: https://openfeature.dev/specification/sections/evaluation-context/
- LaunchDarkly documentation on temporary release flags, permanent kill switches and flag defaults (used as design reference; **no paid vendor recommended**): https://launchdarkly.com/docs/fed-docs/guides/flags/creating-flags
- Supabase RLS, function authorization and fixed `search_path`: https://supabase.com/docs/guides/database/postgres/row-level-security ; https://supabase.com/docs/guides/database/functions

**Reviewed LearningApp repository material (default branch, November 10, 2026):**

- https://github.com/RACCHUS/LearningApp/blob/main/UI_ARCHITECTURE_LOCKED.md
- https://github.com/RACCHUS/LearningApp/blob/main/packages/learning_core/lib/src/models/brand_config_core.dart
- https://github.com/RACCHUS/LearningApp/blob/main/lib/config/brand_config.dart
- https://github.com/RACCHUS/LearningApp/blob/main/lib/screens/governance/cost_observability_screen.dart
- https://github.com/RACCHUS/LearningApp/blob/main/lib/services/governance/cost_observability_service.dart
- https://github.com/RACCHUS/LearningApp/blob/main/docs/analytics/ANA_103_ACTIVATION_AND_RETENTION_RUNBOOK.md
- https://github.com/RACCHUS/LearningApp/blob/main/supabase/tests/ana_103_product_release_latch_test.sql
- https://github.com/RACCHUS/LearningApp/blob/main/docs/product/COMMUNITY_EDUCATOR_KNOWLEDGE_ROADMAP.md
- https://github.com/RACCHUS/LearningApp/blob/main/LEARNINGAPP_ANALYTICS_IMPLEMENTATION_PLAN.md
- https://github.com/RACCHUS/LearningApp/blob/main/docs/analytics/ANA_102_PRIVATE_EVENT_PIPELINE.md
- https://github.com/RACCHUS/LearningApp/blob/main/lib/services/ai/byok_provider.dart
- https://github.com/RACCHUS/LearningApp/blob/main/lib/services/ai/llm_client.dart
- https://github.com/RACCHUS/LearningApp/blob/main/tool/mcp_server/README.md
- https://github.com/RACCHUS/LearningApp/blob/main/tool/mcp_server/bin/learningapp_mcp.dart
- https://github.com/RACCHUS/LearningApp/blob/main/tool/mcp_server/src/mcp_tools.dart
- https://github.com/RACCHUS/LearningApp/blob/main/tool/mcp_server/src/learning_data_source.dart
- https://github.com/RACCHUS/LearningApp/blob/main/ARCHITECTURE_REVIEW.md
- https://github.com/RACCHUS/LearningApp/blob/main/lib/widgets/ai/byok_settings_dialog.dart
- https://github.com/RACCHUS/LearningApp/blob/main/lib/services/community/seo_metadata_service.dart
- https://github.com/RACCHUS/LearningApp/blob/main/web/sitemap.xml
- https://github.com/RACCHUS/LearningApp/blob/main/web/robots.txt
- https://github.com/RACCHUS/LearningApp/blob/main/web/index.html
- https://github.com/RACCHUS/LearningApp/blob/main/firebase.json

**Limitations:** No access to verified live revenue, invoices, Search Console, merchant accounts or confirmed production web crawls was obtained in this review. No ad yield, sign-up rate, sponsor willingness or learner count is estimated as a factual baseline. This is a prioritized technical/business proposal requiring normal development and owner-approved operational activation.


---

## 22. Final independent review, corrected assumptions and release handoff (November 10, 2026)

### 22.1 Repository evidence and verification boundary

GitHub `main` was rechecked at **`8fe54cb01a1f35a9ee6937233674a4f2e5998279`** (TEL v0.5 merge, PR #215). The repository root did **not** contain this marketing master plan before this document was prepared for commit. Review focused on the code paths that could materially change the plan, not every file or a live hosted schema. Do not interpret this plan's merge into `main` as a production rollout or a working control center.

| Finding reconfirmed | Current code evidence | Required implementation response |
|---|---|---|
| BYOK is not safely production-ready | `ByokStorageService` serializes `apiKey` into `SharedPreferences`; Gemini calls place a key in the request URL; model supports custom endpoints | **P0 OFF first** at actual user/UI/call paths, then review key lifecycle, provider support, CSP, error hygiene; avoid user-key upload |
| TEL Fast is currently enabled by code defaults | `TelFeatureFlags` defaults ON; `telFeatureFlagsProvider` creates `const TelFeatureFlags()` | Preserve public Fast availability; mark unverified operation **Experimental**; do not turn it off merely to migrate flags |
| Fast target allowlist is not a strict allowlist | `isFastEnabledForTarget` returns `contains(slug) || isExamTarget`, with `isExamTarget=true` default | Write failing regression tests; determine intended general-exam availability with owner before any narrowing; fix misleading semantics |
| Build-time flags are not live kill switches | `FeatureFlagsCore` defines default-true flags, while `BrandConfig` reads build injection; audit did not identify production action-point guards | Inventory consumers and capabilities; unify effective flags and enforce sensitive operations at their server boundary |
| Existing admin and quota components are reusable but incomplete | `/admin/analytics` is routed; Cost & Observability uses `public.is_admin()`; `UsageQuotaService` calls `check_and_record_usage` | Add `/admin/features` under governance; verify server dollar cap separately instead of assuming client quota calls protect every spend |
| SEO scaffolding is not a public SEO website | Firebase catch-all rewrites to Flutter index; seed-only sitemap; hash-based robots disallows | Ship actual prerendered public pages with correct HTTP statuses; generate sitemap from live published URLs; enforce auth, not robots, for privacy |
| Seed-FAQ `QAPage` output is materially overbroad | `SeoMetadataService.generateQaPageJsonLd` checks publication/seed status, not actual user-answer submission | Replace editorial FAQ schema with appropriate editorial markup; use `QAPage` only on genuine alternative-answer Q&A pages |
| Local MCP cannot safely be treated as a public multi-user connector | CLI accepts service-role key; tool inputs include caller-supplied user IDs and answer exposure; `getLearnerState` can return synthetic scores | Secure read-only pilot first; hosted user-bound OAuth/RLS later; prohibit protected bank answers and invented readiness |
| Analytics has a separate authorization latch | `analytics.product_release_gate` and opt-in pipeline defined in repo | Preserve its independent privacy/eligibility/consent/retention release gate; generic `analytics.product_events` OFF is only an additional brake |

### 22.2 Final correction: $0 funding and third-party billing

**Hard zero owner-funded spending is a product target, not proof that external bills cannot exist.** Supabase Free and Cloudflare Free constrain requests and capacity; unavailable/paused free services can still harm availability. Processor fees reduce net receipts; a custom domain, compliance, refunds, taxes and human work may require funds. The plan must show *verified cash receipts*, *processor fees*, *committed expenses*, *free-tier headroom* and a *forecast of remaining capacity* separately. Never fund overages by adding a card or enabling an upgrade without explicit owner approval.

**Paid-media enforcement boundary:** `marketing.paid_acquisition=OFF` and a server `max_spend=0` only guard actions that traverse LearningApp's own integration. Once a campaign has been activated in an external ad account, disabling a LearningApp flag cannot guarantee its ads stop or its billing ceases. Maintain provider-side paused defaults, separate billing credentials, budgets and an operator emergency-stop checklist. Reconcile actual invoices before declaring spend zero.

**Free hosting boundary:** Current Cloudflare documentation describes unlimited static-asset requests where no Function runs, but serverless requests have daily limits, and Cloudflare now recommends Workers for new projects. Evaluate Workers static assets alongside Pages and the existing Firebase deployment; do not migrate automatically. Supabase Free's inactivity pausing, lack of included managed backups, and quota/availability constraints require an honest uptime and backup/recovery plan before production reliance.

### 22.3 Final SEO schema and crawlability gate

Google's published `QAPage` requirements call for **users to be able to submit answers to a single question**. A curated one-answer seed FAQ is not eligible merely because it has an accepted answer. Google's ordinary FAQ rich-result feature was removed in May 2026; avoid promise-based SEO work. Generate suitable `WebPage`/`Article` and breadcrumbs for editorial pages, and reserve `QAPage` for appropriately reviewed community discussion URLs with real alternative-answer capability. Each schema claim needs a corresponding visible page element. Test HTML status, canonical, noindex/private content, structured-data eligibility, sitemap integrity and social preview in CI/browser smoke tests.

### 22.4 Non-negotiable first implementation sequence

1. **Immediate hotfix:** MKT-002 / FLAG-015 — actual BYOK OFF, including saved-key invocation and direct provider requests. Verify no regressions to non-AI learning. Do **not** wait for the feature-control panel. Do not claim complete until deployed and checked.
2. **Safe feature-control foundation:** FLAG-001–004 plus FLAG-012 — full consumer/capability inventory, source-of-truth registry, server gates, independent legacy parity rules, TEL scope/allowlist tests. Preserve currently working Fast and Overview availability.
3. **Owner-facing controls and tests:** FLAG-005–008, FLAG-014 and FLAG-016 — accessible admin panel, separate availability vs Experimental maturity, durable audit, safe OFF, rollback/re-enable drill, no capability-loss cleanup policy and deterministic tests.
4. **Safe organic growth:** MKT-003/101/102 — public HTML, correct schema and quality-reviewed content; optional support checkout only after entity/tax/legal/provider evidence.
5. **User-owned AI distribution:** MKT-002B/105 first, then MKT-205 — secure read-only MCP and one verified client, later user-bound personal tools. BYOK repair/re-enable is a separately approved security decision.
6. **Build commercial integrations dark:** sponsorship, affiliates, public-page ad slot, spend-tooling and managed AI can be merged OFF, with zero dormant traffic/third-party scripts. None automatically activate because the plan merges.

### 22.5 Release acceptance gates and implementation record

A PR claiming any of these tasks complete must link to exact code paths, test evidence and **deployed** behavior if a runtime claim is made. At minimum test: (a) direct RPC/MCP bypass with feature OFF; (b) graceful deep-link and offline access; (c) no leaked BYOK key or protected answer; (d) original study path and saved evidence untouched; (e) no external scripts or paid requests while dark; (f) stale flag snapshot, panel outage and concurrent edits; (g) opt-in eligibility and analytics privacy release gate; (h) bundle/startup/latency delta; and (i) verified revenue reconciliation if payment is active.

**Repository governance:** `AGENTS.md` requires append-only migrations with exact timestamp versions, guarded dry-run and owner-authorized deployment. No direct production SQL, no migration repair workaround and no new service-role secret in Flutter. The written plan may be committed to `main` directly if repository rules permit, **but doing so does not authorize application builds, migrations, launches or changing feature states**.

### 22.6 Remaining owner decisions and operational unknowns

Unresolved: legal payee and charitable/noncharitable terminology; production domains; age/region policy; acceptable BYOK credential design; verified revenue and infrastructure costs; sponsor/affiliate governance; and whether a particular Fast-mode target restriction is intended. **These do not reopen the three decisions already settled**: Fast stays available with Experimental disclosure as warranted; BYOK stays OFF pending verified repairs; and unreplaced useful legacy capabilities must be kept.

**Source verification:** [Google QAPage](https://developers.google.com/search/docs/appearance/structured-data/qapage), [Google Search documentation updates (May–June 2026)](https://developers.google.com/search/updates), [Cloudflare Pages Functions pricing](https://developers.cloudflare.com/pages/functions/pricing/), [Cloudflare Pages platform direction](https://developers.cloudflare.com/pages/), [Supabase Free plan / pausing](https://supabase.com/pricing), [Supabase free pausing](https://supabase.com/docs/guides/platform/free-project-pausing), and [MCP 2026-07-28 specification](https://blog.modelcontextprotocol.io/posts/2026-07-28/).
