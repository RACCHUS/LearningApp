import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/daily_plan.dart';
import 'package:learning_pwa/providers/daily_plan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewEmphasisNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to balanced when no preference is saved', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reviewEmphasisProvider.notifier);
      await notifier.load();

      expect(container.read(reviewEmphasisProvider), equals(ReviewEmphasis.balanced));
    });

    test('loads saved preference from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        kReviewEmphasisKey: 'prioritiseReviews',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reviewEmphasisProvider.notifier);
      await notifier.load();

      expect(container.read(reviewEmphasisProvider), equals(ReviewEmphasis.prioritiseReviews));
    });

    test('updates state and persists to SharedPreferences when setEmphasis is called', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reviewEmphasisProvider.notifier);
      await notifier.setEmphasis(ReviewEmphasis.prioritiseNew);

      expect(container.read(reviewEmphasisProvider), equals(ReviewEmphasis.prioritiseNew));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kReviewEmphasisKey), equals('prioritiseNew'));
    });
  });
}

