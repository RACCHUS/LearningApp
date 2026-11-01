// tool/verify_schema_contract.dart
// CI Contract Check: verifies that every .from('x') and .rpc('y') referenced
// in lib/ is declared in canonical supabase/migrations/.

import 'dart:io';

void main() {
  print('====================================================');
  print('  Supabase Schema Contract & Call-Site Guard        ');
  print('====================================================');

  final libDir = Directory('lib');
  final migrationsDir = Directory('supabase/migrations');

  if (!libDir.existsSync()) {
    stderr.writeln('Error: lib/ directory not found');
    exit(1);
  }
  if (!migrationsDir.existsSync()) {
    stderr.writeln('Error: supabase/migrations/ directory not found');
    exit(1);
  }

  // 1. Collect all declared tables, views, and functions from migrations
  final declaredTablesAndViews = <String>{};
  final declaredFunctions = <String>{};

  final tableRegex = RegExp(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-zA-Z0-9_]+)', caseSensitive: false);
  final viewRegex = RegExp(r'create\s+(?:or\s+replace\s+)?view\s+(?:public\.)?([a-zA-Z0-9_]+)', caseSensitive: false);
  final funcRegex = RegExp(r'create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?([a-zA-Z0-9_]+)', caseSensitive: false);

  for (final file in migrationsDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    final content = file.readAsStringSync();
    
    for (final m in tableRegex.allMatches(content)) {
      declaredTablesAndViews.add(m.group(1)!.toLowerCase());
    }
    for (final m in viewRegex.allMatches(content)) {
      declaredTablesAndViews.add(m.group(1)!.toLowerCase());
    }
    for (final m in funcRegex.allMatches(content)) {
      declaredFunctions.add(m.group(1)!.toLowerCase());
    }
  }

  print('📦 Declared Schema Objects: ${declaredTablesAndViews.length} tables/views, ${declaredFunctions.length} RPCs');

  // 2. Scan lib/ for .from('...') and .rpc('...') calls
  final referencedTables = <String, List<String>>{};
  final referencedFunctions = <String, List<String>>{};

  final fromCallRegex = RegExp(r'''\.from\(\s*['"]([a-zA-Z0-9_]+)['"]\s*\)''');
  final rpcCallRegex = RegExp(r'''\.rpc\(\s*['"]([a-zA-Z0-9_]+)['"]''');

  for (final file in libDir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final content = file.readAsStringSync();
    final relPath = file.path.replaceAll('\\', '/');

    for (final m in fromCallRegex.allMatches(content)) {
      final name = m.group(1)!.toLowerCase();
      referencedTables.putIfAbsent(name, () => []).add(relPath);
    }
    for (final m in rpcCallRegex.allMatches(content)) {
      final name = m.group(1)!.toLowerCase();
      referencedFunctions.putIfAbsent(name, () => []).add(relPath);
    }
  }

  // 3. Known built-in Supabase or pg_ catalog exceptions if any
  final allowedTableExceptions = <String>{};
  final allowedRpcExceptions = <String>{};

  // 4. Verify contracts
  final missingTables = <String, List<String>>{};
  for (final entry in referencedTables.entries) {
    if (!declaredTablesAndViews.contains(entry.key) && !allowedTableExceptions.contains(entry.key)) {
      missingTables[entry.key] = entry.value;
    }
  }

  final missingFunctions = <String, List<String>>{};
  for (final entry in referencedFunctions.entries) {
    if (!declaredFunctions.contains(entry.key) && !allowedRpcExceptions.contains(entry.key)) {
      missingFunctions[entry.key] = entry.value;
    }
  }

  if (missingTables.isNotEmpty || missingFunctions.isNotEmpty) {
    stderr.writeln('\n❌ Schema Drift Detected! Client calls uncommitted DB objects:');
    if (missingTables.isNotEmpty) {
      stderr.writeln('\nMissing Tables / Views:');
      for (final entry in missingTables.entries) {
        stderr.writeln('  • ${entry.key} (referenced in ${entry.value.first})');
      }
    }
    if (missingFunctions.isNotEmpty) {
      stderr.writeln('\nMissing RPC Functions:');
      for (final entry in missingFunctions.entries) {
        stderr.writeln('  • ${entry.key} (referenced in ${entry.value.first})');
      }
    }
    stderr.writeln('\nFix: Port missing objects into a new forward migration or remove dead client code.');
    exit(1);
  }

  print('✅ Contract check passed: all ${referencedTables.length} client tables and ${referencedFunctions.length} RPCs exist in migrations.');
  print('====================================================');
}
