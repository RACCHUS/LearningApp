import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/calculator/scientific_calculator_widget.dart';

void main() {
  group('ScientificCalculatorEngine Unit Tests', () {
    test('evaluates basic arithmetic operations and respects precedence', () {
      expect(ScientificCalculatorEngine.evaluate('2 + 3').format(), '5');
      expect(ScientificCalculatorEngine.evaluate('15 - 8').format(), '7');
      expect(ScientificCalculatorEngine.evaluate('6 * 7').format(), '42');
      expect(ScientificCalculatorEngine.evaluate('6 × 7').format(), '42');
      expect(ScientificCalculatorEngine.evaluate('20 / 4').format(), '5');
      expect(ScientificCalculatorEngine.evaluate('20 ÷ 4').format(), '5');
      // Precedence: multiplication before addition
      expect(ScientificCalculatorEngine.evaluate('2 + 3 * 4').format(), '14');
      // Parentheses override
      expect(ScientificCalculatorEngine.evaluate('(2 + 3) * 4').format(), '20');
    });

    test('evaluates exponents and powers', () {
      expect(ScientificCalculatorEngine.evaluate('2^3').format(), '8');
      expect(ScientificCalculatorEngine.evaluate('5^2').format(), '25');
      expect(ScientificCalculatorEngine.evaluate('4^(0.5)').format(), '2');
      // Power precedence over multiplication
      expect(ScientificCalculatorEngine.evaluate('3 * 2^3').format(), '24');
    });

    test('evaluates mathematical functions: sqrt, log, ln', () {
      expect(ScientificCalculatorEngine.evaluate('sqrt(16)').format(), '4');
      expect(ScientificCalculatorEngine.evaluate('sqrt(100)').format(), '10');
      expect(ScientificCalculatorEngine.evaluate('log(100)').format(), '2');
      expect(ScientificCalculatorEngine.evaluate('log(1000)').format(), '3');
      expect(ScientificCalculatorEngine.evaluate('ln(1)').format(), '0');
      expect(ScientificCalculatorEngine.evaluate('ln(e)').format(), '1');
    });

    test('evaluates factorials', () {
      expect(ScientificCalculatorEngine.evaluate('0!').format(), '1');
      expect(ScientificCalculatorEngine.evaluate('1!').format(), '1');
      expect(ScientificCalculatorEngine.evaluate('5!').format(), '120');
      expect(ScientificCalculatorEngine.evaluate('6!').format(), '720');
    });

    test('evaluates mathematical constants pi and e', () {
      final piRes = ScientificCalculatorEngine.evaluate('pi').value!;
      expect(piRes, closeTo(3.14159, 0.0001));

      final eRes = ScientificCalculatorEngine.evaluate('e').value!;
      expect(eRes, closeTo(2.71828, 0.0001));
    });

    test('handles division by zero and mathematical domain errors', () {
      final divZero = ScientificCalculatorEngine.evaluate('10 / 0');
      expect(divZero.isError, isTrue);
      expect(divZero.format(), contains('Division by zero'));

      final negSqrt = ScientificCalculatorEngine.evaluate('sqrt(-4)');
      expect(negSqrt.isError, isTrue);
      expect(negSqrt.format(), contains('Negative radicand'));

      final nonPosLog = ScientificCalculatorEngine.evaluate('log(0)');
      expect(nonPosLog.isError, isTrue);
      expect(nonPosLog.format(), contains('Non-positive log'));

      final nonPosLn = ScientificCalculatorEngine.evaluate('ln(-2)');
      expect(nonPosLn.isError, isTrue);
      expect(nonPosLn.format(), contains('Non-positive log'));
    });

    test('evaluates unary minus, power precedence, right-associativity, and negative exponents', () {
      // Standard algebraic notation: -3^2 = -(3^2) = -9
      expect(ScientificCalculatorEngine.evaluate('-3^2').format(), '-9');
      // Parenthesized base: (-3)^2 = 9
      expect(ScientificCalculatorEngine.evaluate('(-3)^2').format(), '9');
      // Negative exponent: 2^-3 = 0.125
      expect(ScientificCalculatorEngine.evaluate('2^-3').format(), '0.125');
      // Right-associative exponentiation: 2^3^2 = 2^(3^2) = 2^9 = 512
      expect(ScientificCalculatorEngine.evaluate('2^3^2').format(), '512');
      // Parenthesized exponentiation with unary: -(3^2) = -9
      expect(ScientificCalculatorEngine.evaluate('-(3^2)').format(), '-9');
      // Unary minus with power: -2^3 = -8
      expect(ScientificCalculatorEngine.evaluate('-2^3').format(), '-8');
      // Term subtraction vs power: 4 - 3^2 = 4 - 9 = -5
      expect(ScientificCalculatorEngine.evaluate('4 - 3^2').format(), '-5');
      // Term multiplication with unary power: 4 * -2^2 = 4 * (-4) = -16
      expect(ScientificCalculatorEngine.evaluate('4 * -2^2').format(), '-16');
    });

    test('rejects malformed inputs, invalid characters, and unrecognized symbols', () {
      // Rejects unknown characters e.g. @ instead of silently dropping them
      final atChar = ScientificCalculatorEngine.evaluate('12@+3');
      expect(atChar.isError, isTrue);
      expect(atChar.format(), contains('Unrecognized character'));

      // Rejects hash and currency symbols
      final hashChar = ScientificCalculatorEngine.evaluate('5 # 2');
      expect(hashChar.isError, isTrue);
      expect(hashChar.format(), contains('Unrecognized character'));

      // Rejects unknown functions
      final unknownFunc = ScientificCalculatorEngine.evaluate('foo(5)');
      expect(unknownFunc.isError, isTrue);
      expect(unknownFunc.format(), contains('Unknown function'));

      // Rejects unmatched parentheses
      final unmatchedParen = ScientificCalculatorEngine.evaluate('((2 + 3)');
      expect(unmatchedParen.isError, isTrue);
      expect(unmatchedParen.format(), contains('Unmatched parenthesis'));

      // Rejects dangling operators
      final danglingOp = ScientificCalculatorEngine.evaluate('2 + * 3');
      expect(danglingOp.isError, isTrue);
    });
  });

  group('ScientificCalculatorWidget Integration & Accessibility Tests', () {
    testWidgets('renders calculator header, disclaimer banner, and display', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ScientificCalculatorWidget(),
              ),
            ),
          ),
        ),
      );

      // Verify title and subtitle
      expect(find.text('Scientific Calculator'), findsOneWidget);
      expect(find.text('Practice substitute for CLEP College Algebra'), findsOneWidget);

      // Verify mandatory disclaimer
      expect(find.textContaining('Practice substitute only'), findsOneWidget);
      expect(find.textContaining('Not official TI-30XS software'), findsOneWidget);

      // Verify initial display
      expect(find.byKey(const Key('calculator_result_display')), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('performs addition interactively: 7 + 8 = 15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ScientificCalculatorWidget(),
              ),
            ),
          ),
        ),
      );

      // Tap 7
      await tester.tap(find.widgetWithText(FilledButton, '7'));
      await tester.pump();

      // Tap +
      await tester.tap(find.widgetWithText(FilledButton, '+'));
      await tester.pump();

      // Tap 8
      await tester.tap(find.widgetWithText(FilledButton, '8'));
      await tester.pump();

      // Tap =
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pump();

      // Result should be 15
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('performs clear (C) and backspace (⌫) operations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ScientificCalculatorWidget(),
              ),
            ),
          ),
        ),
      );

      // Tap 9, 5
      await tester.tap(find.widgetWithText(FilledButton, '9'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '5'));
      await tester.pump();

      expect(find.text('95'), findsOneWidget);

      // Tap Backspace
      await tester.tap(find.widgetWithText(FilledButton, '⌫'));
      await tester.pump();

      expect(find.text('9'), findsWidgets);

      // Tap Clear
      await tester.tap(find.widgetWithText(FilledButton, 'C'));
      await tester.pump();

      // Expression is cleared, result reset to 0
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('displays error message cleanly for division by zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: ScientificCalculatorWidget(),
              ),
            ),
          ),
        ),
      );

      // Enter 8 ÷ 0 =
      await tester.tap(find.widgetWithText(FilledButton, '8'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '÷'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '0'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pump();

      expect(find.textContaining('Division by zero'), findsOneWidget);
    });
  });
}

