import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/dmv_exam_item.dart';
import 'package:learning_pwa/models/ged_bridge_item.dart';
import 'package:learning_pwa/models/uscis_civics_item.dart';
import 'package:learning_pwa/screens/literacy/life_milestones_screen.dart';
import 'package:learning_pwa/widgets/literacy/dmv_exam_simulator_widget.dart';
import 'package:learning_pwa/widgets/literacy/ged_bridge_widget.dart';
import 'package:learning_pwa/widgets/literacy/life_milestones_banner_card.dart';
import 'package:learning_pwa/widgets/literacy/uscis_civics_simulator_widget.dart';

void main() {
  group('Phase 3: High-Stakes US Life Milestones Models', () {
    test('USCIS civics catalog contains 2025, 2008, and 65/20 exemption items',
        () {
      expect(officialUscisCivicsCatalog.isNotEmpty, isTrue);

      final test2025Items =
          officialUscisCivicsCatalog.where((i) => i.is2025Test).toList();
      final test2008Items =
          officialUscisCivicsCatalog.where((i) => i.is2008Test).toList();
      final exemptionItems =
          officialUscisCivicsCatalog.where((i) => i.is65_20Exemption).toList();

      expect(test2025Items.isNotEmpty, isTrue);
      expect(test2008Items.isNotEmpty, isTrue);
      expect(exemptionItems.isNotEmpty, isTrue);

      // Verify question 1 supreme law of the land
      final q1 = officialUscisCivicsCatalog.firstWhere((i) => i.number == 1);
      expect(q1.question, contains('supreme law'));
      expect(q1.options[q1.correctOptionIndex], contains('Constitution'));
    });

    test('USCIS N-400 interview catalog contains core interview drills', () {
      expect(officialN400InterviewCatalog.length, greaterThanOrEqualTo(5));

      final oath = officialN400InterviewCatalog
          .firstWhere((q) => q.section.contains('Oaths'));
      expect(oath.officerQuestion, contains('truth'));

      final taxes = officialN400InterviewCatalog
          .firstWhere((q) => q.section.contains('Moral Character'));
      expect(taxes.officerQuestion, contains('citizen'));
    });

    test('MUTCD road sign grammar catalog has 9 standardized shapes & colors',
        () {
      expect(mutcdSignGrammarCatalog.length, equals(9));

      final octagon =
          mutcdSignGrammarCatalog.firstWhere((s) => s.id == 'sign_octagon');
      expect(octagon.meaning, equals('STOP'));
      expect(octagon.visualIcon, equals('🛑'));

      final triangle =
          mutcdSignGrammarCatalog.firstWhere((s) => s.id == 'sign_triangle');
      expect(triangle.meaning, equals('YIELD'));
      expect(triangle.visualIcon, equals('🔻'));
    });

    test('Florida FLHSMV question catalog enforces road rules and Move Over law',
        () {
      expect(floridaDmvQuestionsCatalog.length, equals(10));

      final moveOver =
          floridaDmvQuestionsCatalog.firstWhere((q) => q.id == 'fl_dmv_001');
      expect(moveOver.question, contains('emergency vehicle'));
      expect(moveOver.options[moveOver.correctOptionIndex], contains('20 mph'));

      final fourWay =
          floridaDmvQuestionsCatalog.firstWhere((q) => q.id == 'fl_dmv_002');
      expect(fourWay.options[fourWay.correctOptionIndex], contains('right'));
    });

    test('GED ABE reading bridge covers Levels 1, 2, and 3 with trademark notice',
        () {
      expect(officialGedBridgeCatalog.length, greaterThanOrEqualTo(3));

      final lvl1 = officialGedBridgeCatalog
          .firstWhere((p) => p.level == AbeLevel.level1BeginningLiteracy);
      expect(lvl1.gradeEquivalency, contains('0'));

      final lvl2 = officialGedBridgeCatalog
          .firstWhere((p) => p.level == AbeLevel.level2BasicEducation);
      expect(lvl2.gradeEquivalency, contains('2.0'));

      final lvl3 = officialGedBridgeCatalog
          .firstWhere((p) => p.level == AbeLevel.level3LowIntermediate);
      expect(lvl3.gradeEquivalency, contains('4.0'));

      expect(gedTrademarkAttribution, contains('American Council on Education'));
    });
  });

  group('Phase 3: Widgets Tests', () {
    testWidgets('UscisCivicsSimulatorWidget renders 2025 test and answers correctly',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UscisCivicsSimulatorWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify mode chips
      expect(find.text('🇺🇸 2025 Test (128 Pool)'), findsOneWidget);
      expect(find.text('📜 2008 Test (100 Pool)'), findsOneWidget);
      expect(find.text('🌟 65/20 Exemption'), findsOneWidget);
      expect(find.text('🗣️ Oral N-400 Interview'), findsOneWidget);

      // Verify Question 1 is visible
      expect(find.textContaining('What is the supreme law of the land?'),
          findsOneWidget);
      expect(find.text('The Constitution'), findsOneWidget);
      expect(find.textContaining('12 to Pass'), findsOneWidget);
      expect(find.textContaining('Legal Advice Notice'), findsOneWidget);

      // Tap correct answer
      await tester.tap(find.text('The Constitution'));
      await tester.pumpAndSettle();

      // Shows checkmark and explanation
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Next Question'), findsOneWidget);
    });

    testWidgets('UscisCivicsSimulatorWidget switches to Oral N-400 interview mode',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: UscisCivicsSimulatorWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to and tap Oral N-400 mode
      final n400Chip = find.text('🗣️ Oral N-400 Interview');
      await tester.ensureVisible(n400Chip);
      await tester.tap(n400Chip);
      await tester.pumpAndSettle();

      expect(find.text('USCIS Officer Asks:'), findsOneWidget);
      expect(find.textContaining('truth'), findsOneWidget);
      expect(find.text('Hear Sample Answer'), findsOneWidget);
      expect(find.text('I Practiced This Answer'), findsOneWidget);
    });

    testWidgets('DmvExamSimulatorWidget renders signs, rules, and Florida Class E exam',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DmvExamSimulatorWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sign grammar tab is default
      expect(find.text('🛑 Sign Shapes & Colors'), findsOneWidget);
      expect(find.text('🔄 Right-of-Way Rules'), findsOneWidget);
      expect(find.text('🚗 Florida Class E Exam'), findsOneWidget);

      // Verify accommodation note
      expect(
          find.textContaining('audio-assisted testing with headphones'),
          findsOneWidget);

      // Active sign is Octagon STOP
      expect(find.text('STOP'), findsWidgets);
      expect(find.text('Listen to Sign Rule'), findsOneWidget);

      // Switch to Right-of-Way rules
      await tester.tap(find.text('🔄 Right-of-Way Rules'));
      await tester.pumpAndSettle();

      expect(find.text('4-Way Stop Right of Way'), findsOneWidget);
      expect(find.text('Florida Move Over Law'), findsOneWidget);

      // Switch to Florida Class E Exam
      await tester.tap(find.text('🚗 Florida Class E Exam'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Q 1 of 10'), findsOneWidget);
      expect(find.textContaining('emergency vehicle'), findsOneWidget);
    });

    testWidgets('GedBridgeWidget renders synchronized sentences and trademark notice',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GedBridgeWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify levels
      expect(find.text('🌱 Level 1 (Grades 0–1.9)'), findsOneWidget);
      expect(find.text('🌿 Level 2 (Grades 2.0–3.9)'), findsOneWidget);
      expect(find.text('🌳 Level 3 (Grades 4.0–5.9)'), findsOneWidget);

      // Verify passage title and full story button
      expect(find.text('Sam Starts His New Job'), findsOneWidget);
      expect(find.text('Read Full Story'), findsOneWidget);

      // Verify sentence cards
      expect(find.text('Sam has a new job at a shop.'), findsOneWidget);

      // Tap sentence to highlight
      await tester.tap(find.text('Sam has a new job at a shop.'));
      await tester.pumpAndSettle();

      // Verify trademark disclaimer is visible
      expect(find.text('Trademark Notice'), findsOneWidget);
      expect(find.textContaining('American Council on Education'), findsOneWidget);
    });

    testWidgets('LifeMilestonesScreen hosts the 3 milestones with category chips',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LifeMilestonesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('US Life Milestones'), findsOneWidget);
      expect(find.text('🇺🇸 US Citizenship (2025)'), findsOneWidget);
      expect(find.text('🚗 Florida Driver\'s License'), findsOneWidget);
      expect(find.text('🎓 GED® Reading Bridge'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Foundational Literacy Hub'), findsOneWidget);
    });

    testWidgets('LifeMilestonesBannerCard renders discovery pathways',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LifeMilestonesBannerCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AUDIO-GUIDED MILESTONES'), findsOneWidget);
      expect(find.text('High-Stakes US Life Goals & Literacy'), findsOneWidget);
      expect(find.text('🇺🇸 USCIS 2025 Test'), findsOneWidget);
      expect(find.text('🚗 Florida DMV'), findsOneWidget);
      expect(find.text('🎓 GED® Reading Bridge'), findsOneWidget);
      expect(find.text('🔤 ABCs & Phonics'), findsOneWidget);
    });
  });
}
