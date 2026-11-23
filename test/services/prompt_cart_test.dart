import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/models/content_generation/coverage_matrix.dart';
import 'package:learning_pwa/providers/learning_support_controller_provider.dart';
import 'package:learning_pwa/providers/manual_generation_v2_provider.dart';
import 'package:learning_pwa/providers/target_coverage_provider.dart';
import 'package:learning_pwa/screens/lessons/prompt_cart_screen.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/prompt_cart.dart';
import 'package:learning_pwa/services/learning_support/bridge_library.dart';
import 'package:learning_pwa/widgets/targets/target_coverage_card.dart';

CoverageNeed need(String code, double priority) => CoverageNeed(
      row: CoverageRow(
        objectiveId: 'o-$code',
        code: code,
        title: 'Topic $code',
        priority: priority,
        cells: const {CoverageRole.check: CoverageState.gap},
      ),
      missing: const [CoverageRole.check],
    );

void main() {
  group('planner', () {
    test('highest reuse value first; ties keep outline order', () {
      final ordered = PromptCart.ordered([need('1', 0.25), need('2', 1), need('3', 0.25)]);
      expect([for (final n in ordered) n.row.code], ['2', '1', '3']);
    });

    test('fewest chats: up to five topics per chat', () {
      final plan = PromptCart.plan(
        [for (var i = 1; i <= 7; i++) need('$i', 1)],
        tier: ModelSizeTier.standard,
      );
      expect(plan.chats, 2);
      expect([for (final b in plan.batches) b.needs.length], [5, 2]);
    });

    test('messages respect the chosen size', () {
      // 5 topics × (explanation + term + 2 questions) = 20 slots.
      final topics = [for (var i = 1; i <= 5; i++) need('$i', 1)];
      expect(PromptCart.plan(topics, tier: ModelSizeTier.compact).messages, 7); // 3 per message
      expect(PromptCart.plan(topics, tier: ModelSizeTier.standard).messages, 3); // 8 per message
      expect(PromptCart.plan(topics, tier: ModelSizeTier.large).messages, 2); // 16 per message
      expect(PromptCart.plan(const [], tier: ModelSizeTier.large).isEmpty, isTrue);
    });
  });

  testWidgets('the cart estimates, lets topics be dropped and starts a chat', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? pushed;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => PromptCartScreen(
          goalTitle: 'Prealgebra',
          needs: [need('6.1', 0.5), need('6.2', 1)],
        ),
      ),
      GoRoute(
        path: '/manual-generation-v2',
        builder: (_, s) {
          pushed = s.uri.toString();
          return const Text('generator');
        },
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    // 2 topics × 4 slots = 8 slots; small chats take 3 per message.
    expect(find.text('About 3 messages in 1 chat. An estimate for a small chat; replies that need '
        'fixing add more.'), findsOneWidget);
    expect(find.text('Chat 1: Topic 6.2, Topic 6.1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prompt-cart-need-o-6.1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('About 2 messages in 1 chat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('prompt-cart-start-0')));
    await tester.pumpAndSettle();
    expect(Uri.parse(pushed!).queryParameters, {'subject': 'Prealgebra', 'ideas': 'Topic 6.2'});
  });

  testWidgets('the coverage card offers the cart only with the generator on', (tester) async {
    Future<void> pump(bool generatorOn) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          manualGenerationV2EnabledProvider.overrideWithValue(generatorOn),
          bridgeLibraryProvider.overrideWith((ref) async => BridgeLibrary(const [])),
          coverageDraftsLoaderProvider.overrideWithValue((ids) async => const {}),
          coverageMatrixLoaderProvider.overrideWithValue((slug) async => {
                'objectives': [
                  for (final c in ['1.1', '1.2'])
                    {
                      'objective_id': 'o-$c', 'code': c, 'title': 'T $c', 'tags': ['x'],
                      'unreviewed': true, 'teach_blocks': 1, 'example_blocks': 1,
                      'practice_items': 1, 'check_items': 0, 'priority': 0.25,
                    },
                ],
              }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TargetCoverageCard(targetSlug: 's', targetVersionId: 'v', goalTitle: 'Goal'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pump(false);
    expect(find.byKey(const Key('target-coverage-prompt-cart')), findsNothing);
    await pump(true);
    expect(find.text('Make all 2 with my AI'), findsOneWidget);
    await tester.tap(find.byKey(const Key('target-coverage-prompt-cart')));
    await tester.pumpAndSettle();
    expect(find.byType(PromptCartScreen), findsOneWidget);
  });
}
