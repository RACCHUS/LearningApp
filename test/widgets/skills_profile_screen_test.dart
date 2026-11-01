import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/skill.dart';
import 'package:learning_pwa/providers/skill_stats_provider.dart';
import 'package:learning_pwa/screens/skills/skills_profile_screen.dart';

class _FakeUserSkillStatsNotifier extends StateNotifier<AsyncValue<List<UserSkillStats>>>
    implements UserSkillStatsNotifier {
  _FakeUserSkillStatsNotifier(List<UserSkillStats> stats)
      : super(AsyncValue.data(stats));

  @override
  Future<void> refresh() async {}

  @override
  UserSkillStats? getStatsForSkill(String skillId) => null;

  @override
  List<UserSkillStats> getTopSkills({int limit = 5}) => [];

  @override
  List<UserSkillStats> getNeedsPractice({int limit = 5}) => [];
}

void main() {
  group('SkillsProfileScreen & SkillsSummaryCard verification isolation', () {
    testWidgets('excludes unverified/practice skills from verified average level calculation', (tester) async {
      final now = DateTime.now();
      final stats = [
        UserSkillStats(
          id: 'stat-1',
          userId: 'user-1',
          skillId: 'skill-verified',
          level: 80,
          isVerified: true,
          createdAt: now,
          updatedAt: now,
          skill: Skill(
            id: 'skill-verified',
            name: 'Verified Dart',
            slug: 'verified-dart',
            createdAt: now,
          ),
        ),
        UserSkillStats(
          id: 'stat-2',
          userId: 'user-1',
          skillId: 'skill-unverified',
          level: 20, // Low unverified score should NOT pull down the 80 verified level
          isVerified: false,
          createdAt: now,
          updatedAt: now,
          skill: Skill(
            id: 'skill-unverified',
            name: 'Practice Python',
            slug: 'practice-python',
            createdAt: now,
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userSkillStatsProvider.overrideWith((ref) => _FakeUserSkillStatsNotifier(stats)),
            skillsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: SkillsProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total skills should report 2
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Total Skills'), findsOneWidget);

      // Verified Level should be 80 in summary card and 80 in the stat card
      expect(find.text('80'), findsNWidgets(2));
      expect(find.text('Verified Level'), findsOneWidget);

      // Verified count should be 1
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      // Exclusion note should be visible
      expect(find.text('1 practice/unverified skill excluded from verified level'), findsOneWidget);

      // Overall verified level label should be visible
      expect(find.text('Overall Verified Skill Level'), findsOneWidget);

      // The unverified card should render the Practice badge
      expect(find.text('Practice'), findsOneWidget);
    });

    testWidgets('displays practice mode state when all user skill assessments are unverified', (tester) async {
      final now = DateTime.now();
      final stats = [
        UserSkillStats(
          id: 'stat-1',
          userId: 'user-1',
          skillId: 'skill-1',
          level: 90,
          isVerified: false,
          createdAt: now,
          updatedAt: now,
          skill: Skill(
            id: 'skill-1',
            name: 'Legacy Practice Skill',
            slug: 'legacy-practice-skill',
            createdAt: now,
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userSkillStatsProvider.overrideWith((ref) => _FakeUserSkillStatsNotifier(stats)),
            skillsProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: SkillsProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verified level should be 0 because 0 verified skills exist
      expect(find.text('0'), findsNWidgets(2)); // Verified Level 0 and Verified count 0
      expect(find.text('No verified skill assessments yet (Practice mode)'), findsOneWidget);
      expect(find.text('1 practice/unverified skill excluded from verified level'), findsOneWidget);
      expect(find.text('Practice'), findsOneWidget);
    });
  });
}