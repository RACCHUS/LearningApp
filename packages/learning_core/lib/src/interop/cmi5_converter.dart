/// ADL cmi5 Specification Course Structure and xAPI interoperability models (OPP-5).
///
/// cmi5 uses xAPI as its messaging protocol and specifies a standardized
/// course structure manifest (cmi5.xml) with Assignable Units (AUs).
library cmi5_converter;

enum Cmi5LaunchMethod {
  anyWindow,
  ownWindow,
}

enum Cmi5MoveOnCriteria {
  passed,
  completed,
  completedAndPassed,
  completedOrPassed,
  notApplicable,
}

/// Represents an Assignable Unit (AU) within a cmi5 course package.
class Cmi5AssignableUnit {
  final String id;
  final String title;
  final String description;
  final String url;
  final Cmi5LaunchMethod launchMethod;
  final Cmi5MoveOnCriteria moveOn;
  final double? masteryScore;
  final String activityType;

  const Cmi5AssignableUnit({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.launchMethod = Cmi5LaunchMethod.anyWindow,
    this.moveOn = Cmi5MoveOnCriteria.completedAndPassed,
    this.masteryScore,
    this.activityType = 'http://adlnet.gov/expapi/activities/lesson',
  });

  String get launchMethodString =>
      launchMethod == Cmi5LaunchMethod.ownWindow ? 'OwnWindow' : 'AnyWindow';

  String get moveOnString {
    switch (moveOn) {
      case Cmi5MoveOnCriteria.passed:
        return 'Passed';
      case Cmi5MoveOnCriteria.completed:
        return 'Completed';
      case Cmi5MoveOnCriteria.completedAndPassed:
        return 'CompletedAndPassed';
      case Cmi5MoveOnCriteria.completedOrPassed:
        return 'CompletedOrPassed';
      case Cmi5MoveOnCriteria.notApplicable:
        return 'NotApplicable';
    }
  }

  static Cmi5LaunchMethod parseLaunchMethod(String val) {
    if (val.toLowerCase() == 'ownwindow') return Cmi5LaunchMethod.ownWindow;
    return Cmi5LaunchMethod.anyWindow;
  }

  static Cmi5MoveOnCriteria parseMoveOn(String val) {
    switch (val.toLowerCase()) {
      case 'passed':
        return Cmi5MoveOnCriteria.passed;
      case 'completed':
        return Cmi5MoveOnCriteria.completed;
      case 'completedandpassed':
        return Cmi5MoveOnCriteria.completedAndPassed;
      case 'completedorpassed':
        return Cmi5MoveOnCriteria.completedOrPassed;
      default:
        return Cmi5MoveOnCriteria.notApplicable;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'url': url,
        'launchMethod': launchMethodString,
        'moveOn': moveOnString,
        if (masteryScore != null) 'masteryScore': masteryScore,
        'activityType': activityType,
      };

  factory Cmi5AssignableUnit.fromJson(Map<String, dynamic> json) {
    return Cmi5AssignableUnit(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      url: json['url'] as String,
      launchMethod: parseLaunchMethod(json['launchMethod'] as String? ?? 'AnyWindow'),
      moveOn: parseMoveOn(json['moveOn'] as String? ?? 'CompletedAndPassed'),
      masteryScore: (json['masteryScore'] as num?)?.toDouble(),
      activityType: json['activityType'] as String? ??
          'http://adlnet.gov/expapi/activities/lesson',
    );
  }
}

/// A complete cmi5 course package manifest representation.
class Cmi5CourseManifest {
  final String courseId;
  final String title;
  final String description;
  final String publisher;
  final List<Cmi5AssignableUnit> assignableUnits;

  const Cmi5CourseManifest({
    required this.courseId,
    required this.title,
    required this.description,
    this.publisher = 'LearningApp',
    required this.assignableUnits,
  });

  /// Serializes this course package to the ADL cmi5 XML specification (cmi5.xml).
  String toXml() {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="utf-8"?>');
    buffer.writeln(
        '<courseStructure xmlns="https://w3id.org/xapi/profiles/cmi5/v1.0/CourseStructure.xsd">');
    buffer.writeln('  <course id="$courseId">');
    buffer.writeln('    <title><langstring lang="en-US">${_escapeXml(title)}</langstring></title>');
    buffer.writeln(
        '    <description><langstring lang="en-US">${_escapeXml(description)}</langstring></description>');
    buffer.writeln('  </course>');

    for (final au in assignableUnits) {
      final masteryAttr =
          au.masteryScore != null ? ' masteryScore="${au.masteryScore!.toStringAsFixed(2)}"' : '';
      buffer.writeln(
          '  <au id="${au.id}" launchMethod="${au.launchMethodString}" moveOn="${au.moveOnString}"$masteryAttr>');
      buffer.writeln('    <title><langstring lang="en-US">${_escapeXml(au.title)}</langstring></title>');
      buffer.writeln(
          '    <description><langstring lang="en-US">${_escapeXml(au.description)}</langstring></description>');
      buffer.writeln('    <url>${_escapeXml(au.url)}</url>');
      buffer.writeln('    <activityType>${au.activityType}</activityType>');
      buffer.writeln('  </au>');
    }

    buffer.writeln('</courseStructure>');
    return buffer.toString();
  }

