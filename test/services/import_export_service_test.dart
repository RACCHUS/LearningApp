import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/import_export_service.dart';

void main() {
  group('ImportExportService', () {
    test('exportLesson returns success for JSON format', () async {
      final result = await ImportExportService.exportLesson(
        {'id': '1', 'title': 'Lesson'},
        ExportFormat.json,
      );

      expect(result.success, isTrue);
      expect(result.content, isNotNull);
    });

    test('createBackup returns backup content', () async {
      final result = await ImportExportService.createBackup([
        {'id': '1', 'title': 'Lesson'},
      ]);

      expect(result.success, isTrue);
      expect(result.fileName, isNotEmpty);
      expect(result.content ?? result.filePath, isNotNull);
    });

    test('restoreFromBackup handles malformed JSON', () async {
      final result = await ImportExportService.restoreFromBackup('{"bad_json":');

      expect(result.success, isFalse);
      expect(result.error, isNotNull);
    });
  });
}

