/// MKT-002 / FLAG-015: hard owner-approved safety latch for BYOK.
///
/// This remains OFF even if a remote feature registry accidentally enables
/// ai.byok. Only a build made with `--dart-define=BYOK_RELEASE_APPROVED=true`
/// turns it on, and that build needs owner approval (AGENTS.md). Every
/// default and preview build keeps it OFF; CI sets it only in the dedicated
/// BYOK test step, never in a deployed build. Turning BYOK on for learners
/// also needs the live `ai.byok` switch; see docs/product/BYOK_ROLLOUT.md.
abstract final class ByokReleaseGate {
  static const bool enabled = bool.fromEnvironment('BYOK_RELEASE_APPROVED');

  static const String unavailableMessage =
      'Bring Your Own Key AI is temporarily disabled while credential '
      'handling, provider compatibility, and privacy safeguards are repaired. '
      'Your other learning features remain available.';

  static void requireEnabled() {
    if (!enabled) {
      throw StateError(unavailableMessage);
    }
  }
}
