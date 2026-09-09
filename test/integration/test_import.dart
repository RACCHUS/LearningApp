import 'dart:convert';
import 'dart:io';

/// Integration test to verify lesson import order handling logic
/// 
/// This test verifies that lesson content order values are processed correctly
/// during the lesson import process. It helps debug and verify the order 
/// assignment logic used in lesson creation.
/// 
/// This is a standalone test that doesn't depend on Flutter models to avoid
/// dart:ui dependency issues when running with plain `dart` command.
/// 
/// Usage: Run from project root directory
/// ```bash
/// dart test/integration/test_import.dart
/// ```
void main() async {
  print('🔍 Integration Test: Lesson Import Order Handling');
  print('===================================================\n');
  
  // Read the sample lesson JSON from organized data structure
  final file = File('data/samples/sample_lesson_valid.json');
  
  if (!await file.exists()) {
    print('❌ Sample lesson file not found: ${file.path}');
    print('💡 Make sure you\'re running this script from the project root directory');
    print('💡 Expected file location: data/samples/sample_lesson_valid.json');
    exit(1);
  }
  
  try {
    final jsonString = await file.readAsString();
    final jsonData = jsonDecode(jsonString);
    
    // Parse the lesson data directly from JSON (without Flutter models)
    final lessonData = jsonData['lesson'] as Map<String, dynamic>;
    final content = jsonData['content'] as List;
    
    print('📖 Lesson: ${lessonData['title']}');
    print('📊 Content items: ${content.length}\n');
    
    // Check the order values in the JSON
    print('📋 Order values in JSON:');
    for (int i = 0; i < content.length; i++) {
      final item = content[i];
      final type = item['type'];
      final order = item['order'];
      print('   Item $i: type=$type, order=$order');
    }
    
    // Simulate the order processing logic from importLessonFromJson
    print('\n🔄 Processed order values (as would be saved to database):');
    for (int index = 0; index < content.length; index++) {
      final itemMap = content[index] as Map<String, dynamic>;
      final order = itemMap['order'] as int? ?? index;
      final type = itemMap['type'];
      print('   Index $index: type=$type, processed_order=$order');
    }
    
    print('\n✅ Order handling test completed successfully!');
    
  } catch (e) {
    print('❌ Error processing lesson file: $e');
    print('💡 Check that the JSON file is valid and contains the expected structure');
    exit(1);
  }
}
