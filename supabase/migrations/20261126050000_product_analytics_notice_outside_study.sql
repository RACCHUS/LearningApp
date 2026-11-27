-- Approve the product-analytics notice with the outside-study sentence
-- (owner decision 2026-11-26: the owner asked the AI building the app to
-- choose the privacy wording).
--
-- Why a new version: get_companion_outcome_report (20261126010000) counts
-- opted-in learners' use of the outside-study companion. The notice they
-- agreed to now says so (lib/screens/settings/product_analytics_privacy_
-- screen.dart, outsideStudyCountsNotice). A changed notice must not borrow
-- consent given under the old one, so the version changes and the existing
-- trigger analytics.invalidate_old_product_policy() withdraws every prior
-- consent and deletes raw events collected under the old notice.
--
-- On 2026-11-26 production had no opted-in account and no stored event, so
-- nothing is lost. Nothing else changes: collection stays enabled, each
-- person must still be eligible and opt in explicitly, and withdrawal still
-- deletes their events.
UPDATE analytics.product_release_gate
   SET approved_policy_version = 'basic-2026-11-26',
       policy_approved_at = now(),
       reviewed_by = 'owner (wording delegated in chat, 2026-11-26)',
       changed_at = now()
 WHERE id = 1
   AND approved_policy_version IS DISTINCT FROM 'basic-2026-11-26';
