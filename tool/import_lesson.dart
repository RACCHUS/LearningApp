import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

/// Flexible lesson import tool for developers.
///
/// Pure-Dart CLI (no Flutter dependency) that talks to Supabase over its REST
/// API, so it runs with a plain `dart run`. It writes to the RELATIONAL tables
/// (`lessons` + `terms`/`concepts`/`questions`) that the app reads when opening
/// a lesson, so imported lessons are immediately testable in the app.
///
/// Supports two JSON formats:
///   1. Simple format: { title, description, tags, concepts[], terms[], questions[] }
///   2. Database format: { lesson: {...}, content: [{type, ...}] }
///
/// Usage:
///   dart run tool/import_lesson.dart <file_or_directory> [--dry-run] [--list]
///
/// Examples:
///   dart run tool/import_lesson.dart assets/lessons/prog_01_variables.json
///   dart run tool/import_lesson.dart assets/lessons/      # import all JSON in folder
///   dart run tool/import_lesson.dart data/samples/        # import all JSON in folder
///   dart run tool/import_lesson.dart --list               # list lessons in database
///   dart run tool/import_lesson.dart my_lesson.json --dry-run
///
/// Config resolution (first non-empty wins):
///   .env file  ->  process environment  ->  built-in public fallback
/// Set SUPABASE_SERVICE_ROLE_KEY (in .env or the environment) to bypass RLS
/// when seeding public/ownerless lessons.

const _uuid = Uuid();

// Public fallback project (anon key is RLS-protected and safe to expose).
const _fallbackUrl = 'https://xzvkdwebtbxlrxagtzlv.supabase.co';
const _fallbackAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh6dmtkd2VidGJ4bHJ4YWd0emx2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM0NTY4NTMsImV4cCI6MjA2OTAzMjg1M30.PrrRi4aecxwUVSeKgor-la2Vk-Tg6heRPGdUOzfEPIY';

class _Config {
  final String url;
  final String key;
  final bool serviceRole;
  const _Config(this.url, this.key, this.serviceRole);
}

/// Parse a local .env file (KEY=VALUE per line) if present.
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

_Config _resolveConfig() {
  final env = _loadDotenv();
  String pick(String key, String fallback) {
    final fromFile = env[key];
    if (fromFile != null && fromFile.isNotEmpty) return fromFile;
    final fromEnv = Platform.environment[key];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    return fallback;
  }

  final url = pick('SUPABASE_URL', _fallbackUrl);
  final service = pick('SUPABASE_SERVICE_ROLE_KEY', '');
  if (service.isNotEmpty) return _Config(url, service, true);
  return _Config(url, pick('SUPABASE_ANON_KEY', _fallbackAnonKey), false);
}

class _Resp {
  final int status;
  final String body;
  const _Resp(this.status, this.body);
  bool get ok => status >= 200 && status < 300;
}

/// Perform a single REST request against the Supabase API.
Future<_Resp> _rest(
  _Config cfg,
  String method,
  String path, {
  Object? body,
  Map<String, String>? prefer,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('${cfg.url}/rest/v1/$path');
    final req = await client.openUrl(method, uri);
    req.headers.set('apikey', cfg.key);
    req.headers.set('Authorization', 'Bearer ${cfg.key}');
    req.headers.set('Content-Type', 'application/json');
    if (prefer != null && prefer.isNotEmpty) {
      req.headers.set(
        'Prefer',
        prefer.entries.map((e) => '${e.key}=${e.value}').join(','),
      );
    }
    if (body != null) req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    return _Resp(resp.statusCode, text);
  } finally {
    client.close();
  }
}

/// Detect whether JSON is simple format or database format.
String _detectFormat(Map<String, dynamic> json) {
  if (json.containsKey('lesson') && json.containsKey('content')) {
    return 'database';
  }
  if (json.containsKey('title') &&
      (json.containsKey('terms') ||
          json.containsKey('questions') ||
          json.containsKey('concepts'))) {
    return 'simple';
  }
  return 'unknown';
}

