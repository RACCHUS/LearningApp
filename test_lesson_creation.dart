import 'package:learning_pwa/services/lesson_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final lessonService = LessonService();
  const userId = '00000000-0000-0000-0000-000000000000'; // Guest user

  const testJson = '''
  {
    "lesson": {
      "title": "Sample Lesson",
      "description": "This is a sample lesson",
      "tags": ["sample", "test"]
    },
    "content": [
      {
        "type": "term",
        "term": "Widget",
        "definition": "The basic building block of Flutter UIs",
        "example": "Text, Container, and Row are all widgets"
      },
      {
        "type": "concept",
        "title": "State Management",
        "description": "How to manage state in Flutter apps"
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
        "explanation": "Flutter is Google's UI toolkit for building natively compiled applications."
      }
    ]
  }
  ''';

  try {
    print('🚀 Testing lesson creation with JSON...');
    final lesson = await lessonService.importLessonFromJson(testJson, userId);
    print('✅ Lesson created successfully: ${lesson.id}');
    print('📝 Title: ${lesson.title}');
    print('📝 Description: ${lesson.description}');
    
    // Now test loading the lesson
    print('🔍 Testing lesson loading...');
    final loadedLesson = await lessonService.getLesson(lesson.id);
    print('✅ Lesson loaded successfully');
    print('📝 Terms: ${loadedLesson.terms.length}');
    print('📝 Questions: ${loadedLesson.questions.length}');
    print('📝 Concepts: ${loadedLesson.concepts.length}');
    
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('📊 Stack trace: $stackTrace');
  }
}
