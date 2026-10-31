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
          domainWeight: 0.35,
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

    testWidgets('renders Practice Allocation and strictly omits Blueprint Weight', (tester) async {
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

      // Verify "Practice Allocation:" is rendered for domains
      expect(find.text('Practice Allocation: 25%'), findsOneWidget);
      expect(find.text('Practice Allocation: 35%'), findsOneWidget);

      // Verify "Blueprint Weight" claim is strictly absent
      expect(find.textContaining('Blueprint Weight'), findsNothing);
    });
  });
}
