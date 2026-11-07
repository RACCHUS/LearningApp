import 'package:learning_core/learning_core.dart';

/// Service providing ADL cmi5 course packaging and launch management (OPP-5).
class Cmi5CourseService {
  /// Converts learning unit manifests into an authoritative cmi5 course package manifest.
  Cmi5CourseManifest createCourseManifest({
    required String courseId,
    required String title,
    required String description,
    required List<Map<String, dynamic>> lessonUnits,
    String baseUrl = 'https://app.learningapp.io',
    String publisher = 'LearningApp',
  }) {
    final aus = <Cmi5AssignableUnit>[];

    for (int i = 0; i < lessonUnits.length; i++) {
      final unit = lessonUnits[i];
      final unitId = unit['id']?.toString() ?? 'au_${i + 1}';
      final unitTitle = unit['title']?.toString() ?? 'Lesson ${i + 1}';
      final unitDesc = unit['description']?.toString() ?? '';
      final path = unit['path']?.toString() ?? 'lesson/$unitId';
      final mastery = (unit['mastery_score'] as num?)?.toDouble() ?? 0.80;

      aus.add(Cmi5AssignableUnit(
        id: 'urn:learningapp:au:$unitId',
        title: unitTitle,
        description: unitDesc,
        url: '$baseUrl/$path',
        launchMethod: Cmi5LaunchMethod.anyWindow,
        moveOn: Cmi5MoveOnCriteria.completedAndPassed,
        masteryScore: mastery,
      ));
    }

    return Cmi5CourseManifest(
      courseId: courseId.startsWith('urn:') ? courseId : 'urn:learningapp:course:$courseId',
      title: title,
      description: description,
      publisher: publisher,
      assignableUnits: aus,
    );
  }

  /// Exports the given course manifest into the standardized ADL cmi5.xml string.
  String exportToCmi5Xml(Cmi5CourseManifest manifest) {
    return manifest.toXml();
  }

  /// Parses an external cmi5.xml file into a [Cmi5CourseManifest].
  Cmi5CourseManifest importFromCmi5Xml(String xml) {
    return Cmi5CourseManifest.fromXml(xml);
  }

  /// Creates a cmi5 launch session xAPI statement.
  Map<String, dynamic> generateLaunchStatement({
    required String learnerEmail,
    required String learnerName,
    required Cmi5AssignableUnit au,
    required String registrationId,
    required String sessionId,
  }) {
    return Cmi5CourseManifest.createCmi5XapiStatement(
      actorEmail: learnerEmail,
      actorName: learnerName,
      verb: 'launched',
      au: au,
      registrationId: registrationId,
      sessionId: sessionId,
    );
  }

  /// Creates a cmi5 completion session xAPI statement.
  Map<String, dynamic> generateCompletionStatement({
    required String learnerEmail,
    required String learnerName,
    required Cmi5AssignableUnit au,
    required String registrationId,
    required String sessionId,
    required bool passed,
    required double scorePercent,
    required Duration duration,
  }) {
    return Cmi5CourseManifest.createCmi5XapiStatement(
      actorEmail: learnerEmail,
      actorName: learnerName,
      verb: passed ? 'passed' : 'failed',
      au: au,
      registrationId: registrationId,
      sessionId: sessionId,
      scaledScore: scorePercent / 100.0,
      rawScore: scorePercent,
      success: passed,
      completion: true,
      sessionDuration: duration,
    );
  }
}

