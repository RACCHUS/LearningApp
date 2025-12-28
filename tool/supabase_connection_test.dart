import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/config/supabase_config.dart';

class SupabaseConnectionTest {
  static Future<void> testConnection() async {
    try {
      final supabase = Supabase.instance.client;
      
      print('🔍 SUPABASE DEBUG: Testing connection...');
      print('🔍 SUPABASE DEBUG: URL: ${SupabaseConfig.url}');
      print('🔍 SUPABASE DEBUG: Key: ${SupabaseConfig.anonKey.substring(0, 20)}...');
      
      // Test basic query
      final response = await supabase
          .from('lessons')
          .select('count')
          .count(CountOption.exact);
          
      print('🔍 SUPABASE DEBUG: Connection successful! Lesson count: $response');
      
    } catch (e) {
      print('❌ SUPABASE ERROR: Connection failed: $e');
      print('❌ SUPABASE ERROR: Type: ${e.runtimeType}');
    }
  }
}
