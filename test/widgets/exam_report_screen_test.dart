import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/assessment_engine/exam_diagnostic_report.dart';
import 'package:learning_pwa/models/user_concept_state.dart';
import 'package:learning_pwa/screens/assessment/exam_report_screen.dart';

void main() {
  group('ExamReportScreen Widget Tests', () {
    final now = DateTime.now();

    final sampleReport = ExamDiagnosticReport(
      sessionId: 'test-session-123',
      targetVersionId: 'tv-test-1',
      completedAt: now,
      durationTaken: const Duration(minutes: 45),
      officialFacts: const OfficialExamFacts(
        examCode: 'SY0-701',
        title: 'CompTIA Security+ Practice Test',
        publishedPassingScore: null,
        scoreScale: null,
        timeLimitMinutes: 90,
      ),
      readinessEstimate: const AppReadinessEstimate(
        practiceScorePercentage: 80.0,
        estimatedScaledScore: null,
        readinessBand: TargetReadinessBand.developing,
        readinessHeadline: 'Approaching Practice Readiness',
        readinessSummary: 'Solid performance across practice domains.',
        totalQuestions: 20,
        correctCount: 16,
        partialCount: 0,
        incorrectCount: 4,
        unansweredCount: 0,
        totalScoreEarned: 16.0,
      ),
      domainDiagnostics: const [
        DomainDiagnostic(
          domainId: 'dom-1',
          domainCode: '1.0',
          domainTitle: 'General Security Concepts',
          domainWeight: 0.25,
          totalQuestions: 5,
          correctQuestions: 4,
          scoreEarned: 4.0,
          percentage: 80.0,
          evidenceLevel: DomainEvidenceLevel.strongEvidence,
        ),
        DomainDiagnostic(
          domainId: 'dom-2',
          domainCode: '2.0',
          domainTitle: 'Threats, Vulnerabilities & Mitigations',
          domainWeight: 0.75,
          totalQuestions: 7,
          correctQuestions: 5,
          scoreEarned: 5.0,
          percentage: 71.4,
          evidenceLevel: DomainEvidenceLevel.moderateEvidence,
        ),
      ],
      remediationRecommendations: const [
        RemediationRecommendation(
          conceptId: 'conc-1',
          conceptName: 'Symmetric Cryptography',
          domainTitle: 'General Security Concepts',
          priority: 'high',
          rationale: 'Review AES and DES key size differences.',
        ),
      ],
      scoredItems: const [
        ScoredItemResult(
          itemId: 'item-1',
          prompt: 'Which cipher uses a 128-bit block size?',
          domainCode: '1.0',
          userResponse: 'AES',
          correctResponse: 'AES',
          isCorrect: true,
          scoreEarned: 1.0,
          explanation: 'AES uses a 128-bit block size.',
        ),
      ],
    );

    testWidgets('renders Target Practice Allocation and strictly omits Blueprint Weight', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: ExamReportScreen(report: sampleReport),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and practice-only context
      expect(find.text('Practice Results'), findsOneWidget);
      expect(find.textContaining('PRACTICE ONLY'), findsOneWidget);

      // Verify "Target Practice Allocation:" is rendered for domains
      expect(find.text('Target Practice Allocation: 25%'), findsOneWidget);
      expect(find.text('Target Practice Allocation: 75%'), findsOneWidget);

      // Verify "Blueprint Weight" claim is strictly absent
      expect(find.textContaining('Blueprint Weight'), findsNothing);
    });

    testWidgets('normalizes 19 equal-weight domains to Target Practice Allocation: 5%', (tester) async {
      tester.view.physicalSize = const Size(1200, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final nineteenDomains = List.generate(
        19,
        (i) => DomainDiagnostic(
          domainId: 'dom-${i + 1}',
          domainCode: '${i + 1}.0',
          domainTitle: 'Domain ${i + 1}',
          domainWeight: 1.0, // Unnormalized stored production weight
          totalQuestions: 5,
          correctQuestions: 4,
          scoreEarned: 4.0,
          percentage: 80.0,
          evidenceLevel: DomainEvidenceLevel.strongEvidence,
        ),
      );

      final nineteenReport = ExamDiagnosticReport(
        sessionId: 'test-19-domains',
        targetVersionId: 'tv-2026-1',
        completedAt: now,
        durationTaken: const Duration(minutes: 60),
        officialFacts: const OfficialExamFacts(
          examCode: 'CONTRACTOR-2026.1',
          title: 'Florida Contractor Practice Exam',
          publishedPassingScore: null,
          scoreScale: null,
          timeLimitMinutes: 90,
        ),
        readinessEstimate: const AppReadinessEstimate(
          practiceScorePercentage: 80.0,
          estimatedScaledScore: null,
          readinessBand: TargetReadinessBand.strongCoverage,
          readinessHeadline: 'Strong Practice Performance',
          readinessSummary: 'Broad coverage across 19 practice domains.',
          totalQuestions: 95,
          correctCount: 76,
          partialCount: 0,
          incorrectCount: 19,
          unansweredCount: 0,
          totalScoreEarned: 76.0,
        ),
        domainDiagnostics: nineteenDomains,
        remediationRecommendations: const [],
        scoredItems: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExamReportScreen(report: nineteenReport),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that unnormalized 1.0 weight displays normalized 5%, not 100%
      expect(find.text('Target Practice Allocation: 5%'), findsWidgets);
      expect(find.text('Target Practice Allocation: 100%'), findsNothing);
      expect(find.textContaining('Blueprint Weight'), findsNothing);
    });
  });
}
