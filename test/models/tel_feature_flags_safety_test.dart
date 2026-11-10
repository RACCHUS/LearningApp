import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_strategy.dart';

void main() {
  test('Fast stays available for all exam targets while unverified', () {
    const flags = TelFeatureFlags();
    expect(flags.fastEnabled, true);
    expect(flags.isFastEnabledForTarget('clep-introductory-psychology'), true);
    // The historical short list is NOT a restriction; owner kept broad Fast.
    expect(flags.isFastEnabledForTarget('different-exam', isExamTarget: true), true);
    expect(flags.isFastEnabledForTarget(null, isExamTarget: true), true);
    expect(flags.isFastEnabledForTarget('not-an-exam', isExamTarget: false), false);
  });

  test('Explicit emergency OFF still shuts off Fast without affecting Overview',
      () {
    const flags = TelFeatureFlags(fastEnabled: false);
    expect(flags.isFastEnabledForTarget('any-exam'), false);
    expect(flags.isOverviewEnabledForTarget('clep-introductory-psychology'), true);
  });

  test('Overview retains its existing target restriction', () {
    const flags = TelFeatureFlags();
    expect(flags.isOverviewEnabledForTarget('other-target'), false);
  });
}
