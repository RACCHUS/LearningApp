import 'dart:io';
import '../src/learning_data_source.dart';
import '../src/learningapp_mcp_server.dart';

Map<String, String> _loadEnvFile([String path = '.env']) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq != -1) {
      final key = trimmed.substring(0, eq).trim();
      var val = trimmed.substring(eq + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.substring(1, val.length - 1);
      }
      env[key] = val;
    }
  }
  return env;
}

void main(List<String> args) async {
  final env = _loadEnvFile();

  String? supabaseUrl;
  String? supabaseKey;
  String contentDir = 'content';
  bool offline = false;
  bool verbose = false;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--supabase-url' && i + 1 < args.length) {
      supabaseUrl = args[++i];
    } else if (arg == '--supabase-key' && i + 1 < args.length) {
      supabaseKey = args[++i];
    } else if (arg == '--content-dir' && i + 1 < args.length) {
      contentDir = args[++i];
    } else if (arg == '--offline') {
      offline = true;
    } else if (arg == '--verbose' || arg == '-v') {
      verbose = true;
    } else if (arg == '--help' || arg == '-h') {
      stdout.writeln('LearningApp Model Context Protocol (MCP) Stdio Server');
      stdout.writeln('Usage: dart run tool/mcp_server/bin/learningapp_mcp.dart [options]');
      stdout.writeln('');
      stdout.writeln('Options:');
      stdout.writeln('  --supabase-url <url>  Supabase project URL (defaults to SUPABASE_URL env)');
      stdout.writeln('  --supabase-key <key>  Supabase API key (defaults to SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY)');
      stdout.writeln('  --content-dir <dir>   Curriculum content directory (defaults to "content")');
      stdout.writeln('  --offline             Force offline mode using local manifests only');
      stdout.writeln('  --verbose, -v         Log protocol details to stderr');
      stdout.writeln('  --help, -h            Show this help');
      exit(0);
    }
  }

  supabaseUrl ??= Platform.environment['SUPABASE_URL'] ?? env['SUPABASE_URL'];
  supabaseKey ??= Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_ANON_KEY'] ??
      env['SUPABASE_SERVICE_ROLE_KEY'] ??
      env['SUPABASE_ANON_KEY'];

  final dataSource = LearningDataSource(
    supabaseUrl: supabaseUrl,
    supabaseKey: supabaseKey,
    contentDir: contentDir,
    offline: offline,
    verbose: verbose,
  );

  final server = LearningAppMcpServer(
    dataSource: dataSource,
    verbose: verbose,
  );

  if (verbose) {
    stderr.writeln('[learningapp-mcp] Server initialized.');
    stderr.writeln('[learningapp-mcp] Mode: ${dataSource.hasDatabase ? "Connected to Supabase" : "Offline / Local Manifests"}');
  }

  // Handle process shutdown signals gracefully
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      await server.stop();
      exit(0);
    });
  }

  await server.start();
}
