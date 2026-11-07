import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/language/bilingual_vocab_service.dart';
import 'package:learning_pwa/widgets/language/bilingual_bridge_widget.dart';

void main() {
  group('BilingualBridgeWidget Tests', () {
    testWidgets('renders English primary term by default and displays pronunciation', (tester) async {
      final service = BilingualVocabService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BilingualBridgeWidget(
              vocabService: service,
              initialCategory: 'OSHA Workplace Safety',
            ),
          ),
        ),
      );

      expect(find.textContaining('Lockout / Tagout'), findsOneWidget);
      expect(find.textContaining('/ˈlɒk.aʊt ˈtæɡ.aʊt/'), findsOneWidget);
      expect(find.text('Standard: 29 CFR 1910.147'), findsOneWidget);
    });

    testWidgets('switches to Spanish when ES segment is tapped', (tester) async {
      final service = BilingualVocabService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BilingualBridgeWidget(
              vocabService: service,
              initialCategory: 'OSHA Workplace Safety',
            ),
          ),
        ),
      );

      await tester.tap(find.text('ES 🇪🇸'));
      await tester.pump();

      expect(find.textContaining('Bloqueo / Etiquetado'), findsOneWidget);
    });
  });
}
