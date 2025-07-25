import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lesson.dart';

final lessonListProvider = FutureProvider<List<Lesson>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.from('lessons').select();
  return (response as List)
      .map((json) => Lesson.fromJson(json))
      .toList();
});
