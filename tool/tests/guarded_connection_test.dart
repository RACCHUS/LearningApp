import 'dart:io';
import '../../lib/services/governance/guarded_database_connection.dart';

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main(List<String> args) {
  if (args.contains('--probe')) {
    final result = runGuardedDatabaseProcess('supabase', [
      'db',
      'push',
      '--linked',
      '--dry-run',
    ]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  }
  final env = <String, String>{
    'SUPABASE_DEPLOY_CONNECTION': 'session_pooler',
    'SUPABASE_DB_PASSWORD': r'p@ss:&\*%/word',
  };
  final connection = GuardedDatabaseConnection.fromEnvironment(env);
  for (final command in [
    ['migration', 'list', '--linked'],
    ['db', 'push', '--linked', '--dry-run'],
    ['db', 'push', '--linked'],
  ]) {
    final args = connection.arguments(command);
    require(
      !args.contains('--linked') && args.contains('--db-url'),
      'All database operations use the session destination',
    );
    final uri = Uri.parse(args[args.indexOf('--db-url') + 1]);
    require(
      uri.host == 'aws-0-us-east-2.pooler.supabase.com' && uri.port == 5432,
      'Exact dashboard endpoint',
    );
    require(
      Uri.decodeComponent(uri.userInfo.split(':')[1]) ==
          env['SUPABASE_DB_PASSWORD'],
      'Special characters round trip',
    );
    require(
      uri.queryParameters['sslmode'] == 'verify-full',
      'TLS verification required',
    );
    require(
      !connection
          .redact('error $uri ${env['SUPABASE_DB_PASSWORD']}')
          .contains('p@ss'),
      'Failures cannot leak credentials',
    );
    require(
      !connection.redact('error $uri').contains('postgresql://'),
      'URL removed from errors',
    );
  }
  require(
    GuardedDatabaseConnection.fromEnvironment(
          {},
        ).arguments(['migration', 'list', '--linked']).last ==
        '--linked',
    'Local default unchanged',
  );
  for (final bad in [
    {'SUPABASE_DEPLOY_CONNECTION': 'typo'},
    {'SUPABASE_DEPLOY_CONNECTION': 'session_pooler'},
  ]) {
    var rejected = false;
    try {
      GuardedDatabaseConnection.fromEnvironment(bad);
    } catch (_) {
      rejected = true;
    }
    require(rejected, 'Invalid configuration must fail closed');
  }
  // Exercise the actual subprocess boundary, including failure output. No DB.
  final temp = Directory.systemTemp.createTempSync('guarded_connection_');
  try {
    final fake = File('${temp.path}/supabase');
    fake.writeAsStringSync(
      '#!/bin/sh\nprintf "%s\\n" "\$@"\nprintf "%s\\n" "\$SUPABASE_DB_PASSWORD" >&2\nexit 7\n',
    );
    Process.runSync('chmod', ['+x', fake.path]);
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [Platform.script.toFilePath(), '--probe'],
      environment: {
        ...Platform.environment,
        ...env,
        'PATH': '${temp.path}:${Platform.environment['PATH']}',
      },
    );
    final output = '${result.stdout}${result.stderr}';
    require(result.exitCode == 7, 'Preserve CLI failure exit code');
    require(
      output.contains('--db-url') &&
          output.contains('--dry-run') &&
          !output.contains('--linked'),
      'Subprocess receives reviewed session route and dry-run',
    );
    require(
      !output.contains(env['SUPABASE_DB_PASSWORD']!) &&
          !output.contains(Uri.encodeComponent(env['SUPABASE_DB_PASSWORD']!)),
      'No raw or encoded password escapes subprocess',
    );
    require(!output.contains('postgresql://'), 'No URL escapes subprocess');
  } finally {
    temp.deleteSync(recursive: true);
  }
  print('guarded connection tests passed');
}
