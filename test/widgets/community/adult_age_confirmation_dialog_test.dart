import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/community/adult_age_confirmation_dialog.dart';

void main() {
  group('AdultAgeConfirmationDialog (ECO-00B, Invariant 3)', () {
    testWidgets('enables continue button only when age checkbox is checked', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdultAgeConfirmationDialog(),
          ),
        ),
      );

      expect(find.text('Age Eligibility Confirmation'), findsOneWidget);
      expect(find.text('I attest that I am 18 years of age or older.'), findsOneWidget);

      final continueButton = tester.widget<FilledButton>(
        find.byKey(const Key('confirm_adult_button')),
      );
      expect(continueButton.onPressed, isNull);

      // Check the checkbox
      await tester.tap(find.byKey(const Key('adult_age_checkbox')));
      await tester.pump();

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('confirm_adult_button')),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('cancels and returns false when under 18 is tapped', (tester) async {
      bool? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await AdultAgeConfirmationDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I am under 18 (Cancel)'));
      await tester.pumpAndSettle();

      expect(dialogResult, isFalse);
    });
  });
}
