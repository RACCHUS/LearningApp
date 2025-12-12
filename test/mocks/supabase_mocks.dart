import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock annotations for Supabase classes
/// 
/// Run `flutter pub run build_runner build` to generate mocks
@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  PostgrestClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestTransformBuilder,
])
void main() {}