/// Normalize simple format into database format for unified import.
Map<String, dynamic> _normalizeToDbFormat(
    Map<String, dynamic> json, String sourceFile) {
  final format = _detectFormat(json);

  if (format == 'database') return json;

  if (format == 'simple') {
    final id = json['id']?.toString() ?? _uuid.v4();
    final content = <Map<String, dynamic>>[];
    var order = 1;

    if (json['concepts'] is List) {
      for (final c in json['concepts']) {
        content.add({
          'type': 'concept',
          'id': c['id']?.toString() ?? _uuid.v4(),
          'order': order++,
          'title': c['concept_text'] ?? c['title'] ?? '',
          'description': c['example_text'] ?? c['description'] ?? '',
          if (c['emoji'] != null) 'emoji': c['emoji'],
        });
      }
    }

    if (json['terms'] is List) {
      for (final t in json['terms']) {
        content.add({
          'type': 'term',
          'id': t['id']?.toString() ?? _uuid.v4(),
          'order': order++,
          'term': t['term'] ?? '',
          'definition': t['definition'] ?? '',
          'example': t['example'] ?? '',
          if (t['emoji'] != null) 'emoji': t['emoji'],
        });
      }
    }

    if (json['questions'] is List) {
      for (final q in json['questions']) {
        content.add({
          'type': 'mcq',
          'id': q['id']?.toString() ?? _uuid.v4(),
          'order': order++,
          'question': q['question'] ?? q['question_text'] ?? '',
          'options':
              q['options'] is List ? List<String>.from(q['options']) : <String>[],
          'correctIndex': q['correct_answer'] ?? q['correctIndex'] ?? 0,
          'explanation': q['explanation'] ?? '',
        });
      }
    }

    return {
      'lesson': {
        'id': id,
        'title': json['title'] ?? 'Untitled',
        'description': json['description'] ?? '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'tags': json['tags'] is List ? List<String>.from(json['tags']) : <String>[],
      },
      'content': content,
    };
  }

  throw FormatException('Unrecognized lesson JSON format in $sourceFile');
}

