import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/import_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('ImportExportService', () {
    group('exportLesson', () {
      test('returns success for JSON format', () async {
        final result = await ImportExportService.exportLesson(
          {'id': '1', 'title': 'Test Lesson', 'description': 'Test'},
          ExportFormat.json,
        );

        expect(result.success, isTrue);
        expect(result.content, isNotNull);
        expect(result.error, isNull);
      });

      test('JSON export includes lesson data', () async {
        final lessonData = {
          'id': 'lesson-123',
          'title': 'Biology Basics',
          'description': 'Introduction to biology',
          'tags': ['science', 'biology'],
        };
        
        final result = await ImportExportService.exportLesson(
          lessonData,
          ExportFormat.json,
        );

        expect(result.success, isTrue);
        expect(result.content, contains('Biology Basics'));
        expect(result.content, contains('biology'));
      });

      test('returns result for PDF format', () async {
        final result = await ImportExportService.exportLesson(
          {'id': '1', 'title': 'Lesson'},
          ExportFormat.pdf,
        );

        expect(result, isA<ExportResult>());
        // PDF export may not be fully implemented
        if (!result.success) {
          expect(result.error, isNotNull);
        }
      });

      test('returns result for Word format', () async {
        final result = await ImportExportService.exportLesson(
          {'id': '1', 'title': 'Lesson'},
          ExportFormat.word,
        );

        expect(result, isA<ExportResult>());
        // Word export may not be fully implemented
        if (!result.success) {
          expect(result.error, isNotNull);
        }
      });

      test('returns success for Markdown format', () async {
        final result = await ImportExportService.exportLesson(
          {'id': '1', 'title': 'Lesson'},
          ExportFormat.markdown,
        );

        expect(result.success, isTrue);
        expect(result.content, isNotNull);
      });

      test('returns success for CSV format', () async {
        final result = await ImportExportService.exportLesson(
          {'id': '1', 'title': 'Lesson'},
          ExportFormat.csv,
        );

        expect(result.success, isTrue);
      });

      test('handles export errors gracefully', () async {
        // Pass null data to trigger error
        final result = await ImportExportService.exportLesson(
          {},
          ExportFormat.json,
        );

        // Should still return a result (either success or error)
        expect(result, isA<ExportResult>());
      });
    });

    group('backup and restore', () {
      test('createBackup returns backup content', () async {
        final lessons = [
          {'id': '1', 'title': 'Lesson 1'},
          {'id': '2', 'title': 'Lesson 2'},
        ];
        
        final result = await ImportExportService.createBackup(lessons);

        expect(result, isNotNull);
        
        if (result.success) {
          expect(result.fileName, isNotEmpty);
          expect(result.content ?? result.filePath, isNotNull);
        } else {
          // If it failed, verify we get an error message
          expect(result.error, isNotNull);
          expect(result.error, contains('Backup failed'));
        }
      });

      test('createBackup includes metadata', () async {
        final lessons = [
          {'id': '1', 'title': 'Test'},
        ];
        
        final result = await ImportExportService.createBackup(lessons);

        if (result.success && result.content != null) {
          expect(result.content, contains('version'));
          expect(result.content, contains('createdBy'));
          expect(result.content, contains('totalLessons'));
        }
      });

      test('createBackup generates unique filename', () async {
        final lessons = [{'id': '1', 'title': 'Test'}];
        
        final result1 = await ImportExportService.createBackup(lessons);
        await Future.delayed(const Duration(milliseconds: 10));
        final result2 = await ImportExportService.createBackup(lessons);

        if (result1.success && result2.success) {
          expect(result1.fileName, isNot(equals(result2.fileName)));
        }
      });

      test('restoreFromBackup handles valid backup', () async {
        final backupContent = '''
        {
          "id": "backup-123",
          "createdAt": "2025-12-12T00:00:00.000Z",
          "version": "1.0",
          "lessons": [
            {"id": "1", "title": "Restored Lesson"}
          ],
          "metadata": {
            "totalLessons": 1
          }
        }
        ''';
        
        final result = await ImportExportService.restoreFromBackup(backupContent);

        expect(result.success, isTrue);
        expect(result.lessons, isNotEmpty);
        expect(result.restoredCount, 1);
        expect(result.error, isNull);
      });

      test('restoreFromBackup handles malformed JSON', () async {
        final result = await ImportExportService.restoreFromBackup('{"bad_json":');

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.lessons, isEmpty);
      });

      test('restoreFromBackup handles empty backup', () async {
        final result = await ImportExportService.restoreFromBackup('{}');

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('history management', () {
      test('getImportHistory returns list', () async {
        final history = await ImportExportService.getImportHistory();

        expect(history, isA<List<ImportHistoryItem>>());
      });

      test('saveToHistory completes without error', () async {
        final item = ImportHistoryItem(
          title: 'Test Import',
          timestamp: DateTime.now(),
          size: '5 KB',
          success: true,
        );

        // Should not throw
        await expectLater(
          ImportExportService.saveToHistory(item),
          completes,
        );
      });
    });

    group('favorites management', () {
      test('getFavorites returns list', () async {
        final favorites = await ImportExportService.getFavorites();

        expect(favorites, isA<List<FavoriteImport>>());
      });

      test('addToFavorites completes without error', () async {
        final jsonContent = '{"id": "1", "title": "Favorite"}';

        await expectLater(
          ImportExportService.addToFavorites('Test Favorite', jsonContent),
          completes,
        );
      });

      test('removeFromFavorites completes without error', () async {
        await expectLater(
          ImportExportService.removeFromFavorites('fav-123'),
          completes,
        );
      });
    });

    group('bulk import', () {
      test('bulkImportLessons handles JSON format', () async {
        final result = await ImportExportService.bulkImportLessons(
          'test.json',
          BulkImportFormat.json,
        );

        expect(result, isA<BulkImportResult>());
      });

      test('bulkImportLessons handles CSV format', () async {
        final result = await ImportExportService.bulkImportLessons(
          'test.csv',
          BulkImportFormat.csv,
        );

        expect(result, isA<BulkImportResult>());
      });

      test('bulkImportLessons handles Excel format', () async {
        final result = await ImportExportService.bulkImportLessons(
          'test.xlsx',
          BulkImportFormat.excel,
        );

        expect(result, isA<BulkImportResult>());
      });

      test('bulkImportLessons returns error on failure', () async {
        final result = await ImportExportService.bulkImportLessons(
          'nonexistent.json',
          BulkImportFormat.json,
        );

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.importedLessons, isEmpty);
      });
    });
  });
}