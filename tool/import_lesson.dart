import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/config/supabase_config.dart';

/// Script to import lesson JSON data into Supabase database
/// 
/// This script:
/// 1. Loads environment variables for secure Supabase connection
/// 2. Reads lesson data from the organized data/samples/ folder
/// 3. Imports the complete lesson structure into the database
/// 
/// Usage: Run from project root directory with `dart tool/import_lesson.dart`
Future<void> importLaptopLesson() async {
  print('🚀 Starting lesson import process...');
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded');
  } catch (e) {
    print('❌ Failed to load .env file: $e');
    print('💡 Make sure .env file exists and contains SUPABASE_URL and SUPABASE_ANON_KEY');
    exit(1);
  }

  // Validate configuration
  if (!SupabaseConfig.isConfigured) {
    print('❌ Supabase configuration is incomplete');
    print('💡 Check your .env file for SUPABASE_URL and SUPABASE_ANON_KEY');
    exit(1);
  }

  // Initialize Supabase using environment variables
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final supabase = Supabase.instance.client;
  print('✅ Connected to Supabase');

  // Read the lesson JSON file from organized data structure
  final file = File('data/samples/sample_lesson_valid.json');
  
  if (!await file.exists()) {
    print('❌ Sample lesson file not found: ${file.path}');
    print('💡 Make sure you\'re running this script from the project root directory');
    exit(1);
  }
  
  final jsonString = await file.readAsString();
  final lessonData = jsonDecode(jsonString);
  
  print('📖 Loaded lesson: ${lessonData['lesson']['title']}');

  try {
    // Insert/update the lesson with the full JSON content
    await supabase
        .from('lessons')
        .upsert({
          'id': lessonData['lesson']['id'],
          'title': lessonData['lesson']['title'],
          'description': lessonData['lesson']['description'],
          'author': lessonData['lesson']['author'],
          'tags': lessonData['lesson']['tags'],
          'difficulty': lessonData['lesson']['difficulty'],
          'estimated_time_minutes': lessonData['lesson']['estimated_time_minutes'],
          'cover_image_url': lessonData['lesson']['cover_image_url'],
          'is_public': lessonData['lesson']['is_public'],
          'is_featured': lessonData['lesson']['is_featured'],
          'language': lessonData['lesson']['language'],
          'content': lessonData, // Store the entire JSON structure
          'created_at': lessonData['lesson']['created_at'],
          'updated_at': lessonData['lesson']['updated_at'],
        });

    print('✅ Lesson imported successfully!');
    print('📋 Lesson Details:');
    print('   ID: ${lessonData['lesson']['id']}');
    print('   Title: ${lessonData['lesson']['title']}');
    print('   Content items: ${lessonData['content'].length}');
    print('   Difficulty: ${lessonData['lesson']['difficulty']}');
    print('   Estimated time: ${lessonData['lesson']['estimated_time_minutes']} minutes');

  } catch (e) {
    print('❌ Error importing lesson: $e');
    print('💡 Check your database schema and permissions');
    exit(1);
  }
}

void main() async {
  print('🎯 Lesson Import Tool - Learning PWA');
  print('=====================================');
  
  await importLaptopLesson();
  
  print('=====================================');
  print('🎉 Import process completed!');
  exit(0);
}
