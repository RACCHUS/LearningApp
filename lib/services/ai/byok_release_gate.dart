/// MKT-002 / FLAG-015: hard owner-approved safety latch for BYOK.
///
/// This remains OFF even if a remote feature registry accidentally enables
/// ai.byok. A later independent security review, provider compatibility tests
/// and owner approval are required before changing it.
abstract final class ByokReleaseGate {
  static const bool enabled = false;

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
