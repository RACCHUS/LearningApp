import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/supabase_rest_auth.dart';

String testJwt(String role) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'role': role})))
      .replaceAll('=', '');
  return 'e30.$payload.signature';
}

void main() {
  test('modern secret key uses apikey header only', () {
    expect(supabaseBearerValueForApiKey('sb_secret_test'), isNull);
    expect(() => assertSupabaseAdminKey('sb_secret_test'), returnsNormally);
  });

  test('modern publishable key never gains importer privilege', () {
    expect(supabaseBearerValueForApiKey('sb_publishable_test'), isNull);
    expect(() => assertSupabaseAdminKey('sb_publishable_test'),
        throwsFormatException);
  });

  test('legacy JWT is bearer and requires service_role for importer', () {
    final service = testJwt('service_role');
    expect(supabaseBearerValueForApiKey(service), 'Bearer $service');
    expect(() => assertSupabaseAdminKey(service), returnsNormally);

    final anon = testJwt('anon');
    expect(supabaseBearerValueForApiKey(anon), 'Bearer $anon');
    expect(() => assertSupabaseAdminKey(anon), throwsFormatException);
  });

  test('unrecognized key shapes fail closed', () {
    expect(() => supabaseBearerValueForApiKey('wrong'), throwsFormatException);
    expect(() => assertSupabaseAdminKey('wrong'), throwsFormatException);
  });
}
