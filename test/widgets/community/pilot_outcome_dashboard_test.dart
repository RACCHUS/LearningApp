import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/community/outcome_assessment_service.dart';
import 'package:learning_pwa/widgets/community/pilot_outcome_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PilotOutcomeDashboard renders aggregate metrics and distribution',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = OutcomeAssessmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PilotOutcomeDashboard(
              assessmentService: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Field Pilot Outcomes & Gain Evidence'), findsOneWidget);
    expect(find.text('Sample Size'), findsOneWidget);
    expect(find.text('Mean Pre-Score'), findsOneWidget);
    expect(find.text('Mean Post-Score'), findsOneWidget);
    expect(find.text('Mean Gain (Hake g)'), findsOneWidget);
    expect(find.text('Normalized Gain Distribution'), findsOneWidget);
    expect(find.textContaining('Clarity:'), findsOneWidget);
    expect(find.textContaining('Audio:'), findsOneWidget);
  });
}

