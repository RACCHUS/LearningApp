import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/widgets/analytics/item_psychometrics_sheet.dart';

void main() {
  group('ItemPsychometricsSheet Widget Tests (ER-09a, ER-09b, OPP-3)', () {
    testWidgets('renders unobserved state with default metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemPsychometricsSheet(
              itemId: 'item-unobs-1',
              itemPrompt: 'What is the primary function of an expansion tank?',
              status: ItemPsychometricStatus.unobserved,
            ),
          ),
        ),
      );

      expect(find.text('Item Psychometrics & Calibration'), findsOneWidget);
      expect(find.text('Item ID: item-unobs-1'), findsOneWidget);
      expect(find.text('Unobserved Item'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // Observation count
    });

    testWidgets('renders preliminary Elo ordering state with difficulty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ItemPsychometricsSheet(
              itemId: 'item-elo-2',
              itemPrompt: 'Calculate the total dynamic head of the pump.',
              status: ItemPsychometricStatus(
                status: 'preliminary_elo_ordering',
                observationCount: 35,
                difficultyEstimate: 0.45,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Preliminary Elo Ordering'), findsOneWidget);
      expect(find.text('35'), findsOneWidget);
      expect(find.text('0.45'), findsOneWidget);
    });

    testWidgets('renders calibrated 2PL IRT state with ICC preview and closes on tap', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemPsychometricsSheet(
              itemId: 'item-calib-3',
              itemPrompt: 'Explain the difference between laminar and turbulent flow.',
              status: const ItemPsychometricStatus(
                status: 'calibrated',
                observationCount: 65,
                difficultyEstimate: 0.30,
                standardError: 0.18,
                discriminationEstimate: 1.45,
              ),
              irtParameters: const IrtParameters2Pl(
                discrimination: 1.45,
                difficulty: 0.30,
                standardError: 0.18,
                converged: true,
              ),
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      expect(find.text('Calibrated 2PL IRT Item'), findsOneWidget);
      expect(find.text('65'), findsOneWidget);
      expect(find.text('0.30'), findsOneWidget);
      expect(find.text('1.45'), findsOneWidget);
      expect(find.text('±0.180'), findsOneWidget);
      expect(find.text('Item Characteristic Curve (2PL ICC)'), findsOneWidget);
      expect(find.text('θ = 0.0'), findsOneWidget);

      await tester.tap(find.byKey(const Key('item_psychometrics_close_button')));
      expect(closed, isTrue);
    });
  });
}

