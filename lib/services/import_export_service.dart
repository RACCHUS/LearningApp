import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service for handling import/export operations and history
class ImportExportService {
  static const int _maxHistoryItems = 20;

  /// Save import to history
  static Future<void> saveToHistory(ImportHistoryItem item) async {
    try {
      final history = await getImportHistory();
      
      // Remove existing entry with same title if exists
      history.removeWhere((existing) => existing.title == item.title);
      
      // Add new item at the beginning
      history.insert(0, item);
      
      // Keep only the latest items
      if (history.length > _maxHistoryItems) {
        history.removeRange(_maxHistoryItems, history.length);
      }
      
      await _saveHistory(history);
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  /// Get import history
  static Future<List<ImportHistoryItem>> getImportHistory() async {
    try {
      // In a real implementation, this would use SharedPreferences or local database
      // For now, returning a mock list
      return _getMockHistory();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  /// Add to favorites
  static Future<void> addToFavorites(String title, String jsonContent) async {
    try {
      final favorites = await getFavorites();
      
      final favorite = FavoriteImport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        jsonContent: jsonContent,
        addedAt: DateTime.now(),
      );
      
      // Remove existing with same title
      favorites.removeWhere((existing) => existing.title == title);
      
      // Add to beginning
      favorites.insert(0, favorite);
      
      await _saveFavorites(favorites);
    } catch (e) {
      print('Error adding to favorites: $e');
    }
  }

  /// Get favorites
  static Future<List<FavoriteImport>> getFavorites() async {
    try {
      // In a real implementation, this would use SharedPreferences or local database
      return _getMockFavorites();
    } catch (e) {
      print('Error loading favorites: $e');
      return [];
    }
  }

  /// Remove from favorites
  static Future<void> removeFromFavorites(String id) async {
    try {
      final favorites = await getFavorites();
      favorites.removeWhere((favorite) => favorite.id == id);
      await _saveFavorites(favorites);
    } catch (e) {
      print('Error removing from favorites: $e');
    }
  }

  /// Export lesson to different formats
  static Future<ExportResult> exportLesson(
    Map<String, dynamic> lessonData, 
    ExportFormat format,
  ) async {
    try {
      switch (format) {
        case ExportFormat.json:
          return await _exportToJson(lessonData);
        case ExportFormat.pdf:
          return await _exportToPdf(lessonData);
        case ExportFormat.word:
          return await _exportToWord(lessonData);
        case ExportFormat.markdown:
          return await _exportToMarkdown(lessonData);
        case ExportFormat.csv:
          return await _exportToCsv(lessonData);
      }
    } catch (e) {
      return ExportResult(
        success: false,
        error: 'Export failed: $e',
      );
    }
  }

  /// Bulk import lessons from CSV/Excel
  static Future<BulkImportResult> bulkImportLessons(
    String filePath,
    BulkImportFormat format,
  ) async {
    try {
      switch (format) {
        case BulkImportFormat.csv:
          return await _importFromCsv(filePath);
        case BulkImportFormat.excel:
          return await _importFromExcel(filePath);
        case BulkImportFormat.json:
          return await _importFromJsonFile(filePath);
      }
    } catch (e) {
      return BulkImportResult(
        success: false,
        error: 'Bulk import failed: $e',
        importedLessons: [],
        failedLessons: [],
      );
    }
  }

  /// Backup lessons
  static Future<BackupResult> createBackup(List<Map<String, dynamic>> lessons) async {
    try {
      final backup = LessonBackup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        lessons: lessons,
        version: '1.0',
        metadata: {
          'totalLessons': lessons.length,
          'createdBy': 'LearningApp',
          'platform': defaultTargetPlatform.name,
        },
      );

      final backupJson = backup.toJson();
      final fileName = 'lesson_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      
      if (kIsWeb) {
        // For web, return content for download
        return BackupResult(
          success: true,
          fileName: fileName,
          content: jsonEncode(backupJson),
          filePath: null,
        );
      } else {
        // For mobile/desktop, save to file
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonEncode(backupJson));
        
        return BackupResult(
          success: true,
          fileName: fileName,
          content: null,
          filePath: file.path,
        );
      }
    } catch (e) {
      return BackupResult(
        success: false,
        error: 'Backup failed: $e',
      );
    }
  }

  /// Restore from backup
  static Future<RestoreResult> restoreFromBackup(String backupContent) async {
    try {
      final backupData = jsonDecode(backupContent);
      final backup = LessonBackup.fromJson(backupData);
      
      return RestoreResult(
        success: true,
        lessons: backup.lessons,
        metadata: backup.metadata,
        restoredCount: backup.lessons.length,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        error: 'Restore failed: $e',
        lessons: [],
        metadata: {},
        restoredCount: 0,
      );
    }
  }

  // Private helper methods
  static Future<void> _saveHistory(List<ImportHistoryItem> history) async {
    // In a real implementation, save to SharedPreferences
    // For now, this is a placeholder
  }

  static Future<void> _saveFavorites(List<FavoriteImport> favorites) async {
    // In a real implementation, save to SharedPreferences
    // For now, this is a placeholder
  }

  static List<ImportHistoryItem> _getMockHistory() {
    return [
      ImportHistoryItem(
        title: 'JavaScript Promises',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        size: '2.3 KB',
        success: true,
      ),
      ImportHistoryItem(
        title: 'Python Data Types',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        size: '1.8 KB',
        success: true,
      ),
      ImportHistoryItem(
        title: 'SQL Joins',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        size: '3.1 KB',
        success: false,
        error: 'Invalid JSON format',
      ),
    ];
  }

  static List<FavoriteImport> _getMockFavorites() {
    return [
      FavoriteImport(
        id: '1',
        title: 'React Hooks Template',
        jsonContent: '{"lesson": {"title": "React Hooks"}}',
        addedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      FavoriteImport(
        id: '2',
        title: 'AWS Lambda Basics',
        jsonContent: '{"lesson": {"title": "AWS Lambda"}}',
        addedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  // Export format implementations
  static Future<ExportResult> _exportToJson(Map<String, dynamic> lessonData) async {
    final jsonString = const JsonEncoder.withIndent('  ').convert(lessonData);
    final fileName = '${lessonData['lesson']?['title'] ?? 'lesson'}_export.json';
    
    return ExportResult(
      success: true,
      fileName: fileName,
      content: jsonString,
      mimeType: 'application/json',
    );
  }

  static Future<ExportResult> _exportToPdf(Map<String, dynamic> lessonData) async {
    // In a real implementation, this would use a PDF generation library
    return ExportResult(
      success: false,
      error: 'PDF export not implemented yet',
    );
  }

  static Future<ExportResult> _exportToWord(Map<String, dynamic> lessonData) async {
    // In a real implementation, this would generate a Word document
    return ExportResult(
      success: false,
      error: 'Word export not implemented yet',
    );
  }

  static Future<ExportResult> _exportToMarkdown(Map<String, dynamic> lessonData) async {
    final lesson = lessonData['lesson'] ?? {};
    final content = List<Map<String, dynamic>>.from(lessonData['content'] ?? []);
    
    final buffer = StringBuffer();
    buffer.writeln('# ${lesson['title'] ?? 'Untitled Lesson'}');
    buffer.writeln();
    buffer.writeln(lesson['description'] ?? '');
    buffer.writeln();
    
    if (lesson['tags'] != null) {
      buffer.writeln('**Tags:** ${(lesson['tags'] as List).join(', ')}');
      buffer.writeln();
    }
    
    for (final item in content) {
      switch (item['type']) {
        case 'term':
          buffer.writeln('## ${item['title']}');
          buffer.writeln();
          buffer.writeln(item['content']);
          if (item['example'] != null) {
            buffer.writeln();
            buffer.writeln('**Example:** ${item['example']}');
          }
          buffer.writeln();
          break;
          
        case 'concept':
          buffer.writeln('## ${item['title']}');
          buffer.writeln();
          buffer.writeln(item['content']);
          if (item['key_points'] != null) {
            buffer.writeln();
            buffer.writeln('### Key Points:');
            for (final point in item['key_points']) {
              buffer.writeln('- $point');
            }
          }
          buffer.writeln();
          break;
          
        case 'mcq':
          buffer.writeln('### ${item['question']}');
          buffer.writeln();
          if (item['options'] != null) {
            for (int i = 0; i < item['options'].length; i++) {
              final option = item['options'][i];
              final marker = String.fromCharCode(65 + i); // A, B, C, D
              buffer.writeln('$marker. $option');
            }
          }
          buffer.writeln();
          buffer.writeln('**Answer:** ${item['correct_answer']}');
          if (item['explanation'] != null) {
            buffer.writeln('**Explanation:** ${item['explanation']}');
          }
          buffer.writeln();
          break;
      }
    }
    
    final fileName = '${lesson['title'] ?? 'lesson'}_export.md';
    
    return ExportResult(
      success: true,
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/markdown',
    );
  }

  static Future<ExportResult> _exportToCsv(Map<String, dynamic> lessonData) async {
    final content = List<Map<String, dynamic>>.from(lessonData['content'] ?? []);
    
    final buffer = StringBuffer();
    buffer.writeln('Type,Title,Content,Example,Options,Correct Answer,Explanation');
    
    for (final item in content) {
      final type = item['type'] ?? '';
      final title = _escapeCsv(item['title'] ?? '');
      final content = _escapeCsv(item['content'] ?? '');
      final example = _escapeCsv(item['example'] ?? '');
      final options = _escapeCsv((item['options'] as List?)?.join('|') ?? '');
      final correctAnswer = _escapeCsv(item['correct_answer'] ?? '');
      final explanation = _escapeCsv(item['explanation'] ?? '');
      
      buffer.writeln('$type,$title,$content,$example,$options,$correctAnswer,$explanation');
    }
    
    final fileName = '${lessonData['lesson']?['title'] ?? 'lesson'}_export.csv';
    
    return ExportResult(
      success: true,
      fileName: fileName,
      content: buffer.toString(),
      mimeType: 'text/csv',
    );
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  // Bulk import implementations
  static Future<BulkImportResult> _importFromCsv(String filePath) async {
    // In a real implementation, this would parse CSV files
    return BulkImportResult(
      success: false,
      error: 'CSV import not implemented yet',
      importedLessons: [],
      failedLessons: [],
    );
  }

  static Future<BulkImportResult> _importFromExcel(String filePath) async {
    // In a real implementation, this would parse Excel files
    return BulkImportResult(
      success: false,
      error: 'Excel import not implemented yet',
      importedLessons: [],
      failedLessons: [],
    );
  }

  static Future<BulkImportResult> _importFromJsonFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content);
      
      if (data is List) {
        // Multiple lessons
        final imported = <Map<String, dynamic>>[];
        final failed = <BulkImportError>[];
        
        for (int i = 0; i < data.length; i++) {
          try {
            final lesson = data[i] as Map<String, dynamic>;
            // Validate lesson structure here
            imported.add(lesson);
          } catch (e) {
            failed.add(BulkImportError(
              index: i,
              error: 'Invalid lesson format: $e',
              data: data[i],
            ));
          }
        }
        
        return BulkImportResult(
          success: true,
          importedLessons: imported,
          failedLessons: failed,
        );
      } else {
        // Single lesson
        return BulkImportResult(
          success: true,
          importedLessons: [data],
          failedLessons: [],
        );
      }
    } catch (e) {
      return BulkImportResult(
        success: false,
        error: 'Failed to read JSON file: $e',
        importedLessons: [],
        failedLessons: [],
      );
    }
  }
}

// Data models
class ImportHistoryItem {
  final String title;
  final DateTime timestamp;
  final String size;
  final bool success;
  final String? error;

  ImportHistoryItem({
    required this.title,
    required this.timestamp,
    required this.size,
    required this.success,
    this.error,
  });
}

class FavoriteImport {
  final String id;
  final String title;
  final String jsonContent;
  final DateTime addedAt;

  FavoriteImport({
    required this.id,
    required this.title,
    required this.jsonContent,
    required this.addedAt,
  });
}

class ExportResult {
  final bool success;
  final String? fileName;
  final String? content;
  final String? mimeType;
  final String? error;

  ExportResult({
    required this.success,
    this.fileName,
    this.content,
    this.mimeType,
    this.error,
  });
}

class BulkImportResult {
  final bool success;
  final String? error;
  final List<Map<String, dynamic>> importedLessons;
  final List<BulkImportError> failedLessons;

  BulkImportResult({
    required this.success,
    this.error,
    required this.importedLessons,
    required this.failedLessons,
  });
}

class BulkImportError {
  final int index;
  final String error;
  final dynamic data;

  BulkImportError({
    required this.index,
    required this.error,
    required this.data,
  });
}

class BackupResult {
  final bool success;
  final String? fileName;
  final String? content;
  final String? filePath;
  final String? error;

  BackupResult({
    required this.success,
    this.fileName,
    this.content,
    this.filePath,
    this.error,
  });
}

class RestoreResult {
  final bool success;
  final String? error;
  final List<Map<String, dynamic>> lessons;
  final Map<String, dynamic> metadata;
  final int restoredCount;

  RestoreResult({
    required this.success,
    this.error,
    required this.lessons,
    required this.metadata,
    required this.restoredCount,
  });
}

class LessonBackup {
  final String id;
  final DateTime createdAt;
  final List<Map<String, dynamic>> lessons;
  final String version;
  final Map<String, dynamic> metadata;

  LessonBackup({
    required this.id,
    required this.createdAt,
    required this.lessons,
    required this.version,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'lessons': lessons,
      'version': version,
      'metadata': metadata,
    };
  }

  factory LessonBackup.fromJson(Map<String, dynamic> json) {
    return LessonBackup(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      lessons: List<Map<String, dynamic>>.from(json['lessons']),
      version: json['version'],
      metadata: Map<String, dynamic>.from(json['metadata']),
    );
  }
}

enum ExportFormat {
  json,
  pdf,
  word,
  markdown,
  csv,
}

enum BulkImportFormat {
  csv,
  excel,
  json,
}
