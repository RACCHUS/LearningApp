import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/providers/learning_target_provider.dart';
import 'package:learning_pwa/screens/learn/start_learning_screen.dart';
import 'package:learning_pwa/screens/targets/target_detail_screen.dart';

void main() {
  group('TargetDetailScreen Widget Tests', () {
    testWidgets('renders target title, badge, and action buttons', (tester) async {
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
            targetDetailProvider('target-hvac').overrideWith(
              (ref) => Future.value(sampleTarget),
            ),
            targetVersionProvider('target-hvac').overrideWith(
              (ref) => Future.value(sampleVersion),
            ),
          ],
          child: const MaterialApp(
            home: TargetDetailScreen(targetId: 'target-hvac'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Florida Air Conditioning Contractor Class A'), findsOneWidget);
      expect(find.text('Licensure Exam'), findsOneWidget);
      expect(find.text('Florida DBPR'), findsOneWidget);
      expect(find.text('Florida'), findsOneWidget);
      expect(find.byKey(const Key('target-start-learning-button')), findsOneWidget);
      expect(find.byKey(const Key('target-view-outline-button')), findsOneWidget);
      expect(find.text('About this Target'), findsOneWidget);
      expect(find.text('Curriculum Version 2026-v1'), findsOneWidget);
    });
  });

  group('StartLearningScreen Widget Tests', () {
    testWidgets('renders scope mode options and handles confirmation', (tester) async {
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
      expect(find.byKey(const Key('start-learning-confirm-button')), findsOneWidget);
    });
  });
}
