import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/screens/taxonomy/occupation_detail_screen.dart';

void main() {
  testWidgets('OccupationDetailScreen renders occupation details and crosswalks',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OccupationDetailScreen(occupationCode: '15-1252'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and codes
    expect(find.text('15-1252'), findsOneWidget);
    expect(find.text('Software Developers'), findsAtLeastNWidgets(1));
    expect(find.text('DETAILED OCCUPATION'), findsOneWidget);

    // Verify Job Zone
    expect(
      find.textContaining('Job Zone 4: Considerable Preparation Needed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('four-year bachelor\'s degree'),
      findsOneWidget,
    );

    // Verify Aligned Learning Targets section
    expect(find.text('Aligned Learning Targets in App'), findsOneWidget);
    expect(find.text('B.S. in Computer Science'), findsOneWidget);
    expect(find.text('Software Engineer Career Path'), findsOneWidget);
    expect(find.text('Start Learning'), findsAtLeastNWidgets(1));
    expect(find.text('Outline'), findsAtLeastNWidgets(1));

    // Verify CIP crosswalk section
    expect(
      find.textContaining('Crosswalked Educational Programs'),
      findsOneWidget,
    );
    expect(find.text('CIP 11.0701'), findsOneWidget);

    // Verify pedagogical safeguards notice
    expect(
      find.textContaining('Crosswalk alignments derive from published federal qualitative matrices'),
      findsOneWidget,
    );
  });
}