/// Validate lesson data and return a list of issues (empty = valid).
///
/// Performs deep validation so malformed AI-generated lessons are caught
/// before any database write — especially MCQ answer indices, which are the
/// most common generation error.
List<String> _validate(Map<String, dynamic> normalized) {
  final issues = <String>[];
  final lesson = normalized['lesson'] as Map<String, dynamic>?;

  if (lesson == null) {
    issues.add('Missing "lesson" object');
    return issues;
  }
  if ((lesson['title'] ?? '').toString().trim().isEmpty) {
    issues.add('Missing lesson title');
  }

  final content = normalized['content'];
  if (content is! List || content.isEmpty) {
    issues.add('Lesson has no content items');
    return issues;
  }

  var terms = 0, concepts = 0, mcqs = 0;

  for (var i = 0; i < content.length; i++) {
    final item = content[i];
    if (item is! Map<String, dynamic>) {
      issues.add('Content item ${i + 1} is not an object');
      continue;
    }
    final type = item['type']?.toString() ?? '';
    final label = 'Content item ${i + 1} ($type)';

    switch (type) {
      case 'term':
        terms++;
        if ((item['term'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty "term"');
        }
        if ((item['definition'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty "definition"');
        }
        break;
      case 'concept':
        concepts++;
        if ((item['title'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty concept title');
        }
        if ((item['description'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty concept description');
        }
        break;
      case 'mcq':
        mcqs++;
        if ((item['question'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty "question"');
        }
        final options = item['options'];
        if (options is! List || options.length < 2) {
          issues.add('$label: needs at least 2 options');
        } else {
          final texts =
              options.map((o) => o.toString().trim()).toList(growable: false);
          if (texts.any((t) => t.isEmpty)) {
            issues.add('$label: contains an empty option');
          }
          if (texts.toSet().length != texts.length) {
            issues.add('$label: contains duplicate options');
          }
          final ci = item['correctIndex'];
          if (ci is! int) {
            issues.add('$label: "correctIndex" must be an integer');
          } else if (ci < 0 || ci >= options.length) {
            issues.add(
                '$label: "correctIndex" $ci out of range (0..${options.length - 1})');
          }
        }
        if ((item['explanation'] ?? '').toString().trim().isEmpty) {
          issues.add('$label: empty "explanation"');
        }
        break;
      default:
        issues.add('$label: unknown content type "$type"');
    }
  }

  if (terms + concepts + mcqs == 0) {
    issues.add('Lesson has no recognizable content (terms/concepts/mcqs)');
  }

  return issues;
}

/// Import a single normalized lesson into Supabase via the REST API.
///
/// Writes to the relational tables the app reads. Content rows are deleted and
/// re-inserted so re-importing the same lesson id is idempotent.
Future<void> _importLesson(_Config cfg, Map<String, dynamic> normalized) async {
  final lesson = normalized['lesson'] as Map<String, dynamic>;
  final content = normalized['content'] as List;
  final lessonId = lesson['id'];

  // Upsert the lesson row (public lesson => user_id NULL, world-readable).
  final lessonResp = await _rest(
    cfg,
    'POST',
    'lessons',
    prefer: {'resolution': 'merge-duplicates', 'return': 'minimal'},
    body: [
      {
        'id': lessonId,
        'title': lesson['title'],
        'description': lesson['description'],
        'tags': lesson['tags'],
        'user_id': null,
        'created_at': lesson['created_at'],
        'updated_at': lesson['updated_at'],
      }
    ],
  );
  if (!lessonResp.ok) {
    throw 'lessons upsert failed (${lessonResp.status}): ${lessonResp.body}';
  }

  // Replace existing content for an idempotent re-import.
  for (final table in ['terms', 'concepts', 'questions']) {
    final del = await _rest(cfg, 'DELETE', '$table?lesson_id=eq.$lessonId');
    if (!del.ok) {
      throw '$table delete failed (${del.status}): ${del.body}';
    }
  }

  final terms = <Map<String, dynamic>>[];
  final concepts = <Map<String, dynamic>>[];
  final questions = <Map<String, dynamic>>[];

  for (final raw in content) {
    if (raw is! Map<String, dynamic>) continue;
    switch (raw['type']) {
      case 'term':
        terms.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'term': raw['term'],
          'definition': raw['definition'],
          'example': raw['example'],
          'user_id': null,
        });
        break;
      case 'concept':
        concepts.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'concept_text': raw['title'],
          'example_text': raw['description'],
          'user_id': null,
        });
        break;
      case 'mcq':
        questions.add({
          'id': _uuid.v4(),
          'lesson_id': lessonId,
          'question_text': raw['question'],
          'options': raw['options'],
          'correct_answer': raw['correctIndex'],
          'type': 'mcq',
          'explanation': raw['explanation'],
          'user_id': null,
        });
        break;
    }
  }

  await _insertRows(cfg, 'terms', terms);
  await _insertRows(cfg, 'concepts', concepts);
  await _insertRows(cfg, 'questions', questions);

  print('   ✅ ${lesson['title']}');
  print(
      '      ${terms.length} terms, ${concepts.length} concepts, ${questions.length} MCQs | tags: ${lesson['tags']}');
}

Future<void> _insertRows(
    _Config cfg, String table, List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) return;
  final resp = await _rest(
    cfg,
    'POST',
    table,
    prefer: {'return': 'minimal'},
    body: rows,
  );
  if (!resp.ok) {
    throw '$table insert failed (${resp.status}): ${resp.body}';
  }
}

/// List all lessons currently in the database.
Future<void> _listLessons(_Config cfg) async {
  final resp = await _rest(
    cfg,
    'GET',
    'lessons?select=id,title,tags,user_id,created_at&order=created_at.desc',
  );
  if (!resp.ok) {
    print('❌ Failed to list lessons (${resp.status}): ${resp.body}');
    exit(1);
  }

  final lessons = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  if (lessons.isEmpty) {
    print('📭 No lessons found in the database.');
    return;
  }

  print('📚 Lessons in database (${lessons.length}):');
  print('${'─' * 70}');
  for (final lesson in lessons) {
    final tags = (lesson['tags'] as List?)?.join(', ') ?? '';
    final visibility = lesson['user_id'] == null ? 'public' : 'owned';
    print('  ${lesson['title']}');
    print('    ID: ${lesson['id']} ($visibility)');
    print('    Tags: $tags');
    print('');
  }
}

/// Collect all .json files to import from a path (file or directory).
List<File> _resolveFiles(String path) {
  final entity = FileSystemEntity.typeSync(path);

  if (entity == FileSystemEntityType.file) {
    if (!path.endsWith('.json')) {
      print('⚠️  Skipping non-JSON file: $path');
      return [];
    }
    return [File(path)];
  }

  if (entity == FileSystemEntityType.directory) {
    final dir = Directory(path);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (files.isEmpty) {
      print('⚠️  No JSON files found in $path');
    }
    return files;
  }

  print('❌ Path not found: $path');
  exit(1);
}

void _printUsage() {
  print('');
  print('Usage: dart run tool/import_lesson.dart <file_or_directory> [options]');
  print('');
  print('Arguments:');
  print('  <file_or_directory>   Path to a .json file or folder of .json files');
  print('');
  print('Options:');
  print('  --dry-run             Validate JSON without importing');
  print('  --list                List all lessons currently in the database');
  print('  --help                Show this help message');
  print('');
  print('Examples:');
  print('  dart run tool/import_lesson.dart assets/lessons/prog_01_variables.json');
  print('  dart run tool/import_lesson.dart assets/lessons/');
  print('  dart run tool/import_lesson.dart data/samples/');
  print('  dart run tool/import_lesson.dart my_lesson.json --dry-run');
  print('  dart run tool/import_lesson.dart --list');
}

void main(List<String> args) async {
  print('🎯 Lesson Import Tool - Learning PWA');
  print('=====================================');

  final dryRun = args.contains('--dry-run');
  final listMode = args.contains('--list');
  final showHelp = args.contains('--help') || args.contains('-h');
  final paths = args.where((a) => !a.startsWith('-')).toList();

  if (showHelp) {
    _printUsage();
    exit(0);
  }

  final cfg = _resolveConfig();

  if (listMode) {
    print(cfg.serviceRole ? '🔑 Using service-role key' : '🔑 Using anon key');
    await _listLessons(cfg);
    exit(0);
  }

  if (paths.isEmpty) {
    print('❌ No file or directory specified.');
    _printUsage();
    exit(1);
  }

  final files = <File>[];
  for (final path in paths) {
    files.addAll(_resolveFiles(path));
  }

  if (files.isEmpty) {
    print('❌ No valid JSON files to process.');
    exit(1);
  }

  print('📁 Found ${files.length} lesson file(s) to process');
  print('');

  final prepared = <MapEntry<File, Map<String, dynamic>>>[];
  var errors = 0;

  for (final file in files) {
    final name = file.path.split(Platform.pathSeparator).last;
    try {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final format = _detectFormat(raw);
      final normalized = _normalizeToDbFormat(raw, file.path);
      final issues = _validate(normalized);

      if (issues.isNotEmpty) {
        print('⚠️  $name — validation issues:');
        for (final issue in issues) {
          print('     - $issue');
        }
        errors++;
        continue;
      }

      print(
          '✅ $name — format: $format, title: "${normalized['lesson']['title']}"');
      prepared.add(MapEntry(file, normalized));
    } on FormatException catch (e) {
      print('❌ $name — $e');
      errors++;
    } catch (e) {
      print('❌ $name — Error: $e');
      errors++;
    }
  }

  print('');

  if (dryRun) {
    print('🔍 Dry run complete: ${prepared.length} valid, $errors errors');
    exit(errors > 0 ? 1 : 0);
  }

  if (prepared.isEmpty) {
    print('❌ No valid lessons to import.');
    exit(1);
  }

  print(cfg.serviceRole
      ? '🔑 Connected to Supabase (service-role key)'
      : '🔑 Connected to Supabase (anon key)');
  print('📥 Importing ${prepared.length} lesson(s)...');

  var imported = 0;
  for (final entry in prepared) {
    try {
      await _importLesson(cfg, entry.value);
      imported++;
    } catch (e) {
      final name = entry.key.path.split(Platform.pathSeparator).last;
      print('   ❌ Failed to import $name: $e');
      errors++;
    }
  }

  print('');
  print('=====================================');
  print('🎉 Done! $imported imported, $errors errors');
  exit(errors > 0 ? 1 : 0);
}
