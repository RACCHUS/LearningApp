import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_blueprint.dart';
import 'package:learning_pwa/models/assessment_engine/mock_exam_session.dart';
import 'package:learning_pwa/models/assessment_item.dart';
import 'package:learning_pwa/models/lesson.dart';
import 'package:learning_pwa/models/lesson_block.dart';
import 'package:learning_pwa/models/unified_lesson.dart';
import 'package:learning_pwa/services/assessment/exam_evaluation_service.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CLEP Introductory Psychology Assessment & Learner Experience Tests', () {
    late Map<String, dynamic> manifest;
    late List<dynamic> domains;
    final now = DateTime.now();

    setUpAll(() {
      final file = File('content/clep_introductory_psychology.yaml');
      expect(file.existsSync(), isTrue, reason: 'CLEP Psychology manifest must exist');
      final yamlContent = file.readAsStringSync();
      manifest = (loadYaml(yamlContent) as YamlMap).cast<String, dynamic>();
      domains = manifest['domains'] as List<dynamic>;
    });

    test('Loads 13 domains and builds MockExamBlueprint matching official College Board quotas', () {
      final domainConstraints = <DomainWeightConstraint>[];
      for (final d in domains) {
        final dMap = (d as YamlMap).cast<String, dynamic>();
        domainConstraints.add(DomainWeightConstraint(
          domainId: 'dom-${dMap['code']}',
          domainCode: dMap['code'] as String,
          domainTitle: dMap['title'] as String,
          weight: (dMap['weight'] as num).toDouble(),
        ));
      }

      expect(domainConstraints.length, equals(13));

      final blueprint = MockExamBlueprint(
        targetVersionId: 'tv-clep-psyc-2026',
        examCode: 'CLEP-PSYC',
        title: 'CLEP Introductory Psychology Examination Simulation',
        domainWeights: domainConstraints,
        officialPassingScore: 50,
        officialScoreScale: '20-80 (Diagnostic Reporting)',
        defaultQuestionCount: 95,
        timeLimitMinutes: 90,
      );

      // Verify exact 95-question largest-remainder domain quota allocation
      final quotas = blueprint.computeDomainQuotas(95);
      expect(quotas.values.fold<int>(0, (sum, c) => sum + c), equals(95));

      // Domain-by-domain quota verification against College Board specifications
      expect(quotas['dom-1.0'], equals(11)); // 11–12%
      expect(quotas['dom-2.0'], equals(9));  // 8–9%
      expect(quotas['dom-3.0'], equals(7));  // 7–8%
      expect(quotas['dom-4.0'], equals(5));  // 5–6%
      expect(quotas['dom-5.0'], equals(8));  // 8–9%
      expect(quotas['dom-6.0'], equals(9));  // 8–9%
      expect(quotas['dom-7.0'], equals(5));  // 5–6%
      expect(quotas['dom-8.0'], equals(8));  // 8–9%
      expect(quotas['dom-9.0'], equals(7));  // 7–8%
      expect(quotas['dom-10.0'], equals(8)); // 8–9%
      expect(quotas['dom-11.0'], equals(6)); // 6–7%
      expect(quotas['dom-12.0'], equals(9)); // 9–10%
      expect(quotas['dom-13.0'], equals(3)); // 3–4%
    });

    test('Parses all 95 simulation items and verifies protected metadata and Haladyna standards', () {
      final allItems = <AssessmentItem>[];
      int itemCounter = 0;

      for (final d in domains) {
        final dMap = (d as YamlMap).cast<String, dynamic>();
        final objectives = dMap['objectives'] as List<dynamic>;
        for (final o in objectives) {
          final oMap = (o as YamlMap).cast<String, dynamic>();
          final lessons = oMap['lessons'] as List<dynamic>;
          for (final l in lessons) {
            final lMap = (l as YamlMap).cast<String, dynamic>();
            final items = lMap['assessment_items'] as List<dynamic>? ?? [];
            for (final itm in items) {
              itemCounter++;
              final itmMap = (itm as YamlMap).cast<String, dynamic>();
              final respSpec = (itmMap['response_spec'] as YamlMap).cast<String, dynamic>();
              final scorSpec = (itmMap['scoring_spec'] as YamlMap).cast<String, dynamic>();
              final meta = (itmMap['metadata'] as YamlMap?)?.cast<String, dynamic>() ?? {};

              final item = AssessmentItem(
                id: 'clep-psyc-item-$itemCounter',
                prompt: itmMap['prompt'] as String,
                interactionType: AssessmentInteractionType.fromString(itmMap['interaction_type'] as String),
                responseSpec: {
                  'options': (respSpec['options'] as YamlList).map((e) => e.toString()).toList(),
                },
                scoringSpec: {
                  'correct_index': scorSpec['correct_index'] as int,
                },
                explanation: itmMap['explanation'] as String?,
                difficulty: itmMap['difficulty'] as String? ?? 'intermediate',
                cognitiveLevel: itmMap['cognitive_level'] as String? ?? 'comprehension',
                metadata: meta,
                createdAt: now,
                updatedAt: now,
              );

              allItems.add(item);
            }
          }
        }
      }

      expect(allItems.length, equals(95), reason: 'Must have exactly 95 simulation questions');

      // Verify protected metadata and Haladyna compliance
      for (final item in allItems) {
        expect(item.interactionType, equals(AssessmentInteractionType.singleChoice));
        final options = item.responseSpec['options'] as List<String>;
        expect(options.length, equals(4), reason: 'Every item must have 4 options');

        for (final opt in options) {
          expect(opt.toLowerCase(), isNot(contains('all of the above')));
          expect(opt.toLowerCase(), isNot(contains('none of the above')));
        }

        expect(item.explanation, isNotNull);
        expect(item.explanation!.length, greaterThanOrEqualTo(25));
        expect(item.metadata['bank'], equals('simulation_exam'));
        expect(item.metadata['is_protected'], isTrue);
      }
    });

    test('Simulates complete 90-minute timed exam session with scoring and domain diagnostic reporting', () {
      final domainConstraints = <DomainWeightConstraint>[];
      final itemDomainMap = <String, String>{};
      final allItems = <AssessmentItem>[];
      int itemCounter = 0;

      for (final d in domains) {
        final dMap = (d as YamlMap).cast<String, dynamic>();
        final domCode = dMap['code'] as String;
        domainConstraints.add(DomainWeightConstraint(
          domainId: 'dom-$domCode',
          domainCode: domCode,
          domainTitle: dMap['title'] as String,
          weight: (dMap['weight'] as num).toDouble(),
        ));

        for (final o in (dMap['objectives'] as List<dynamic>)) {
          final oMap = (o as YamlMap).cast<String, dynamic>();
          for (final l in (oMap['lessons'] as List<dynamic>)) {
            final lMap = (l as YamlMap).cast<String, dynamic>();
            for (final itm in (lMap['assessment_items'] as List<dynamic>? ?? [])) {
              itemCounter++;
              final itmId = 'item-$itemCounter';
              itemDomainMap[itmId] = domCode;

              final itmMap = (itm as YamlMap).cast<String, dynamic>();
              final respSpec = (itmMap['response_spec'] as YamlMap).cast<String, dynamic>();
              final scorSpec = (itmMap['scoring_spec'] as YamlMap).cast<String, dynamic>();

              allItems.add(AssessmentItem(
                id: itmId,
                prompt: itmMap['prompt'] as String,
                interactionType: AssessmentInteractionType.singleChoice,
                responseSpec: {
                  'options': (respSpec['options'] as YamlList).map((e) => e.toString()).toList(),
                },
                scoringSpec: {
                  'correct_index': scorSpec['correct_index'] as int,
                },
                explanation: itmMap['explanation'] as String?,
                createdAt: now,
                updatedAt: now,
              ));
            }
          }
        }
      }

      final blueprint = MockExamBlueprint(
        targetVersionId: 'tv-clep-psyc-2026',
        examCode: 'CLEP-PSYC',
        title: 'CLEP Introductory Psychology Examination Simulation',
        domainWeights: domainConstraints,
        officialPassingScore: 50,
        officialScoreScale: '20-80 (Diagnostic Reporting)',
        defaultQuestionCount: 95,
        timeLimitMinutes: 90,
      );

      final userResponses = <String, dynamic>{};
      // Simulate candidate taking the exam: answer first 70 questions correctly, 15 incorrectly, leave 10 unanswered
      for (int i = 0; i < 70; i++) {
        final item = allItems[i];
        final correctIdx = item.scoringSpec['correct_index'] as int;
        userResponses[item.id] = correctIdx;
      }
      for (int i = 70; i < 85; i++) {
        final item = allItems[i];
        final correctIdx = item.scoringSpec['correct_index'] as int;
        final wrongIdx = (correctIdx + 1) % 4;
        userResponses[item.id] = wrongIdx;
      }

      final session = MockExamSession(
        id: 'session-clep-psyc-001',
        blueprint: blueprint,
        items: allItems,
        itemDomainMap: itemDomainMap,
        userResponses: userResponses,
        flaggedItemIds: {allItems[5].id, allItems[15].id, allItems[25].id},
        timeLimit: const Duration(minutes: 90),
        startedAt: now,
        status: ExamSessionStatus.completed,
      );

      expect(session.totalQuestions, equals(95));
      expect(session.answeredCount, equals(85));
      expect(session.unansweredCount, equals(10));
      expect(session.flaggedCount, equals(3));
      expect(session.timeLimit.inMinutes, equals(90));

      // Evaluate exam using the platform's ExamEvaluationService
      final report = ExamEvaluationService().evaluateExam(session);
      expect(report.readinessEstimate.totalQuestions, equals(95));
      expect(report.readinessEstimate.correctCount, equals(70));
      expect(report.readinessEstimate.unansweredCount, equals(10));
      expect(report.readinessEstimate.incorrectCount, equals(15));
      expect(report.readinessEstimate.practiceScorePercentage, closeTo(73.68, 0.1));

      // Verify domain diagnostics generated across all 13 domains
      expect(report.domainDiagnostics.length, equals(13));
      for (final domDiag in report.domainDiagnostics) {
        expect(domDiag.totalQuestions, greaterThan(0));
        expect(domDiag.percentage, inInclusiveRange(0.0, 100.0));
      }
    });

    test('Demonstrates all 25 lessons load as UnifiedLessons with instructional blocks', () {
      int lessonCount = 0;
      for (final d in domains) {
        final dMap = (d as YamlMap).cast<String, dynamic>();
        for (final o in (dMap['objectives'] as List<dynamic>)) {
          final oMap = (o as YamlMap).cast<String, dynamic>();
          for (final l in (oMap['lessons'] as List<dynamic>)) {
            lessonCount++;
            final lMap = (l as YamlMap).cast<String, dynamic>();
            final blocksRaw = lMap['blocks'] as List<dynamic>? ?? [];

            final blocks = blocksRaw.map((b) {
              final bMap = (b as YamlMap).cast<String, dynamic>();
              final content = (bMap['content'] as YamlMap).cast<String, dynamic>();
              return LessonBlock(
                id: 'block-$lessonCount-${bMap['sort_order']}',
                lessonId: 'lesson-$lessonCount',
                sortOrder: bMap['sort_order'] as int,
                blockType: LessonBlockType.fromString(bMap['block_type'] as String),
                content: content,
                createdAt: now,
                updatedAt: now,
              );
            }).toList();

            final lessonModel = Lesson(
              id: 'lesson-$lessonCount',
              title: lMap['title'] as String,
              description: lMap['description'] as String?,
              tags: (lMap['tags'] as YamlList?)?.map((e) => e.toString()).toList() ?? [],
              userId: 'system-clep',
              terms: const [],
              questions: const [],
              concepts: const [],
              createdAt: now,
              updatedAt: now,
            );

            final unifiedLesson = UnifiedLesson(
              lesson: lessonModel,
              blocks: blocks,
            );

            expect(unifiedLesson.lesson.title, isNotEmpty);
            expect(unifiedLesson.blocks, isNotEmpty);
            expect(unifiedLesson.blocks.any((b) => b.blockType == LessonBlockType.markdown), isTrue);
          }
        }
      }

      expect(lessonCount, equals(25), reason: 'Must deliver all 25 official curriculum lessons');
    });
  });
}
