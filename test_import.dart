import 'dart:convert';
import 'dart:io';
import 'package:learning_pwa/models/lesson.dart';

void main() async {
  // Read the sample lesson JSON
  final file = File('sample_lesson_valid.json');
  final jsonString = await file.readAsString();
  final jsonData = jsonDecode(jsonString);
  
  print('Testing lesson import order handling...');
  
  // Parse the lesson from JSON
  final lesson = Lesson.fromJson(jsonData['lesson']);
  final content = jsonData['content'] as List;
  
  print('Lesson: ${lesson.title}');
  print('Content items: ${content.length}');
  
  // Check the order values in the JSON
  print('\nOrder values in JSON:');
  for (int i = 0; i < content.length; i++) {
    final item = content[i];
    final type = item['type'];
    final order = item['order'];
    print('Item $i: type=$type, order=$order');
  }
  
  // Simulate the order processing logic from importLessonFromJson
  print('\nProcessed order values (as would be saved to database):');
  for (int index = 0; index < content.length; index++) {
    final itemMap = content[index] as Map<String, dynamic>;
    final order = itemMap['order'] as int? ?? index;
    final type = itemMap['type'];
    print('Index $index: type=$type, processed_order=$order');
  }
}
