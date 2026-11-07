import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('Cmi5Converter (ADL cmi5 Specification, OPP-5)', () {
    final au1 = Cmi5AssignableUnit(
      id: 'urn:learningapp:au:fire-hydraulics-101',
      title: 'Fire Hydraulics Principles',
      description: 'Understanding friction loss and nozzle pressure calculations.',
      url: 'https://learningapp.io/lesson/fire-hydraulics-101',
      launchMethod: Cmi5LaunchMethod.anyWindow,
      moveOn: Cmi5MoveOnCriteria.completedAndPassed,
      masteryScore: 0.85,
    );

    final au2 = Cmi5AssignableUnit(
      id: 'urn:learningapp:au:pump-operations-drill',
      title: 'Pump Discharge Drill',
      description: 'Practical calculation of engine pressures.',
      url: 'https://learningapp.io/lesson/pump-operations-drill',
      launchMethod: Cmi5LaunchMethod.ownWindow,
      moveOn: Cmi5MoveOnCriteria.passed,
      masteryScore: 0.80,
    );

    final manifest = Cmi5CourseManifest(
      courseId: 'urn:learningapp:course:apparatus-operator',
      title: 'Fire Apparatus Driver / Operator Certification',
      description: 'NFPA 1002 compliant driver operator training program.',
      publisher: 'Fire Rescue Academy',
      assignableUnits: [au1, au2],
    );

    test('serializes course package to valid ADL cmi5.xml format', () {
      final xml = manifest.toXml();

      expect(xml, contains('<courseStructure xmlns="https://w3id.org/xapi/profiles/cmi5/v1.0/CourseStructure.xsd">'));
      expect(xml, contains('<course id="urn:learningapp:course:apparatus-operator">'));
      expect(xml, contains('<langstring lang="en-US">Fire Apparatus Driver / Operator Certification</langstring>'));
      expect(xml, contains('<au id="urn:learningapp:au:fire-hydraulics-101" launchMethod="AnyWindow" moveOn="CompletedAndPassed" masteryScore="0.85">'));
      expect(xml, contains('<au id="urn:learningapp:au:pump-operations-drill" launchMethod="OwnWindow" moveOn="Passed" masteryScore="0.80">'));
      expect(xml, contains('<url>https://learningapp.io/lesson/fire-hydraulics-101</url>'));
    });

    test('roundtrips cmi5.xml via fromXml', () {
      final xml = manifest.toXml();
      final parsed = Cmi5CourseManifest.fromXml(xml);

      expect(parsed.courseId, equals(manifest.courseId));
      expect(parsed.title, equals(manifest.title));
      expect(parsed.description, equals(manifest.description));
      expect(parsed.assignableUnits.length, equals(2));

      final firstAu = parsed.assignableUnits[0];
      expect(firstAu.id, equals(au1.id));
      expect(firstAu.title, equals(au1.title));
      expect(firstAu.launchMethod, equals(Cmi5LaunchMethod.anyWindow));
      expect(firstAu.moveOn, equals(Cmi5MoveOnCriteria.completedAndPassed));
      expect(firstAu.masteryScore, equals(0.85));

      final secondAu = parsed.assignableUnits[1];
      expect(secondAu.id, equals(au2.id));
      expect(secondAu.launchMethod, equals(Cmi5LaunchMethod.ownWindow));
      expect(secondAu.moveOn, equals(Cmi5MoveOnCriteria.passed));
      expect(secondAu.masteryScore, equals(0.80));
    });

    test('generates compliant xAPI cmi5 launch and completion statements', () {
      final statement = Cmi5CourseManifest.createCmi5XapiStatement(
        actorEmail: 'cadet@academy.edu',
        actorName: 'Cadet Davis',
        verb: 'passed',
        au: au1,
        registrationId: 'reg-session-77',
        sessionId: 'session-token-9988',
        scaledScore: 0.92,
        rawScore: 92.0,
        success: true,
        completion: true,
        sessionDuration: const Duration(minutes: 18, seconds: 45),
      );

      expect(statement['actor']['mbox'], equals('mailto:cadet@academy.edu'));
      expect(statement['verb']['id'], equals('http://adlnet.gov/expapi/verbs/passed'));
      expect(statement['object']['id'], equals(au1.id));
      expect(statement['context']['registration'], equals('reg-session-77'));

      final extensions = statement['context']['extensions'] as Map<String, dynamic>;
      expect(extensions['https://w3id.org/xapi/cmi5/context/extensions/sessionid'], equals('session-token-9988'));

      final result = statement['result'] as Map<String, dynamic>;
      expect(result['score']['scaled'], equals(0.92));
      expect(result['success'], isTrue);
      expect(result['duration'], equals('PT1125S'));
    });
  });
}

