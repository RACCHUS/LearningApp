import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/config/brand_config.dart';
import 'package:learning_pwa/services/interop/lti_and_badges_service.dart';

void main() {
  group('LtiAndBadgesService', () {
    setUp(() {
      BrandConfig.reset();
    });

    test('issues compliant Open Badges 3.0 credential using active BrandConfig', () {
      final service = LtiAndBadgesService();
      final badge = service.issueOpenBadge(
        recipientId: 'user-did-12345',
        achievementId: 'https://learningapp.org/badges/adult-literacy-level-1',
        achievementName: 'Adult Literacy Foundations - Level 1',
        achievementDescription: 'Mastered consonant-vowel-consonant (CVC) decodable phonics.',
        criteriaNarrative: 'Scored 100% on decodable phonics assessments with hands-free audio validation.',
        badgeImageUrl: 'https://learningapp.org/assets/badges/literacy_l1.png',
        alignments: const [
          BadgeAlignmentCore(
            targetName: 'Foundational Reading CVC Words',
            targetUrl: 'https://standard.example.org/cvc',
          ),
        ],
      );

      final validation = service.validateBadge(badge);
      expect(validation.isValid, isTrue, reason: 'Validation errors: ${validation.errors}');

      expect(badge['issuer']['name'], equals('LearningApp Open Project'));
      expect(badge['credentialSubject']['achievement']['name'], equals('Adult Literacy Foundations - Level 1'));
      expect(badge['credentialSubject']['achievement']['image']['id'], equals('https://learningapp.org/assets/badges/literacy_l1.png'));
    });

    test('parses LTI 1.3 launch claims and verifies user role and AGS endpoints', () {
      final service = LtiAndBadgesService();
      final claims = {
        'sub': 'student-id-9988',
        LtiLaunchMessage.claimMessageType: 'LtiResourceLinkRequest',
        LtiLaunchMessage.claimVersion: '1.3.0',
        LtiLaunchMessage.claimResourceLink: {'id': 'link-101', 'title': 'Final Practice Exam'},
        LtiLaunchMessage.claimRoles: [
          'http://purl.imsglobal.org/vocab/lis/v2/membership#Learner',
        ],
        LtiLaunchMessage.claimAgsEndpoint: {
          'lineitem': 'https://lms.school.edu/api/courses/4/line_items/12',
          'scope': ['https://purl.imsglobal.org/spec/lti-ags/scope/score'],
        },
      };

      final launch = service.parseLaunchClaims(claims);
      expect(launch.userSub, equals('student-id-9988'));
      expect(launch.resourceLinkId, equals('link-101'));
      expect(launch.isLearner, isTrue);
      expect(launch.isInstructor, isFalse);
      expect(launch.hasGradeService, isTrue);
      expect(launch.agsLineItemUrl, equals('https://lms.school.edu/api/courses/4/line_items/12'));
    });

    test('syncs grade to LMS via LTI AGS v2.0 successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://lms.school.edu/api/courses/4/line_items/12/scores'));
        expect(request.headers['Content-Type'], contains('application/vnd.ims.lis.v1.score+json'));
        expect(request.headers['Authorization'], equals('Bearer test-token-123'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['userId'], equals('student-id-9988'));
        expect(body['scoreGiven'], equals(95.0));
        expect(body['scoreMaximum'], equals(100.0));
        expect(body['activityProgress'], equals('Completed'));
        expect(body['gradingProgress'], equals('FullyGraded'));

        return http.Response(jsonEncode({'status': 'success'}), 200);
      });

      final service = LtiAndBadgesService(httpClient: mockClient);
      final result = await service.syncGradeToLms(
        lineItemUrl: Uri.parse('https://lms.school.edu/api/courses/4/line_items/12/scores'),
        bearerToken: 'test-token-123',
        userId: 'student-id-9988',
        scoreGiven: 95.0,
        comment: 'Passed practice exam with 95%',
      );

      expect(result.success, isTrue);
      expect(result.statusCode, equals(200));
      expect(result.statusCode, equals(200));
      expect(result.message, contains('Score successfully posted'));
    });

    test('handles LMS AGS server errors gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Unauthorized lineitem access', 401);
      });

      final service = LtiAndBadgesService(httpClient: mockClient);
      final result = await service.syncGradeToLms(
        lineItemUrl: Uri.parse('https://lms.school.edu/api/courses/4/line_items/12/scores'),
        bearerToken: 'invalid-token',
        userId: 'student-id-9988',
        scoreGiven: 80.0,
      );

      expect(result.success, isFalse);
      expect(result.statusCode, equals(401));
      expect(result.message, contains('LMS AGS rejected score'));
    });
  });
}
