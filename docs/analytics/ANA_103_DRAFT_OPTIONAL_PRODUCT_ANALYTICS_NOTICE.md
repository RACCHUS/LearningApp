# Proposed optional product analytics notice — review required

**Status: DRAFT, NOT APPROVED OR PUBLISHED.**  
**Proposed policy version:** `product-analytics-v1`  
**Owner/reviewer:** [not assigned]  
**Approval date / jurisdictional review:** [pending]

This is proposed user-facing copy for a separate affirmative opt-in. It does **not** authorize data collection, identify who is legally eligible, or constitute a legal opinion.

## Proposed user-facing wording

**Optional Product Analytics**

LearningApp can work without optional product analytics. Your choice does not affect your lessons, study progress, exam results, account access or core features.

If you choose **Opt in**, we may record limited information about how you use the app, such as which main app section you open, which feature type you use, whether you open a catalog resource, and whether you click an external resource link. We also record a random event and session identifier, your account identifier, the event's time, and a limited set of approved category or catalog IDs.

**We do not record** the text of your searches, private notes, messages, assessment answers, passwords, payment details, or the content of external websites and courses through optional product analytics. A click to an external course does not mean we know whether you watched it or learned from it. Learning progress and assessment scoring use separate records and are not part of this opt-in event stream.

We use these limited events to improve finding resources, remove confusing app steps, understand feature use and identify technical problems. We do not claim this opt-in sample represents every learner. Platform reporting hides small groups and does not provide an administrator with a raw user activity feed.

**Your control:** Optional analytics starts only after you explicitly consent and your account is independently confirmed eligible. You can withdraw consent in Settings → Optional Product Analytics Privacy. Withdrawal deletes your stored raw product analytics events and clears pending events on this device. You can request or export a copy of your product events while stored.

**Retention:** We propose removing raw product events automatically after 90 days. This retention schedule must be operational and verified before any collection is activated. Some aggregated historical statistics may need a separately reviewed retention and erasure policy before being introduced.

**Your account:** Anonymous guest accounts are not eligible. Rules for minors, educational institutions, managed/school accounts and additional jurisdictions require a separate privacy review before enrollment.

Do you want to share this optional product activity information for the purposes described above?

[Not now]  [Opt in to product analytics]

## Consent and release checks before publishing

- [ ] Legal/privacy owner confirms transparency, purposes, lawful basis, applicable jurisdiction and any separate age/guardian/institutional duties.
- [ ] Product owner confirms that every actual app event matches the listed categories and no prohibited text/content can enter `properties`.
- [ ] Approved privacy policy is accessible to the user, with version, effective date and contact route.
- [ ] Server records the approved policy version and exact consent timestamp, not merely a browser preference.
- [ ] Consent is explicitly affirmative, unbundled from signup and easy to withdraw; withdrawal works even if eligibility is removed.
- [ ] Retention is operational and monitored, including erased users, exports and backup retention decisions.
- [ ] Data disclosure accurately covers access by operators, storage geography, service processors and any cross-border transfers; these are not yet researched or approved.
- [ ] Accessible screen reader/keyboard review, mobile responsiveness and error/confirmation states pass.
- [ ] Explicit decision to activate `policy_ready` and `collection_active` is made in a reviewed release PR only after the above.

**No user consent should be solicited using this draft until it has been reviewed and approved.**
