import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/taxonomy/taxonomy.dart';
import 'package:learning_pwa/widgets/taxonomy/cip_detail_sheet.dart';

void main() {
  testWidgets('CipDetailSheet displays CIP details, definition, and crosswalks',
      (tester) async {
    const node = ExternalClassificationNode(
      id: 'cip-11-0701',
      sourceReleaseId: 'rel-cip-2020',
      system: 'cip',
      version: '2020',
      code: '11.0701',
      levelCode: 'program',
      title: 'Computer Science',
      definition:
          'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
      illustrativeExamples: ['Computer Science', 'Theoretical Computer Science'],
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CipDetailSheet(cipNode: node),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify program header
    expect(find.text('CIP 11.0701'), findsOneWidget);
    expect(find.text('Computer Science'), findsAtLeastNWidgets(1));
    expect(find.text('PROGRAM'), findsOneWidget);

    // Verify definition
    expect(find.text('Program Definition'), findsOneWidget);
    expect(
      find.textContaining('A program that focuses on computer theory'),
      findsOneWidget,
    );

    // Verify illustrative examples
    expect(find.text('Theoretical Computer Science'), findsOneWidget);

    // Verify crosswalk section
    expect(
      find.textContaining('Crosswalked Career Occupations'),
      findsOneWidget,
    );
    expect(find.text('Software Developers'), findsOneWidget);
  });
}
