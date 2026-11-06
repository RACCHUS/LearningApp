import 'package:yaml/yaml.dart';

class ManifestValidationIssue {
  final String path;
  final String message;
  final String severity; // 'error' | 'warning'

  const ManifestValidationIssue({
    required this.path,
    required this.message,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'message': message,
        'severity': severity,
      };
}

class ManifestValidationResult {
  final bool isValid;
  final List<ManifestValidationIssue> issues;

  const ManifestValidationResult({
    required this.isValid,
    required this.issues,
  });

  int get errorCount => issues.where((i) => i.severity == 'error').length;
  int get warningCount => issues.where((i) => i.severity == 'warning').length;
}

/// Standalone curriculum manifest validator.
class ManifestValidatorCore {
  ManifestValidationResult validateYaml(String yamlString) {
    final issues = <ManifestValidationIssue>[];

    dynamic doc;
    try {
      doc = loadYaml(yamlString);
    } catch (e) {
      return ManifestValidationResult(
        isValid: false,
        issues: [
          ManifestValidationIssue(
            path: 'root',
            message: 'Invalid YAML syntax: $e',
            severity: 'error',
          ),
        ],
      );
    }

    if (doc is! Map) {
      return const ManifestValidationResult(
        isValid: false,
        issues: [
          ManifestValidationIssue(
            path: 'root',
            message: 'Manifest must be a YAML mapping/dictionary.',
            severity: 'error',
          ),
        ],
      );
    }

    final map = doc;

    // Check required top-level metadata
    if (map['manifest_version'] == null) {
      issues.add(const ManifestValidationIssue(
        path: 'manifest_version',
        message: 'Missing manifest_version attribute.',
        severity: 'error',
      ));
    }
    if (map['title'] == null || (map['title'] as String).trim().isEmpty) {
      issues.add(const ManifestValidationIssue(
        path: 'title',
        message: 'Missing or empty manifest title.',
        severity: 'error',
      ));
    }

    // Check modules
    final modules = map['modules'];
    if (modules == null || modules is! List || modules.isEmpty) {
      issues.add(const ManifestValidationIssue(
        path: 'modules',
        message: 'Manifest must contain a non-empty list of modules.',
        severity: 'error',
      ));
    }

    // Check answer positions if assessments exist
    final assessments = map['assessments'];
    if (assessments is List && assessments.isNotEmpty) {
      final positionCounts = <int, int>{};
      int totalQuestions = 0;

      for (var i = 0; i < assessments.length; i++) {
        final item = assessments[i];
        if (item is Map) {
          final options = item['options'];
          final correctIndex = item['correct_index'];
          if (options is List && correctIndex is int) {
            positionCounts[correctIndex] =
                (positionCounts[correctIndex] ?? 0) + 1;
            totalQuestions++;
          }
        }
      }

      // Check for position bias (>75% at one index)
      if (totalQuestions >= 4) {
        for (final entry in positionCounts.entries) {
          final pct = entry.value / totalQuestions;
          if (pct > 0.75) {
            issues.add(ManifestValidationIssue(
              path: 'assessments',
              message:
                  'Answer position bias detected: Option index ${entry.key} accounts for ${(pct * 100).toStringAsFixed(1)}% of correct answers. Rebalance positions across choices.',
              severity: 'warning',
            ));
          }
        }
      }
    }

    final hasErrors = issues.any((i) => i.severity == 'error');
    return ManifestValidationResult(
      isValid: !hasErrors,
      issues: issues,
    );
  }
}

