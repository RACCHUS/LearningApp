import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/screens/learn/start_learning_screen.dart';
import 'package:learning_pwa/screens/targets/target_detail_screen.dart';
import 'package:learning_pwa/screens/targets/target_outline_screen.dart';

void main() {
  testWidgets(
    'official published outline offers personal study, not curriculum editing',
    (tester) async {
      final target = LearningTarget(
        id: 'official-target',
        targetType: TargetType.certification,
        title: 'Security+',
        slug: 'security-plus',
        isOfficial: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final version = TargetVersion(
        id: 'official-version',
        targetId: target.id,
        versionCode: 'v1',
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _GuestAuthNotifier()),
            targetDetailProvider(
              target.id,
            ).overrideWith((ref) => Future.value(target)),
            targetVersionProvider(
              target.id,
            ).overrideWith((ref) => Future.value(version)),
            targetCurriculumNodesProvider(
              version.id,
            ).overrideWith((ref) => Future.value(<CurriculumNode>[])),
          ],
          child: MaterialApp(home: TargetOutlineScreen(targetId: target.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Personal Lesson'), findsOneWidget);
      expect(find.text('Add Topic'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('TargetDetailScreen Widget Tests', () {
    testWidgets('renders target title, badge, and action buttons', (
      tester,
    ) async {
      final sampleTarget = LearningTarget(
        id: 'target-hvac',
        targetType: TargetType.licensureExam,
        title: 'Florida Air Conditioning Contractor Class A',
        slug: 'florida-ac-class-a',
        providerName: 'Florida DBPR',
        jurisdiction: 'Florida',
        emoji: '❄️',
        description: 'Comprehensive licensure exam preparation',
        isOfficial: true,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final sampleVersion = TargetVersion(
        id: 'ver-2026',
        targetId: 'target-hvac',
        versionCode: '2026-v1',
        title: '2026 Official Exam Specification',
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetDetailProvider(
              'target-hvac',
            ).overrideWith((ref) => Future.value(sampleTarget)),
            targetVersionProvider(
              'target-hvac',
            ).overrideWith((ref) => Future.value(sampleVersion)),
          ],
          child: const MaterialApp(
            home: TargetDetailScreen(targetId: 'target-hvac'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Florida Air Conditioning Contractor Class A'),
        findsOneWidget,
      );
      expect(find.text('Licensure Exam'), findsOneWidget);
      expect(find.text('Florida DBPR'), findsOneWidget);
      expect(find.text('Florida'), findsOneWidget);
      expect(
        find.byKey(const Key('target-start-learning-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('target-view-outline-button')),
        findsOneWidget,
      );
      expect(find.text('About this Target'), findsOneWidget);
      expect(find.text('Curriculum Version 2026-v1'), findsOneWidget);
    });
  });

  group('StartLearningScreen Widget Tests', () {
    testWidgets('renders scope mode options and handles confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StartLearningScreen(
              title: 'Cisco CCNA',
              rootType: ContextRootType.target,
              rootId: 'target-ccna',
              emoji: '🌐',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Configure Cisco CCNA'), findsOneWidget);
      expect(find.text('Customize Learning Scope'), findsOneWidget);
      expect(find.text('Core + Prerequisites (Recommended)'), findsOneWidget);
      expect(find.text('Core Requirements Only'), findsOneWidget);
      expect(find.text('Custom Configuration'), findsOneWidget);
      expect(
        find.byKey(const Key('start-learning-confirm-button')),
        findsOneWidget,
      );
    });
  });
}

class _GuestAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _GuestAuthNotifier() : super(GuestMode());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
