import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('LtiLauncher (1EdTech LTI 1.3 & AGS 2.0)', () {
    final sampleClaims = {
      'sub': 'canvas_user_88219',
      LtiLaunchMessage.claimMessageType: 'LtiResourceLinkRequest',
      LtiLaunchMessage.claimVersion: '1.3.0',
      LtiLaunchMessage.claimResourceLink: {
        'id': 'res-link-10492',
        'title': 'Chapter 3: Calculus Foundations Assessment',
      },
      LtiLaunchMessage.claimContext: {
        'id': 'course-math-201',
        'label': 'MATH-201',
        'title': 'Applied Calculus II',
      },
      LtiLaunchMessage.claimRoles: [
        'http://purl.imsglobal.org/vocab/lis/v2/membership#Learner',
        'http://purl.imsglobal.org/vocab/lis/v2/institution/person#Student',
      ],
      LtiLaunchMessage.claimTargetLinkUri:
          'https://learningapp.org/launch/assessments/calc-ch3',
      LtiLaunchMessage.claimAgsEndpoint: {
        'scope': [
          'https://purl.imsglobal.org/spec/lti-ags/scope/lineitem',
          'https://purl.imsglobal.org/spec/lti-ags/scope/score',
        ],
        'lineitem':
            'https://canvas.example.edu/api/lti/courses/201/line_items/55',
      },
    };

    test('parses LTI 1.3 launch message claims accurately', () {
      final launch = LtiLaunchMessage.fromJwtClaims(sampleClaims);

      expect(launch.messageType, equals('LtiResourceLinkRequest'));
      expect(launch.version, equals('1.3.0'));
      expect(launch.resourceLinkId, equals('res-link-10492'));
      expect(launch.resourceLinkTitle, equals('Chapter 3: Calculus Foundations Assessment'));
      expect(launch.contextId, equals('course-math-201'));
      expect(launch.contextLabel, equals('MATH-201'));
      expect(launch.userSub, equals('canvas_user_88219'));

      // Roles
      expect(launch.isLearner, isTrue);
      expect(launch.isInstructor, isFalse);
      expect(launch.isAdmin, isFalse);

      // AGS Endpoint
      expect(launch.hasGradeService, isTrue);
      expect(launch.agsLineItemUrl, equals('https://canvas.example.edu/api/lti/courses/201/line_items/55'));
      expect(launch.agsScopes.length, equals(2));
    });

    test('identifies instructor role correctly from LTI role vocabulary', () {
      final instructorClaims = Map<String, dynamic>.from(sampleClaims);
      instructorClaims[LtiLaunchMessage.claimRoles] = [
        'http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor',
        'http://purl.imsglobal.org/vocab/lis/v2/institution/person#Faculty',
      ];

      final launch = LtiLaunchMessage.fromJwtClaims(instructorClaims);
      expect(launch.isInstructor, isTrue);
      expect(launch.isLearner, isFalse);
    });

    test('generates compliant AGS 2.0 grade passback payload', () {
      final timestamp = DateTime.parse('2026-11-06T14:30:00Z');
      final payload = LtiGradePassbackPayload(
        userId: 'canvas_user_88219',
        scoreGiven: 92.5,
        scoreMaximum: 100.0,
        activityProgress: 'Completed',
        gradingProgress: 'FullyGraded',
        timestamp: timestamp,
        comment: 'Mastery achieved across all 15 integral calculus items.',
      );

      final json = payload.toJson();
      expect(json['userId'], equals('canvas_user_88219'));
      expect(json['scoreGiven'], equals(92.5));
      expect(json['scoreMaximum'], equals(100.0));
      expect(json['activityProgress'], equals('Completed'));
      expect(json['gradingProgress'], equals('FullyGraded'));
      expect(json['timestamp'], equals('2026-11-06T14:30:00.000Z'));
      expect(json['comment'], contains('Mastery achieved'));
    });
  });
}