  /// Parses an ADL cmi5.xml course structure manifest.
  static Cmi5CourseManifest fromXml(String xml) {
    final courseIdMatch = RegExp(r'<course\s+id="([^"]+)"').firstMatch(xml);
    final courseId = courseIdMatch?.group(1) ?? 'urn:learningapp:course:unknown';

    // Extract course title & description
    final courseBlockMatch =
        RegExp(r'<course[^>]*>([\s\S]*?)<\/course>').firstMatch(xml);
    final courseBlock = courseBlockMatch?.group(1) ?? '';

    final courseTitleMatch =
        RegExp(r'<title>\s*<langstring[^>]*>(.*?)<\/langstring>\s*<\/title>')
            .firstMatch(courseBlock);
    final courseTitle = courseTitleMatch?.group(1) ?? 'Untitled Course';

    final courseDescMatch = RegExp(
            r'<description>\s*<langstring[^>]*>(.*?)<\/langstring>\s*<\/description>')
        .firstMatch(courseBlock);
    final courseDesc = courseDescMatch?.group(1) ?? '';

    // Extract AUs
    final auMatches = RegExp(r'<au\s+([^>]+)>([\s\S]*?)<\/au>').allMatches(xml);
    final aus = <Cmi5AssignableUnit>[];

    for (final m in auMatches) {
      final attrs = m.group(1) ?? '';
      final body = m.group(2) ?? '';

      final idMatch = RegExp(r'id="([^"]+)"').firstMatch(attrs);
      final id = idMatch?.group(1) ?? 'au_${aus.length}';

      final launchMatch = RegExp(r'launchMethod="([^"]+)"').firstMatch(attrs);
      final launchMethod = Cmi5AssignableUnit.parseLaunchMethod(
          launchMatch?.group(1) ?? 'AnyWindow');

      final moveOnMatch = RegExp(r'moveOn="([^"]+)"').firstMatch(attrs);
      final moveOn =
          Cmi5AssignableUnit.parseMoveOn(moveOnMatch?.group(1) ?? 'CompletedAndPassed');

      final masteryMatch = RegExp(r'masteryScore="([^"]+)"').firstMatch(attrs);
      final masteryScore = masteryMatch != null
          ? double.tryParse(masteryMatch.group(1) ?? '')
          : null;

      final titleMatch =
          RegExp(r'<title>\s*<langstring[^>]*>(.*?)<\/langstring>\s*<\/title>')
              .firstMatch(body);
      final title = titleMatch?.group(1) ?? 'AU';

      final descMatch = RegExp(
              r'<description>\s*<langstring[^>]*>(.*?)<\/langstring>\s*<\/description>')
          .firstMatch(body);
      final desc = descMatch?.group(1) ?? '';

      final urlMatch = RegExp(r'<url>(.*?)<\/url>').firstMatch(body);
      final url = urlMatch?.group(1) ?? '';

      final activityTypeMatch =
          RegExp(r'<activityType>(.*?)<\/activityType>').firstMatch(body);
      final activityType = activityTypeMatch?.group(1) ??
          'http://adlnet.gov/expapi/activities/lesson';

      aus.add(Cmi5AssignableUnit(
        id: id,
        title: _unescapeXml(title),
        description: _unescapeXml(desc),
        url: _unescapeXml(url),
        launchMethod: launchMethod,
        moveOn: moveOn,
        masteryScore: masteryScore,
        activityType: activityType,
      ));
    }

    return Cmi5CourseManifest(
      courseId: courseId,
      title: _unescapeXml(courseTitle),
      description: _unescapeXml(courseDesc),
      assignableUnits: aus,
    );
  }

  /// Generates a standardized xAPI statement for cmi5 execution events.
  /// Supported verbs: 'launched', 'initialized', 'completed', 'passed', 'failed', 'terminated'.
  static Map<String, dynamic> createCmi5XapiStatement({
    required String actorEmail,
    required String actorName,
    required String verb,
    required Cmi5AssignableUnit au,
    required String registrationId,
    required String sessionId,
    double? rawScore,
    double? scaledScore,
    bool? success,
    bool? completion,
    Duration? sessionDuration,
  }) {
    final verbUri = 'http://adlnet.gov/expapi/verbs/$verb';

    final result = <String, dynamic>{};
    if (scaledScore != null || rawScore != null) {
      result['score'] = {
        if (scaledScore != null) 'scaled': scaledScore,
        if (rawScore != null) 'raw': rawScore,
      };
    }
    if (success != null) result['success'] = success;
    if (completion != null) result['completion'] = completion;
    if (sessionDuration != null) {
      result['duration'] = 'PT${sessionDuration.inSeconds}S';
    }

    return {
      'actor': {
        'objectType': 'Agent',
        'name': actorName,
        'mbox': 'mailto:$actorEmail',
      },
      'verb': {
        'id': verbUri,
        'display': {'en-US': verb},
      },
      'object': {
        'id': au.id,
        'definition': {
          'type': au.activityType,
          'name': {'en-US': au.title},
          'description': {'en-US': au.description},
        },
      },
      'context': {
        'registration': registrationId,
        'contextActivities': {
          'category': [
            {'id': 'https://w3id.org/xapi/cmi5/context/categories/cmi5'}
          ]
        },
        'extensions': {
          'https://w3id.org/xapi/cmi5/context/extensions/sessionid': sessionId,
        },
      },
      if (result.isNotEmpty) 'result': result,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}

