# Excel practice workbook — proposed learner privacy notice

**Status: DRAFT FOR PRIVACY/PRODUCT/OWNER REVIEW. NOT APPROVED, NOT PUBLISHED, AND NOT AN ACTIVE FEATURE.**

The text below is a proposed notice for a *future* opt-in Excel workbook
practice feature. It must not appear in a live learner interface until the
hosting, retention, erasure and security gates are completed and a responsible
reviewer approves it. The current service is disabled.

## Suggested notice for learners (only after launch approval)

**Practice workbook upload**

You may upload a workbook created for this Excel exercise so the LearningApp
can check whether the required cells and formulas meet the practice criteria.
Only upload the provided practice workbook. **Do not include personal,
financial, medical, employment, or other sensitive information.**

- Supported format: .xlsx, up to **10 MB**, for one exercise attempt.
- Your upload is stored privately and used to provide deterministic practice
  feedback. The workbook is not sent to an AI service as part of this feature.
- The result is **practice feedback, not proof of independent mastery, exam
  credit, a certification, or a verified skill award**.
- The practice attempt expires **45 minutes** after issuance.
- The proposed retention target is to delete the workbook within **24 hours
  after the attempt expires**, with monitored retries if deletion initially
  fails. The attempt's provisional result and associated workbook digest
  would then be removed with its metadata, after object deletion is confirmed.
- A private issuance timestamp may be kept for up to **48 hours** to enforce
  submission limits; it does not contain workbook cells.
- You can stop the exercise without uploading. The application must offer an
  account-deletion path and explain how pending workbook deletions are handled.

**Only publish this text when a real, monitored deletion process and
account-erasure procedure can substantiate the retention statements.**

## Explicit approval and implementation blockers

- [ ] Owner approves the maximum 10 MB upload and synthetic-only learning scope.
- [ ] Privacy/legal review approves retention durations, disclosure and user
  rights language for intended jurisdictions.
- [ ] Product provides accessible consent/notice **before** selecting a file,
  plus clear cancel, expired-attempt and unsuccessful-upload states.
- [ ] Hosted Storage/DB integration tests pass; no signed URL, direct learner
  uploads, arbitrary worksheets, or AI transfer.
- [ ] Retention scheduler, bounded retries, operational alerts and deletion
  evidence verify the 24h target; account deletion revokes sessions first and
  reconciles actual object prefixes.
- [ ] Host/IAM and network isolation verified; credentials never appear in
  the public web process or parser worker.
- [ ] No outcome can automatically write verified learning evidence or alter
  mastery scores.
- [ ] Operational incident response, human support path and audit owner are
  established without exposing private file names or workbook contents.

**Do not imply consent, user acceptance, privacy approval, or service
activation from this draft.**
