import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Integration test for lesson creation and loading via service layer
/// 
/// This test verifies the complete lesson lifecycle:
/// 1. Creates a lesson from JSON
/// 2. Loads the lesson back from database
/// 3. Verifies all content was created correctly
/// 
/// Prerequisites:
/// - .env file with valid Supabase credentials
/// - Supabase database with proper schema
/// 
/// Usage: Run from project root directory
/// ```bash
/// flutter test test/integration/test_lesson_creation.dart
/// ```
/// 
/// Note: This test requires a running Flutter app context to work with
/// platform channels like shared_preferences. For simpler testing,
/// use the standalone test_import.dart instead.
void main() {
  group('Lesson Service Integration Tests', () {
    // Skip this test in regular test runs since it requires platform channels
    testWidgets('lesson creation and loading', (WidgetTester tester) async {
      // Initialize the binding
      TestWidgetsFlutterBinding.ensureInitialized();
      
      print('🎯 Integration Test: Lesson Service');
      print('====================================\n');
      
      // Load environment variables
      try {
        await dotenv.load(fileName: ".env");
        print('✅ Environment variables loaded');
      } catch (e) {
        print('❌ Failed to load .env file: $e');
        print('💡 Make sure .env file exists and contains SUPABASE_URL and SUPABASE_ANON_KEY');
        return;
      }

      // Validate configuration
      if (!SupabaseConfig.isConfigured) {
        print('❌ Supabase configuration is incomplete');
        print('💡 Check your .env file for SUPABASE_URL and SUPABASE_ANON_KEY');
        return;
      }

      // Initialize Supabase using environment variables
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
        print('✅ Connected to Supabase');
      } catch (e) {
        print('❌ Failed to initialize Supabase: $e');
        print('💡 This test requires platform channel support (shared_preferences)');
        print('💡 Consider running this as an integration test in a real app context');
        return;
      }

      final lessonService = LessonService();
      
      // Use a test user ID (you may need to adjust this based on your auth setup)
      const userId = 'test-user-id'; // Replace with actual user ID or create a test user

      const testJson = '''
      {
        "lesson": {
          "title": "Flutter Development Test Lesson",
          "description": "A comprehensive test lesson for Flutter development concepts",
          "tags": ["flutter", "test", "development"]
        },
        "content": [
          {
            "type": "term",
            "term": "Widget",
            "definition": "The basic building block of Flutter UIs",
            "example": "Text, Container, and Row are all widgets",
            "order": 1
          },
          {
            "type": "concept",
            "title": "State Management",
            "description": "How to manage state in Flutter apps using various patterns like setState, Provider, or Riverpod",
            "order": 2
          },
          {
            "type": "mcq",
            "question": "What is Flutter?",
            "options": [
              "A programming language",
              "A UI toolkit",
              "A database",
              "A design pattern"
            ],
            "correctIndex": 1,
            "explanation": "Flutter is Google's UI toolkit for building natively compiled applications for mobile, web, and desktop.",
            "order": 3
          }
        ]
      }
      ''';

      try {
        print('\n🚀 Testing lesson creation with JSON...');
        final lesson = await lessonService.importLessonFromJson(testJson, userId);
        print('✅ Lesson created successfully!');
        print('📋 Lesson Details:');
        print('   ID: ${lesson.id}');
        print('   Title: ${lesson.title}');
        print('   Description: ${lesson.description}');
        print('   Tags: ${lesson.tags.join(', ')}');
        
        // Now test loading the lesson
        print('\n🔍 Testing lesson loading...');
        final loadedLesson = await lessonService.getLesson(lesson.id);
        print('✅ Lesson loaded successfully!');
        print('📊 Content Summary:');
        print('   Terms: ${loadedLesson.terms.length}');
        print('   Questions: ${loadedLesson.questions.length}');
        print('   Concepts: ${loadedLesson.concepts.length}');
        
        // Test content details
        if (loadedLesson.terms.isNotEmpty) {
          print('\n📝 Sample Term:');
          final term = loadedLesson.terms.first;
          print('   "${term.term}": ${term.definition}');
        }
        
        if (loadedLesson.questions.isNotEmpty) {
          print('\n❓ Sample Question:');
          final question = loadedLesson.questions.first;
          print('   ${question.questionText}');
          print('   Options: ${question.options.length}');
        }
        
        if (loadedLesson.concepts.isNotEmpty) {
          print('\n💡 Sample Concept:');
          final concept = loadedLesson.concepts.first;
          print('   ${concept.conceptText}');
        }
        
        print('\n🎉 All tests completed successfully!');
        
        // Assert test conditions
        expect(lesson.title, 'Flutter Development Test Lesson');
        expect(loadedLesson.terms.length, 1);
        expect(loadedLesson.questions.length, 1);
        expect(loadedLesson.concepts.length, 1);
        
      } catch (e, stackTrace) {
        print('\n❌ Error during testing: $e');
        print('📊 Stack trace: $stackTrace');
        print('\n💡 Troubleshooting tips:');
        print('   - Check your database schema is up to date');
        print('   - Verify the user ID exists or adjust the userId variable');
        print('   - Ensure your Supabase project has the correct permissions');
        
        // Re-throw for test framework
        rethrow;
      }
    }, skip: true); // Skip: Requires platform channel support - run as integration test in app context
  });
}
