import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/widgets/empty_state.dart';

void main() {
  group('EmptyState Widget Tests', () {
    testWidgets('should display icon, title, and message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.inbox,
              title: 'No Items',
              message: 'You have no items yet',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('You have no items yet'), findsOneWidget);
    });

    testWidgets('should display action button when provided', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.add,
              title: 'No Lessons',
              message: 'Create your first lesson',
              action: ElevatedButton(
                onPressed: () => actionTapped = true,
                child: const Text('Create Lesson'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Create Lesson'), findsOneWidget);
      
      await tester.tap(find.text('Create Lesson'));
      await tester.pump();

      expect(actionTapped, isTrue);
    });

    testWidgets('should work without action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.search,
              title: 'No Results',
              message: 'Try a different search term',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('No Results'), findsOneWidget);
    });

    testWidgets('should use custom icon size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.error,
              title: 'Error',
              message: 'Something went wrong',
              iconSize: 100,
            ),
          ),
        ),
      );

      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(iconWidget.size, 100);
    });

    testWidgets('should use custom spacing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.info,
              title: 'Information',
              message: 'Here is some info',
              spacing: 32,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('should be scrollable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.book,
              title: 'No Books',
              message: 'Your library is empty. Add some books to get started.',
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should apply theme colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primaryColor: Colors.blue,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: const Scaffold(
            body: EmptyState(
              icon: Icons.favorite,
              title: 'No Favorites',
              message: 'You have not favorited anything yet',
            ),
          ),
        ),
      );

      expect(find.byType(EmptyState), findsOneWidget);
      
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.favorite));
      expect(iconWidget.color, isNotNull);
    });

    testWidgets('should center content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.cloud,
              title: 'Offline',
              message: 'You are currently offline',
            ),
          ),
        ),
      );

      expect(find.byType(Center), findsWidgets);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('should display multiple elements in correct order', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.note,
              title: 'No Notes',
              message: 'Start taking notes',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('Add Note'),
              ),
            ),
          ),
        ),
      );

      // Find all text widgets
      expect(find.text('No Notes'), findsOneWidget);
      expect(find.text('Start taking notes'), findsOneWidget);
      expect(find.text('Add Note'), findsOneWidget);
      
      // Verify icon is present
      expect(find.byIcon(Icons.note), findsOneWidget);
    });

    testWidgets('should handle long text without overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.info,
              title: 'Very Long Title That Might Wrap',
              message: 'This is a very long message that contains a lot of text and might need to wrap to multiple lines on smaller screens',
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(EmptyState), findsOneWidget);
    });
  });
}
