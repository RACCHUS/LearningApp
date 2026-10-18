# LearningApp Privacy Policy

**Effective Date:** October 17, 2026  
**Last Revised:** October 17, 2026  
**Application:** LearningApp (`RACCHUS/LearningApp`)  

---

## 1. Overview & Principles

LearningApp values your privacy. This Privacy Policy explains what information we collect, how it is used, how children and minor accounts are protected, and what controls you have over your data.

Our core privacy principles:
- **Data Minimization**: We collect only what is strictly necessary to deliver personalized educational study and progress tracking.
- **Offline & Local Priority**: Foundational literacy profiles, oral progress, and pre-reader practice data remain stored locally on your device by default.
- **Children's Privacy First**: Accounts for minors default to private study mode, with zero public exposure and no unsolicited communications.
- **Learner Ownership**: You have the right to inspect, export, and permanently delete your account and personal study history at any time.

---

## 2. Information We Collect

### 2.1 Information You Provide Directly
- **Account Registration**: Email address and display name when creating an authenticated account.
- **User-Created Content**: Custom private learning goals, self-reported pathway checklist milestones, notes, and private study collections.
- **Community Contributions (Adults $\ge 18$ only)**: Questions, answers, comments, and feedback submitted to public community areas.
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

We **do not sell, rent, or monetize your personal information** to third-party data brokers or advertisers.

---

## 4. Minor Safety & Children's Privacy (COPPA & FERPA Considerations)

### 4.1 Strict Policy Boundary
- Public posting, creator publishing, and public discussion features are restricted to verified adult users ($\ge 18$).
- Minor accounts are restricted from public directory listing, public broadcasting, and direct messaging with adult strangers.

### 4.2 Children Under 13 (COPPA Operational Framework)
- LearningApp does not knowingly collect personally identifiable information from children under 13 without verified parental or educational institutional consent.
- When children under 13 use the Service:
  - Accounts must be created, managed, or authorized by a parent, legal guardian, or accredited school/caseworker.
  - The account operates strictly in **Private Study Mode**.
  - All public profile visibility, social interaction, and messaging capabilities are permanently disabled.
  - Progress data is accessible only to the authenticated parent/guardian or caseworker.

### 4.3 Student Education Records (FERPA Framework)
- When the Service is utilized in an institutional or classroom context, student data is handled in compliance with applicable education record protections, maintaining strict institutional boundaries and purpose limitation.

---

## 5. Data Retention & Deletion ("Right to be Forgotten")

1. **Active Accounts**: We retain your study progress, learning targets, and account credentials for as long as your account remains active.
2. **Account Deletion**:
   - You may request complete deletion of your account and personal data at any time through your Profile Settings or by contacting `privacy@learningapp.local`.
   - Upon confirmed deletion:
     - Your personal identity record (`public.users`) and authentication credentials (`auth.users`) are permanently deleted.
     - Your private learning targets, versions, custom curriculum notes, and study sets are completely purged.
     - Spaced repetition logs (`review_items`) and concept progress states (`user_concept_state`) are permanently removed.
     - Any public community questions or answers you authored may be anonymized or retained with author attribution removed to preserve instructional continuity.
3. **Data Portability**: You may request a machine-readable export (JSON) of your personal learning goals, study sets, and progress logs.

---

## 6. Security & Data Protection

- All data in transit is encrypted using Transport Layer Security (TLS 1.3).
- Data at rest in our cloud databases is protected by database encryption and enforced by Postgres Row-Level Security (RLS) policies ensuring users can only read and write their own authorized records.
- Server administrative keys are isolated to secure backend infrastructure and are never exposed to client-side bundles.

---

## 7. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect service enhancements or regulatory requirements. Any material changes will be announced with prominent notice within the application prior to taking effect.

---

## 8. Contact & Data Protection Officer

For privacy questions, data requests, or parental inquiries:
- **Email:** `privacy@learningapp.local`
- **Support:** `support@learningapp.local`
- **Repository:** [`RACCHUS/LearningApp`](https://github.com/RACCHUS/LearningApp)
