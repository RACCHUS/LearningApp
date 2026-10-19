# LearningApp Privacy Policy

> [!IMPORTANT]
> **DRAFT PRIVACY POLICY — PENDING OPERATIONAL VERIFICATION AND QUALIFIED LEGAL REVIEW**  
> This policy is an architectural design draft specifying the planned privacy and data governance framework for LearningApp. It does **not** constitute a completed legal compliance program, legal advice, or an active operational warranty. Statements describing technical capabilities (including self-service account deletion, verified parental consent mechanisms, and automated data exports) represent target product specifications under active development and must be validated through technical release gates and formal legal counsel prior to public launch.

**Status:** Draft / Pending Operational & Legal Verification  
**Effective Date:** Pending Public Launch  
**Last Revised:** October 2026  
**Application:** LearningApp (`RACCHUS/LearningApp`)  

---

## 1. Overview & Principles

LearningApp values learner privacy. This Privacy Policy outlines what information we plan to collect, how it will be processed, how children and minor accounts are isolated, and the privacy controls designed for our users.

Our core privacy principles:
- **Data Minimization**: We collect only what is strictly necessary to deliver personalized educational study and progress tracking.
- **Offline & Local Priority**: Foundational literacy profiles, oral progress, and pre-reader practice data remain stored locally on your device by default.
- **Children's Privacy First**: Accounts for minors default to private study mode, with zero public exposure, zero public directory listings, and no unsolicited communications.
- **Learner Ownership**: Target features will allow learners to inspect, export, and permanently delete their accounts and study history.

---

## 2. Information We Collect

### 2.1 Information You Provide Directly
- **Account Registration**: Email address and display name when creating an authenticated account.
- **User-Created Content**: Custom private learning goals, self-reported pathway checklist milestones, notes, and private study collections.
- **Community Contributions (Adults $\ge 18$ only — Disabled during Phase 0)**: Questions, answers, comments, and feedback submitted to public community areas once public UGC is enabled.
- **Moderation Reports**: Information submitted when flagging inappropriate content or requesting review.

### 2.2 Automatically Collected Usage Telemetry
- **Study Progress**: Lesson completions, review intervals (SM-2 spaced repetition), quiz scores, and concept mastery evidence used to adapt study schedules.
- **Technical Diagnostics**: Device type, browser environment, client error logs, and session connectivity necessary to maintain service reliability.

### 2.3 Information Kept Strictly On-Device
- **Foundational Literacy Practice**: Tactile Zaner-Bloser handwriting canvas strokes, pre-reader audio settings, and caseworker profile presets are stored locally via `SharedPreferences` / Hive and are not transmitted to backend servers unless cloud synchronization is explicitly enabled.

---

## 3. How We Use Information

We use collected information solely to:
- Authenticate your access and synchronize your learning progress across devices.
- Calculate adaptive review schedules and diagnostic concept readiness.
- Maintain community safety, investigate abuse reports, and enforce our Terms of Service.
- Monitor service health, fix technical bugs, and optimize application performance.

We **do not sell, rent, or monetize personal information** to third-party data brokers or advertisers.

---

## 4. Minor Safety & Children's Privacy (COPPA & FERPA Considerations)

### 4.1 Strict Policy Boundary
- Public posting, creator publishing, and public discussion features are restricted to verified adult users ($\ge 18$).
- Minor accounts are restricted from public directory listing, public broadcasting, and direct messaging with adult strangers.
- Public user-generated content (UGC) is disabled platform-wide during the initial foundation phase.

### 4.2 Children Under 13 (COPPA Operational Framework)
- LearningApp does not knowingly collect personally identifiable information from children under 13 without verified parental or authorized school consent.
- **Important Statutory Limitation**: A caseworker, guardian, or teacher relationship does not automatically establish valid parental consent under COPPA.
  - Where schools provide consent on behalf of parents, FTC rules strictly require that the Service be used solely for the school's educational benefit and not for any commercial purposes of the operator.
- When children under 13 use the Service:
  - Accounts must be created, managed, or authorized by a parent, legal guardian, or an accredited educational institution under contract.
  - The account operates strictly in **Private Study Mode**.
  - All public profile visibility, social interaction, and messaging capabilities are permanently disabled.
  - Progress data is accessible only to the authenticated parent/guardian or authorized school instructor.

### 4.3 Student Education Records (FERPA Framework)
- When the Service is utilized in an institutional or school classroom context:
  - Student education records are subject to FERPA requirements based on the school's relationship with the service (e.g. "School Official" exception with legitimate educational interests).
  - The educational institution maintains direct control over the maintenance and use of student education records.
  - Student records are never redisclosed to third parties without prior institutional authorization.

---

## 5. Data Retention & Deletion ("Right to be Forgotten" — Target Specifications)

> [!NOTE]
> The account deletion and export capabilities described below represent target functional requirements currently under active engineering development. Operational self-service workflows will be verified before public availability.

1. **Active Accounts**: We retain study progress, learning targets, and account credentials for as long as your account remains active.
2. **Account Deletion (Under Development)**:
   - Planned workflow: Users will be able to request complete deletion of their account and personal data through Profile Settings or designated privacy intake channels.
   - Target technical execution:
     - The personal identity record (`public.users`) and authentication credentials (`auth.users`) are permanently deleted.
     - Private learning targets, custom curriculum notes, and study sets are completely purged.
     - Spaced repetition logs (`review_items`) and concept progress states (`user_concept_state`) are permanently removed.
     - To the extent any public community discussions exist in future phases, authored questions/answers will be anonymized to preserve instructional graph continuity.
3. **Data Portability (Under Development)**:
   - Planned capability for users to download a machine-readable export (JSON) of their personal learning goals, study sets, and progress logs.

---

## 6. Security & Data Protection

- All data in transit is encrypted using Transport Layer Security (TLS 1.3).
- Data at rest in cloud databases is protected by database encryption and enforced by Postgres Row-Level Security (RLS) policies ensuring users can only read and write their own authorized records.
- Server administrative keys are isolated to secure backend infrastructure and are never exposed to client-side bundles.

---

## 7. Changes to This Privacy Policy

We may update this Privacy Policy periodically as features evolve and legal reviews are completed. Any material changes will be announced with prominent notice within the application prior to taking effect.

---

## 8. Contact & Data Protection Officer (Draft — Pending Operational Launch)

> [!NOTE]
> Contact channels below are provisional placeholders pending operational corporate establishment.

For privacy questions, data requests, or parental inquiries:
- **Privacy Intake:** `[privacy@domain-pending.example]`
- **Technical Support:** `[support@domain-pending.example]`
- **Repository Support:** [`RACCHUS/LearningApp`](https://github.com/RACCHUS/LearningApp)
