import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/ai/managed_ai_service.dart';

void main() {
  test('server codes map to what the learner is told', () {
    expect(ManagedAiFailure.fromCode('paused'), ManagedAiFailure.paused);
    expect(ManagedAiFailure.fromCode('user_limit'), ManagedAiFailure.userLimit);
    expect(
      ManagedAiFailure.fromCode('rate_limited'),
      ManagedAiFailure.rateLimited,
    );
    expect(ManagedAiFailure.fromCode('blocked'), ManagedAiFailure.blocked);
    for (final c in ['provider_busy', 'empty_reply', 'network']) {
      expect(ManagedAiFailure.fromCode(c), ManagedAiFailure.temporary);
    }
    for (final c in ['off', 'not_configured', 'misconfigured', null, 'x']) {
      expect(ManagedAiFailure.fromCode(c), ManagedAiFailure.unavailable);
    }
  });

  test('every message offers a way forward and states no numbers', () {
    for (final f in ManagedAiFailure.values) {
      expect(RegExp(r'\d').hasMatch(f.message), isFalse, reason: f.name);
    }
    expect(ManagedAiFailure.paused.message, contains('turned off'));
    expect(ManagedAiFailure.paused.message, contains('copy the prompt'));
  });

  test('status is off unless the server says enabled', () {
    expect(ManagedAiStatus.fromJson(null).enabled, isFalse);
    expect(ManagedAiStatus.fromJson({'enabled': false}).enabled, isFalse);
    final s = ManagedAiStatus.fromJson({
      'enabled': true,
      'paused': false,
      'remaining_today': 7,
      'daily_limit': 10,
    });
    expect(s.enabled, isTrue);
    expect(s.remainingToday, 7);
    expect(s.dailyLimit, 10);
  });
}
