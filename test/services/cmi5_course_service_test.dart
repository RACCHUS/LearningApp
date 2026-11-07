import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/services/interop/cmi5_course_service.dart';

void main() {
  group('Cmi5CourseService (ADL cmi5 Specification, OPP-5)', () {
    late Cmi5CourseService service;

    setUp(() {
      service = Cmi5CourseService();
    });

    final testLessons = [
      {
        'id': 'unit-1',
        'title': 'Hydraulic Principles',
        'description': 'Head loss and pipe friction calculation.',
        'path': 'modules/hydraulics-1',
        'mastery_score': 0.85,
      },
      {
        'id': 'unit-2',
        'title': 'Pump Operations Drill',
        'description': 'Discharge pressure practice.',
        'path': 'modules/pump-ops',
        'mastery_score': 0.80,
      },
    ];

    test('createCourseManifest generates structured manifest with AUs', () {
      final manifest = service.createCourseManifest(
        courseId: 'hvac-tech-core',
        title: 'HVAC Master Technician Program',
        description: 'Comprehensive thermodynamics and refrigerant handling.',
        lessonUnits: testLessons,
      );

      expect(manifest.courseId, equals('urn:learningapp:course:hvac-tech-core'));
      expect(manifest.title, equals('HVAC Master Technician Program'));
      expect(manifest.assignableUnits.length, equals(2));
      expect(manifest.assignableUnits.first.id, equals('urn:learningapp:au:unit-1'));
      expect(manifest.assignableUnits.first.masteryScore, equals(0.85));
      expect(manifest.assignableUnits.first.url, equals('https://app.learningapp.io/modules/hydraulics-1'));
    });

    test('exportToCmi5Xml produces compliant cmi5 XML document', () {
      final manifest = service.createCourseManifest(
        courseId: 'electrical-safety',
        title: 'NFPA 70E Arc Flash Safety',
        description: 'Electrical workplace safety standards.',
        lessonUnits: testLessons,
      );

      final xml = service.exportToCmi5Xml(manifest);

      expect(xml, contains('<courseStructure xmlns="https://w3id.org/xapi/profiles/cmi5/v1.0/CourseStructure.xsd">'));
      expect(xml, contains('<course id="urn:learningapp:course:electrical-safety">'));
      expect(xml, contains('<langstring lang="en-US">NFPA 70E Arc Flash Safety</langstring>'));
      expect(xml, contains('<au id="urn:learningapp:au:unit-1" launchMethod="AnyWindow" moveOn="CompletedAndPassed" masteryScore="0.85">'));
    });

    test('importFromCmi5Xml parses exported manifest accurately', () {
      final manifest = service.createCourseManifest(
        courseId: 'commercial-driving',
        title: 'CDL Air Brakes Endorsement',
        description: 'Pneumatic braking systems.',
        lessonUnits: testLessons,
      );

      final xml = service.exportToCmi5Xml(manifest);
      final parsed = service.importFromCmi5Xml(xml);

      expect(parsed.courseId, equals(manifest.courseId));
      expect(parsed.title, equals(manifest.title));
      expect(parsed.assignableUnits.length, equals(2));
      expect(parsed.assignableUnits[1].id, equals('urn:learningapp:au:unit-2'));
      expect(parsed.assignableUnits[1].masteryScore, equals(0.80));
    });

    test('generates compliant launch and completion xAPI statements', () {
      final au = Cmi5AssignableUnit(
        id: 'urn:learningapp:au:test-unit',
        title: 'Test AU',
        description: 'Test description',
        url: 'https://app.learningapp.io/test',
      );

      final launch = service.generateLaunchStatement(
        learnerEmail: 'operator@works.org',
        learnerName: 'Alex River',
        au: au,
        registrationId: 'reg-8812',
        sessionId: 'sess-abc-123',
      );

      expect(launch['verb']['id'], equals('http://adlnet.gov/expapi/verbs/launched'));
      expect(launch['actor']['mbox'], equals('mailto:operator@works.org'));

      final completion = service.generateCompletionStatement(
        learnerEmail: 'operator@works.org',
        learnerName: 'Alex River',
        au: au,
        registrationId: 'reg-8812',
        sessionId: 'sess-abc-123',
        passed: true,
        scorePercent: 94.0,
        duration: const Duration(minutes: 12),
      );

      expect(completion['verb']['id'], equals('http://adlnet.gov/expapi/verbs/passed'));
      expect(completion['result']['score']['scaled'], equals(0.94));
      expect(completion['result']['duration'], equals('PT720S'));
    });
  });
}

