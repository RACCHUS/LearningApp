import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/reference_practice_json_download.dart';

void main() {
  test('Filename contains UTC timestamp but no private owner or target IDs',() {
    expect(ReferencePracticeJsonDownload.filenameAt(
        DateTime.utc(2027,3,4,5,6,7)),
      'learningapp-exm-reference-practice-20270304T050607Z.json');
    expect(ReferencePracticeJsonDownload.filenameAt(
        DateTime(2027,3,4,5,6,7).toUtc()),endsWith('Z.json'));
    final filename=ReferencePracticeJsonDownload.filenameAt(
      DateTime.utc(2027,3,4,5,6,7));
    expect(filename,contains('reference-practice'));
    expect(filename,isNot(contains('@')));
    expect(filename,isNot(contains('owner')));
  });

  test('Unsupported non-browser platform refuses to claim a saved file',() {
    final download=ReferencePracticeJsonDownload();
    // This test runs on Dart VM, with the conditional platform stub.
    expect(download.isSupported,isFalse);
    expect(() => download.requestDownload(
      filename:'learningapp-exm-reference-practice-20270304T050607Z.json',
      json:'{"format":"reference-practice"}',
    ),throwsUnsupportedError);
  });
}
