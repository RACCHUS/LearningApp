import 'dart:convert';
import 'dart:io';

import 'supabase_rest_auth.dart';

Map<String, String> _loadDotenv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    var value = trimmed.substring(eq + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env[trimmed.substring(0, eq).trim()] = value;
  }
  return env;
}

void main(List<String> args) async {
  stdout.writeln('====================================================');
  stdout.writeln('🌱 ECO-02: Pilot Community FAQ Seeding CLI');
  stdout.writeln('====================================================');

  final env = _loadDotenv();
  String? url = env['SUPABASE_URL'] ?? Platform.environment['SUPABASE_URL'];
  String? serviceKey =
      env['SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  String? authorId;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--url' && i + 1 < args.length) {
      url = args[++i];
    } else if (arg == '--service-key' && i + 1 < args.length) {
      serviceKey = args[++i];
    } else if (arg == '--author-id' && i + 1 < args.length) {
      authorId = args[++i];
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln('''
Usage: dart run tool/seed_pilot_community_faqs.dart [options]

Options:
  --url <url>              Supabase base URL (defaults to .env SUPABASE_URL)
  --service-key <key>      Supabase service role key (defaults to .env SUPABASE_SERVICE_ROLE_KEY)
  --author-id <uuid>       Optional author user ID to attribute the seeded FAQs to
  -h, --help               Show help
''');
      exit(0);
    }
  }

  if (url == null || url.isEmpty) {
    stderr.writeln('❌ Error: Missing SUPABASE_URL in .env or arguments.');
    exit(1);
  }

  if (serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln(
      '❌ Error: Missing SUPABASE_SERVICE_ROLE_KEY in .env or arguments.',
    );
    exit(1);
  }

  assertSupabaseAdminKey(serviceKey);

  final client = HttpClient();
  try {
    // 1. If authorId not supplied, fetch the first admin user from moderation_roles
    if (authorId == null) {
      final rolesUri = Uri.parse(
        '$url/rest/v1/moderation_roles?role=eq.admin&select=user_id&limit=1',
      );
      final rolesReq = await client.getUrl(rolesUri);
      setSupabaseRestAuth(rolesReq, serviceKey);
      final rolesResp = await rolesReq.close();
      final rolesBody = await rolesResp.transform(utf8.decoder).join();

      if (rolesResp.statusCode == 200) {
        final roles = jsonDecode(rolesBody) as List<dynamic>;
        if (roles.isNotEmpty) {
          authorId = roles.first['user_id'] as String?;
          stdout.writeln('ℹ️  Found admin user for FAQ authorship: $authorId');
        }
      }
    }

    // 2. Invoke seed_pilot_community_faqs RPC
    final rpcUri = Uri.parse('$url/rest/v1/rpc/seed_pilot_community_faqs');
    final rpcReq = await client.postUrl(rpcUri);
    setSupabaseRestAuth(rpcReq, serviceKey);
    rpcReq.headers.set(
      HttpHeaders.contentTypeHeader,
      'application/json; charset=utf-8',
    );

    final payload = <String, dynamic>{
      if (authorId != null) 'p_author_id': authorId,
    };
    rpcReq.write(jsonEncode(payload));

    final rpcResp = await rpcReq.close();
    final rpcBody = await rpcResp.transform(utf8.decoder).join();

    if (rpcResp.statusCode >= 200 && rpcResp.statusCode < 300) {
      final seededCount = int.tryParse(rpcBody.trim()) ?? 0;
      stdout.writeln(
        '✅ seed_pilot_community_faqs executed successfully. Newly seeded: $seededCount',
      );
    } else {
      stderr.writeln(
        '❌ Failed to execute seed_pilot_community_faqs RPC (${rpcResp.statusCode}): $rpcBody',
      );
      exit(1);
    }

    // 3. Query total published seed FAQs
    final queryUri = Uri.parse(
      '$url/rest/v1/community_questions?is_seeded=eq.true&status=eq.published&select=id,title,concept_id,answer_count',
    );
    final queryReq = await client.getUrl(queryUri);
    setSupabaseRestAuth(queryReq, serviceKey);
    final queryResp = await queryReq.close();
    final queryBody = await queryResp.transform(utf8.decoder).join();

    if (queryResp.statusCode == 200) {
      final faqs = jsonDecode(queryBody) as List<dynamic>;
      stdout.writeln(
        '📊 Total published pilot FAQs active in database: ${faqs.length}',
      );
      for (final faq in faqs) {
        stdout.writeln(
          '   • [${faq['concept_id']}] "${faq['title']}" (${faq['answer_count']} answers)',
        );
      }
    }
  } finally {
    client.close();
  }

  stdout.writeln('====================================================');
  stdout.writeln('✨ Seeding complete.');
}
