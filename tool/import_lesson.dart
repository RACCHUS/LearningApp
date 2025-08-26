import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/config/supabase_config.dart';

/// Script to import the laptop lesson JSON into Supabase with proper content field
/// Run this once to set up the lesson data correctly
Future<void> importLaptopLesson() async {
  // Initialize Supabase using your project credentials
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final supabase = Supabase.instance.client;

  // Read the lesson JSON file
  final file = File('sample_lesson_valid.json');
  final jsonString = await file.readAsString();
  final lessonData = jsonDecode(jsonString);

  try {
    // Insert/update the lesson with the full JSON content
    await supabase
        .from('lessons')
        .upsert({
          'id': lessonData['lesson']['id'],
          'title': lessonData['lesson']['title'],
          'description': lessonData['lesson']['description'],
          'tags': lessonData['lesson']['tags'],
          'content': lessonData, // Store the entire JSON
          'created_at': lessonData['lesson']['created_at'],
          'updated_at': lessonData['lesson']['updated_at'],
        });

    print('✅ Lesson imported successfully');
    print('Lesson ID: ${lessonData['lesson']['id']}');
    print('Content items: ${lessonData['content'].length}');

  } catch (e) {
    print('❌ Error importing lesson: $e');
  }
}

void main() async {
  await importLaptopLesson();
  exit(0);
}
