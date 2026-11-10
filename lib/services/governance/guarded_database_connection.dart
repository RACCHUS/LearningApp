import 'dart:io';

/// One reviewed destination for every hosted migration operation. Opt-in keeps
/// existing local developer tooling unchanged. Never accept an arbitrary URL.
class GuardedDatabaseConnection {
  static const projectRef = 'xzvkdwebtbxlrxagtzlv';
  static const sessionHost = 'aws-0-us-east-2.pooler.supabase.com';
  final String? _url;
  final String? _password;

  GuardedDatabaseConnection._(this._url, this._password);

  factory GuardedDatabaseConnection.fromEnvironment(Map<String, String> env) {
    final mode = env['SUPABASE_DEPLOY_CONNECTION'];
    if (mode == null || mode.isEmpty) {
      return GuardedDatabaseConnection._(null, env['SUPABASE_DB_PASSWORD']);
    }
    if (mode != 'session_pooler') {
      throw StateError('Unsupported guarded database connection mode.');
    }
    final password = env['SUPABASE_DB_PASSWORD'];
    if (password == null || password.isEmpty) {
      throw StateError('Session pooler requires SUPABASE_DB_PASSWORD.');
    }
    // Host/user were verified in the project dashboard Connect > Session pooler.
    // Encode the password only, so delimiters in it cannot alter the destination.
    final url =
        'postgresql://postgres.$projectRef:'
        '${Uri.encodeComponent(password)}@$sessionHost:5432/postgres?sslmode=verify-full';
    return GuardedDatabaseConnection._(url, password);
  }

  List<String> arguments(List<String> original) {
    if (_url == null) return List.of(original);
    final migrationList =
        original.length >= 2 &&
        original[0] == 'migration' &&
        original[1] == 'list';
    final push =
        original.length >= 2 && original[0] == 'db' && original[1] == 'push';
    if (!migrationList && !push) return List.of(original);
    if (!original.contains('--linked') || original.contains('--db-url')) {
      throw StateError(
        'Guarded migration command must select one reviewed destination.',
      );
    }
    return [
      for (final arg in original)
        if (arg == '--linked') ...['--db-url', _url] else arg,
    ];
  }

  String redact(String text) {
    var safe = text.replaceAll(
      RegExp(r'postgres(?:ql)?://[^\s]+'),
      '[REDACTED_DATABASE_URL]',
    );
    final password = _password;
    if (password != null && password.isNotEmpty) {
      safe = safe
          .replaceAll(Uri.encodeComponent(password), '[REDACTED]')
          .replaceAll(password, '[REDACTED]');
    }
    return safe;
  }
}

/// Scrub subprocess output before any caller can log it or save an audit report.
/// Child Dart gates inherit the same environment and resolve the same endpoint.
ProcessResult runGuardedDatabaseProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell = false,
}) {
  final connection = GuardedDatabaseConnection.fromEnvironment(
    Platform.environment,
  );
  try {
    final result = Process.runSync(
      executable,
      executable == 'supabase' ? connection.arguments(arguments) : arguments,
      workingDirectory: workingDirectory,
      runInShell: executable == 'supabase' ? false : runInShell,
    );
    return ProcessResult(
      result.pid,
      result.exitCode,
      connection.redact(result.stdout.toString()),
      connection.redact(result.stderr.toString()),
    );
  } catch (error) {
    throw StateError(connection.redact('Guarded subprocess failed: $error'));
  }
}
