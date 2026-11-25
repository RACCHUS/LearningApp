/// Immutable feature-key catalog shared by Flutter and CI validation.
/// When adding a substantial new feature, add the registry key here, seed it
/// default OFF in the additive migration, and implement both UI/off-path and
/// authoritative server-side guards before marking it release-ready.
///
/// This list does not make the corresponding feature operational by itself.
abstract final class SiteFeatureKeys {
  static const String telFast = 'tel.fast';
  static const String telOverview = 'tel.overview';
  static const String aiByok = 'ai.byok';
  static const String aiManaged = 'ai.managed';
  static const String aiExternalMcp = 'ai.external_mcp';
  static const String aiLocalExperimental = 'ai.local_experimental';
  static const String mcpRemote = 'mcp.remote';
  static const String mcpPersonalRead = 'mcp.personal_read';
  static const String mcpWriteReview = 'mcp.write_review';
  static const String analyticsProductEvents = 'analytics.product_events';
  static const String analyticsPromptQuality = 'analytics.prompt_quality';
  static const String supportDonations = 'support.donations';
  static const String marketingSponsorCards = 'marketing.sponsor_cards';
  static const String marketingAffiliateLinks = 'marketing.affiliate_links';
  static const String marketingDisplayAds = 'marketing.display_ads';
  static const String marketingPaidAcquisition = 'marketing.paid_acquisition';
  static const String seoDynamicEndpoints = 'seo.dynamic_endpoints';
  static const String opsBackgroundJobs = 'ops.nonessential_background_jobs';
  static const String learningCommunityQa = 'learning.community_qa';
  static const String learningSimulations = 'learning.simulations';
  static const String learningQuickRescue = 'learning.quick_rescue';
  static const String aiManualGenerationV2 = 'ai.manual_generation_v2';
  static const String learningAutoGapSuggestions =
      'learning.auto_gap_suggestions';
  static const String contentExternalCompanion = 'content.external_companion';
  static const String contentPublicContribution = 'content.public_contribution';
  static const String contentRefreshProposals = 'content.refresh_proposals';
  static const String learningXpAchievements = 'learning.xp_achievements';
  static const String learningAvatarCustomizer = 'learning.avatar_customizer';
  static const String learningStudyReminders = 'learning.study_reminders';
  static const String learningScratchpad = 'learning.scratchpad';
  static const String learningAnswerRevisions = 'learning.answer_revisions';
  static const String learningReinforcementSuggestions =
      'learning.reinforcement_suggestions';
  static const String learningEducatorProfiles = 'learning.educator_profiles';
  static const String learningCheckDisputes = 'learning.check_disputes';
  static const String contentWantedBoard = 'content.wanted_board';
  static const String contentParametricPractice = 'content.parametric_practice';
  static const String contentFeedbackChips = 'content.feedback_chips';
  static const String learningReadinessCoverageGate =
      'learning.readiness_coverage_gate';
  static const String learningObjectiveReadinessView =
      'learning.objective_readiness_view';
  static const String learningReadinessProjection =
      'learning.readiness_projection';
  static const String contentLearnerResources = 'content.learner_resources';
  static const String contentCompanionCapture = 'content.companion_capture';

  static const Set<String> all = {
    telFast,
    telOverview,
    aiByok,
    aiManaged,
    aiExternalMcp,
    aiLocalExperimental,
    mcpRemote,
    mcpPersonalRead,
    mcpWriteReview,
    analyticsProductEvents,
    analyticsPromptQuality,
    supportDonations,
    marketingSponsorCards,
    marketingAffiliateLinks,
    marketingDisplayAds,
    marketingPaidAcquisition,
    seoDynamicEndpoints,
    opsBackgroundJobs,
    learningCommunityQa,
    learningSimulations,
    learningQuickRescue,
    aiManualGenerationV2,
    learningAutoGapSuggestions,
    contentExternalCompanion,
    contentPublicContribution,
    contentRefreshProposals,
    learningXpAchievements,
    learningAvatarCustomizer,
    learningStudyReminders,
    learningScratchpad,
    learningAnswerRevisions,
    learningReinforcementSuggestions,
    learningEducatorProfiles,
    learningCheckDisputes,
    contentWantedBoard,
    contentParametricPractice,
    contentFeedbackChips,
    learningReadinessCoverageGate,
    learningObjectiveReadinessView,
    learningReadinessProjection,
    contentLearnerResources,
    contentCompanionCapture,
  };
}
