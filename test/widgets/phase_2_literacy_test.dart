import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/cvc_word_item.dart';
import 'package:learning_pwa/models/letter_stroke_data.dart';
import 'package:learning_pwa/models/phonics_item.dart';
import 'package:learning_pwa/models/survival_word_item.dart';
import 'package:learning_pwa/screens/literacy/foundational_literacy_screen.dart';
import 'package:learning_pwa/widgets/literacy/cvc_blending_widget.dart';
import 'package:learning_pwa/widgets/literacy/personal_id_form_widget.dart';
import 'package:learning_pwa/widgets/literacy/survival_words_widget.dart';

void main() {
  group('Phase 2: Hand-Verified LetterStrokeData Tests', () {
    test('contains verified stroke paths for all 26 uppercase letters A-Z', () {
      const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      for (int i = 0; i < letters.length; i++) {
        final char = letters[i];
        final strokes = LetterStrokeData.uppercase[char];
        expect(strokes, isNotNull, reason: 'Missing stroke for $char');
        expect(strokes!.isNotEmpty, isTrue, reason: 'Empty stroke list for $char');

        for (final stroke in strokes) {
          expect(stroke.points.isNotEmpty, isTrue);
          for (final point in stroke.points) {
            expect(point.dx, inInclusiveRange(0.0, 1.0));
            expect(point.dy, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });

    test('contains verified stroke paths for digits 0-9', () {
      for (int i = 0; i <= 9; i++) {
        final digit = i.toString();
        final strokes = LetterStrokeData.digits[digit];
        expect(strokes, isNotNull, reason: 'Missing stroke for digit $digit');
        expect(strokes!.isNotEmpty, isTrue);
      }
    });

    test('LetterStrokeData.forChar retrieves uppercase and digit strokes cleanly', () {
      expect(LetterStrokeData.forChar('a'), isNotNull);
      expect(LetterStrokeData.forChar('M'), isNotNull);
      expect(LetterStrokeData.forChar('7'), isNotNull);
      expect(LetterStrokeData.forChar(''), isNull);
    });

    test('verifies Zaner-Bloser top-to-bottom stroke kinematics for stems', () {
      // M first vertical stem: top (0.12) to bottom (0.88)
      final mStrokes = LetterStrokeData.uppercase['M']!;
      expect(mStrokes.first.startPoint.dy, lessThan(mStrokes.first.endPoint.dy));

      // B vertical stem: top (0.12) to bottom (0.88)
      final bStrokes = LetterStrokeData.uppercase['B']!;
      expect(bStrokes.first.startPoint.dy, lessThan(bStrokes.first.endPoint.dy));

      // T central stem: top to bottom
      final tStrokes = LetterStrokeData.uppercase['T']!;
      expect(tStrokes[1].startPoint.dy, lessThan(tStrokes[1].endPoint.dy));
    });
  });

  group('Phase 2: Comprehensive 26-Letter Phonics Catalog Tests', () {
    test('contains all 26 letters in foundationalPhonicsCatalog', () {
      expect(foundationalPhonicsCatalog.length, 26);
      final set = foundationalPhonicsCatalog.map((e) => e.letter).toSet();
      expect(set.length, 26);
      expect(set.contains('A'), isTrue);
      expect(set.contains('Z'), isTrue);
    });

    test('each phonics item has letter name, pure phoneme sound, and 3 anchors per track', () {
      for (final item in foundationalPhonicsCatalog) {
        expect(item.letterName.isNotEmpty, isTrue);
        expect(item.phonemeSound.startsWith('/'), isTrue);
        expect(item.phonemeSound.endsWith('/'), isTrue);
        expect(item.adultAnchors.length, 3);
        expect(item.youthAnchors.length, 3);

        // Exactly one correct anchor per track
        expect(item.adultAnchors.where((a) => a.isCorrect).length, 1);
        expect(item.youthAnchors.where((a) => a.isCorrect).length, 1);
      }
    });

    test('short vowels are properly flagged', () {
      final vowels = foundationalPhonicsCatalog.where((i) => i.isVowel).map((i) => i.letter).toSet();
      expect(vowels, equals({'A', 'E', 'I', 'O', 'U'}));
    });
  });

  group('Phase 2: CVC Word Blending Widget Tests', () {
    testWidgets('renders CVC sound cards and blends sounds on tap', (tester) async {
      bool mastered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CvcBlendingWidget(
                onWordMastered: () => mastered = true,
              ),
            ),
          ),
        ),
      );

      // Verify header and 3 segments (Start, Vowel, End)
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Vowel'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);

      // Tap onset card
      await tester.tap(find.text('Start'));
      await tester.pump();

      // Tap Blend Sounds Together button
      final blendBtn = find.byKey(const Key('cvc-blend-action-btn'));
      expect(blendBtn, findsOneWidget);
      await tester.tap(blendBtn);
      await tester.pump();

      expect(mastered, isTrue);

      // Navigate to next word
      final nextBtn = find.byKey(const Key('cvc-next-btn'));
      await tester.tap(nextBtn);
      await tester.pump();
      expect(find.text('Word 2 of ${decodableCvcWordBank.length}'), findsOneWidget);
    });
  });

  group('Phase 2: Environmental Survival Words Widget Tests', () {
    testWidgets('renders survival signs and toggles between explore and quiz modes', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SurvivalWordsWidget(),
              ),
            ),
          ),
        ),
      );

      // In Explore mode: signs are visible
      expect(find.text('EXIT'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
      expect(find.text('DANGER'), findsOneWidget);

      // Tap EXIT sign to view details
      await tester.tap(find.text('EXIT'));
      await tester.pump();
      expect(find.text('The door out of the building.'), findsOneWidget);

      // Toggle to Quiz Mode
      final toggleBtn = find.byKey(const Key('survival-mode-toggle-btn'));
      await tester.tap(toggleBtn);
      await tester.pump();

      expect(find.text('Find the Sign'), findsOneWidget);

      // Toggle back to Explore Signs
      await tester.tap(toggleBtn);
      await tester.pump();
      expect(find.text('Survival Safety Signs'), findsOneWidget);
    });
  });

  group('Phase 2: Personal Identification Form Widget Tests', () {
    testWidgets('renders personal ID fields and allows completion', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PersonalIdFormWidget(
                  onSaved: () => completed = true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('My Name & Info'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name (Family Name)'), findsOneWidget);
      expect(find.text('Street Address'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);

      // Enter First Name
      await tester.enterText(find.byType(TextField).first, 'John');
      await tester.pump();

      // Submit form
      final submitBtn = find.byKey(const Key('personal-id-submit-btn'));
      await tester.tap(submitBtn);
      await tester.pump();

      expect(completed, isTrue);
    });
  });

  group('Phase 2: FoundationalLiteracyScreen Hub Multi-Mode Tests', () {
    testWidgets('navigates cleanly across all 4 hub modes', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FoundationalLiteracyScreen(),
          ),
        ),
      );

      // Mode 1: Letters (default)
      expect(find.text('🔤 Letters (A-Z)'), findsOneWidget);
      expect(find.text('Sound & Picture'), findsOneWidget);
      expect(find.text('Finger Tracing'), findsOneWidget);

      // Switch to Mode 2: Word Blending
      await tester.tap(find.text('🧩 Word Blending'));
      await tester.pumpAndSettle();
      expect(find.byType(CvcBlendingWidget), findsOneWidget);

      // Switch to Mode 3: Survival Signs
      await tester.tap(find.text('🛑 Survival Signs'));
      await tester.pumpAndSettle();
      expect(find.byType(SurvivalWordsWidget), findsOneWidget);

      // Switch to Mode 4: My Name & Info
      final nameChip = find.text('📝 My Name & Info');
      await tester.ensureVisible(nameChip);
      await tester.pumpAndSettle();
      await tester.tap(nameChip);
      await tester.pumpAndSettle();
      expect(find.byType(PersonalIdFormWidget), findsOneWidget);
    });
  });
}
