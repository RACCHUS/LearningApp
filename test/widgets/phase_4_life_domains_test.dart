import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/currency_survival_item.dart';
import 'package:learning_pwa/models/food_safety_item.dart';
import 'package:learning_pwa/models/health_safety_item.dart';
import 'package:learning_pwa/models/workplace_safety_item.dart';
import 'package:learning_pwa/screens/literacy/life_domains_screen.dart';
import 'package:learning_pwa/widgets/literacy/currency_atm_widget.dart';
import 'package:learning_pwa/widgets/literacy/food_safety_widget.dart';
import 'package:learning_pwa/widgets/literacy/rx_and_first_aid_widget.dart';
import 'package:learning_pwa/widgets/literacy/workplace_safety_widget.dart';

void main() {
  group('Phase 4: Life Domains & Survival Models', () {
    test('Workplace safety catalog contains PPE, GHS, LOTO, and ladder rules', () {
      expect(officialWorkplaceSafetyCatalog.isNotEmpty, isTrue);

      final ppe = officialWorkplaceSafetyCatalog
          .where((i) => i.category == WorkplaceSafetyCategory.ppe)
          .toList();
      final ghs = officialWorkplaceSafetyCatalog
          .where((i) => i.category == WorkplaceSafetyCategory.ghsPictogram)
          .toList();
      final loto = officialWorkplaceSafetyCatalog
          .where((i) => i.category == WorkplaceSafetyCategory.lockoutTagout)
          .toList();
      final ladder = officialWorkplaceSafetyCatalog
          .where((i) => i.category == WorkplaceSafetyCategory.fallProtection)
          .toList();

      expect(ppe.length, greaterThanOrEqualTo(4));
      expect(ghs.length, greaterThanOrEqualTo(4));
      expect(loto.isNotEmpty, isTrue);
      expect(ladder.isNotEmpty, isTrue);

      // Verify OSHA disclaimer text
      expect(oshaCardDisclaimer, contains('OSHA-authorized trainers'));
      expect(oshaCardDisclaimer, contains('does not issue cards'));
    });

    test('Food safety catalog contains FDA Food Code temperatures, cutting boards, & allergens', () {
      expect(officialFoodSafetyCatalog.isNotEmpty, isTrue);

      final dangerZone = officialFoodSafetyCatalog
          .firstWhere((i) => i.id == 'temp_danger_zone');
      expect(dangerZone.ruleSummary, contains('41°F and 135°F'));

      final poultry = officialFoodSafetyCatalog
          .firstWhere((i) => i.id == 'temp_poultry');
      expect(poultry.criticalStandard, contains('165°F'));

      final groundMeat = officialFoodSafetyCatalog
          .firstWhere((i) => i.id == 'temp_ground_meat');
      expect(groundMeat.criticalStandard, contains('155°F'));

      final boards = officialFoodSafetyCatalog
          .firstWhere((i) => i.category == FoodSafetyCategory.crossContamination);
      expect(boards.ruleSummary, contains('Red'));
      expect(boards.ruleSummary, contains('Green'));

      final allergens = officialFoodSafetyCatalog
          .firstWhere((i) => i.category == FoodSafetyCategory.allergens);
      expect(allergens.title, contains('Big 9'));

      // Verify 6 handwashing steps with 20s scrub
      expect(officialHandwashingSteps.length, equals(6));
      final scrubStep = officialHandwashingSteps.firstWhere((s) => s.stepNumber == 3);
      expect(scrubStep.durationSeconds, equals(20));
    });

    test('Healthcare & Rx catalog contains 5 bottle components and cool water burn protocol', () {
      expect(officialRxLabelComponents.length, equals(5));

      final patientName =
          officialRxLabelComponents.firstWhere((c) => c.id == 'rx_patient_name');
      expect(patientName.fieldName, equals('Patient Name'));

      final phone =
          officialRxLabelComponents.firstWhere((c) => c.id == 'rx_pharmacy_phone');
      expect(phone.purposeExplanation, contains('Call this phone number'));

      expect(officialFirstAidGuidelines.length, equals(3));

      final burnProtocol =
          officialFirstAidGuidelines.firstWhere((g) => g.id == 'first_aid_burns');
      expect(burnProtocol.criticalRule, contains('cool, gentle running tap water'));
      expect(burnProtocol.criticalRule, contains('10 to 20 minutes'));
      expect(burnProtocol.dangerousMythWarning, contains('NEVER apply ice'));

      final bleeding =
          officialFirstAidGuidelines.firstWhere((g) => g.id == 'first_aid_bleeding');
      expect(bleeding.spokenProtocol, contains('direct pressure'));

      final call911 =
          officialFirstAidGuidelines.firstWhere((g) => g.id == 'first_aid_911');
      expect(call911.actionSteps.length, equals(5));

      // Medical advice disclaimer
      expect(medicalAdviceDisclaimer, contains('does NOT provide medical advice'));
    });

    test('Currency catalog contains coins, banknotes, and 6-step ATM simulator', () {
      expect(officialCurrencyCatalog.isNotEmpty, isTrue);

      final penny = officialCurrencyCatalog.firstWhere((c) => c.id == 'coin_penny');
      expect(penny.valueDollars, equals(0.01));

      final quarter = officialCurrencyCatalog.firstWhere((c) => c.id == 'coin_quarter');
      expect(quarter.valueDollars, equals(0.25));

      final dollar20 = officialCurrencyCatalog.firstWhere((c) => c.id == 'bill_20');
      expect(dollar20.valueDollars, equals(20.0));

      final dollar100 = officialCurrencyCatalog.firstWhere((c) => c.id == 'bill_100');
      expect(dollar100.valueDollars, equals(100.0));

      // ATM simulator has 6 steps
      expect(officialAtmSteps.length, equals(6));
      expect(officialAtmSteps[0].actionTitle, contains('Insert Debit Card'));
      expect(officialAtmSteps[1].actionTitle, contains('PIN'));
      expect(officialAtmSteps[2].actionTitle, contains('Withdraw Cash'));
    });
  });

  group('Phase 4: Life Domains Interactive Widgets', () {
    testWidgets('WorkplaceSafetyWidget renders PPE, GHS, and OSHA disclaimer',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WorkplaceSafetyWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check PPE default category
      expect(find.textContaining('Hard Hat'), findsWidgets);
      expect(find.textContaining('OSHA Training Disclosure'), findsOneWidget);
      expect(find.textContaining('does not issue cards'), findsOneWidget);

      // Switch to GHS category
      final ghsChip = find.text('☠️ GHS Chemical Symbols');
      expect(ghsChip, findsOneWidget);
      await tester.tap(ghsChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('Flammable'), findsWidgets);
    });

    testWidgets('FoodSafetyWidget displays temperatures, cutting boards, and 20s handwash timer',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: FoodSafetyWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check temperature danger zone
      expect(find.textContaining('41°F to 135°F'), findsWidgets);
      expect(find.textContaining('FDA Food Code 2022 Compliance'), findsOneWidget);

      // Switch to Cutting Boards tab
      final boardsChip = find.text('🔪 Cutting Boards (Cross-Contamination)');
      expect(boardsChip, findsOneWidget);
      await tester.ensureVisible(boardsChip);
      await tester.pumpAndSettle();
      await tester.tap(boardsChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('RED BOARD'), findsOneWidget);
      expect(find.textContaining('GREEN BOARD'), findsOneWidget);

      // Switch to Handwashing Timer tab
      final washChip = find.text('🧼 20-Sec Handwash Timer');
      expect(washChip, findsOneWidget);
      await tester.ensureVisible(washChip);
      await tester.pumpAndSettle();
      await tester.tap(washChip);
      await tester.pumpAndSettle();

      expect(find.text('Start 20s Timer'), findsOneWidget);
      expect(find.textContaining('Wet Hands'), findsOneWidget);
    });

    testWidgets('RxAndFirstAidWidget displays Rx bottle, pharmacist rule, and burn first aid',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: RxAndFirstAidWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check prescription label components
      expect(find.textContaining('Patient Name'), findsWidgets);
      expect(find.textContaining('Medical Advice Disclaimer'), findsOneWidget);
      expect(find.textContaining('does NOT provide medical advice'), findsOneWidget);

      // Switch to Ask Pharmacist tab
      final pharmChip = find.text('👨‍⚕️ Ask Your Pharmacist');
      expect(pharmChip, findsOneWidget);
      await tester.tap(pharmChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('What to Say to the Pharmacist:'), findsOneWidget);

      // Switch to Burns & First Aid tab
      final burnChip = find.text('🚰 Burn Care (Never Ice)');
      expect(burnChip, findsOneWidget);
      await tester.ensureVisible(burnChip);
      await tester.pumpAndSettle();
      await tester.tap(burnChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('NEVER USE ICE'), findsOneWidget);
      expect(find.textContaining('10 to 20 minutes'), findsWidgets);
    });

    testWidgets('CurrencyAtmWidget renders coins/bills, ATM simulator PIN pad, and cash withdrawal',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CurrencyAtmWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check coins & bills
      expect(find.textContaining('Penny (One Cent)'), findsWidgets);
      expect(find.textContaining('18 U.S.C. § 504 Currency Compliance'), findsOneWidget);

      // Switch to ATM Simulator tab
      final atmChip = find.text('🏧 ATM Cash Simulator');
      expect(atmChip, findsOneWidget);
      await tester.tap(atmChip);
      await tester.pumpAndSettle();

      expect(find.textContaining('Insert Debit Card'), findsWidgets);

      // Tap Next ATM Action to advance to Step 2 (PIN entry)
      final nextStepBtn = find.text('Next ATM Action');
      expect(nextStepBtn, findsOneWidget);
      await tester.tap(nextStepBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Enter 4-Digit PIN'), findsWidgets);

      // Enter digits 1, 2, 3, 4 via keypad ElevatedButton
      await tester.tap(find.widgetWithText(ElevatedButton, '1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '2'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '3'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '4'));
      await tester.pumpAndSettle();

      // Advance with Next ATM Action button
      await tester.tap(find.text('Next ATM Action'));
      await tester.pumpAndSettle();

      // Step 3: Select Withdraw Cash
      expect(find.textContaining('Withdraw Cash'), findsWidgets);
    });

    testWidgets('LifeDomainsScreen hosts all 4 survival domains and allows tab switching',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LifeDomainsScreen(
              initialCategory: LifeDomainCategory.workplaceSafety,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Survival Skills'), findsOneWidget);
      expect(find.byType(WorkplaceSafetyWidget), findsOneWidget);

      // Switch to Food Safety
      final foodTab = find.text('🍳 Food Safety (FDA)');
      expect(foodTab, findsOneWidget);
      await tester.ensureVisible(foodTab);
      await tester.pumpAndSettle();
      await tester.tap(foodTab);
      await tester.pumpAndSettle();

      expect(find.byType(FoodSafetyWidget), findsOneWidget);

      // Switch to Health & First Aid
      final healthTab = find.text('💊 Health & First Aid');
      expect(healthTab, findsOneWidget);
      await tester.ensureVisible(healthTab);
      await tester.pumpAndSettle();
      await tester.tap(healthTab);
      await tester.pumpAndSettle();

      expect(find.byType(RxAndFirstAidWidget), findsOneWidget);

      // Switch to Cash & ATM
      final cashTab = find.text('💵 Cash & ATM Practice');
      expect(cashTab, findsOneWidget);
      await tester.ensureVisible(cashTab);
      await tester.pumpAndSettle();
      await tester.tap(cashTab);
      await tester.pumpAndSettle();

      expect(find.byType(CurrencyAtmWidget), findsOneWidget);
    });
  });
}
