import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/models/governance/moderation_report.dart';
import 'package:learning_pwa/services/governance/moderation_service.dart';
import '../../mocks/supabase_mocks.mocks.dart';

class FakeRpcFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  final T _value;
  FakeRpcFilterBuilder(this._value);

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) {
    return Future.value(_value).then(onValue, onError: onError);
  }
}

void main() {
  group('ECO-00B: Canonical Database Contract & Model Tests', () {
    test('ModerationReport serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 10, 18, 12, 0, 0);
      final report = ModerationReport(
        id: 'rep-12345',
        reporterId: 'usr-reporter-1',
        targetType: ModerationTargetType.lesson,
        targetId: 'lesson-101',
        reason: ReportReason.minorSafety,
        description: 'Harmful content detected',
        status: ReportStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      final json = report.toJson();
      expect(json['id'], 'rep-12345');
      expect(json['reporter_id'], 'usr-reporter-1');
      expect(json['target_type'], 'lesson');
      expect(json['reason'], 'minor_safety');
      expect(json['status'], 'pending');

      final deserialized = ModerationReport.fromJson(json);
      expect(deserialized.id, report.id);
      expect(deserialized.reporterId, 'usr-reporter-1');
      expect(deserialized.targetType, ModerationTargetType.lesson);
      expect(deserialized.reason, ReportReason.minorSafety);
      expect(deserialized.status, ReportStatus.pending);
      expect(deserialized.createdAt, now);
      expect(deserialized.updatedAt, now);
      expect(deserialized.status.isTerminal, isFalse);
    });

    test('ModerationReport handles null reporter_id (account deleted preservation)', () {
      final now = DateTime.utc(2026, 10, 18, 12, 0, 0);
      final json = {
        'id': 'rep-orphan',
        'reporter_id': null,
        'target_type': 'word_list',
        'target_id': 'wl-999',
        'reason': 'spam',
        'description': null,
        'status': 'actioned',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final deserialized = ModerationReport.fromJson(json);
      expect(deserialized.id, 'rep-orphan');
      expect(deserialized.reporterId, isNull);
      expect(deserialized.targetType, ModerationTargetType.wordList);
      expect(deserialized.reason, ReportReason.spam);
      expect(deserialized.status, ReportStatus.actioned);
      expect(deserialized.status.isTerminal, isTrue);
    });

    test('All canonical ReportStatus database values parse and roundtrip', () {
      const dbStatuses = ['pending', 'under_review', 'actioned', 'dismissed'];
      for (final dbVal in dbStatuses) {
        final status = ReportStatus.fromDb(dbVal);
        expect(status.dbValue, dbVal);
      }
      expect(ReportStatus.pending.isTerminal, isFalse);
      expect(ReportStatus.underReview.isTerminal, isFalse);
      expect(ReportStatus.actioned.isTerminal, isTrue);
      expect(ReportStatus.dismissed.isTerminal, isTrue);
    });

    test('Unknown ReportStatus fails visibly with FormatException', () {
      expect(() => ReportStatus.fromDb('unknown_status'), throwsFormatException);
      expect(() => ReportStatus.fromDb(null), throwsArgumentError);
    });

    test('All canonical ModerationActionType database values parse and roundtrip', () {
      const dbActions = ['dismiss', 'warn', 'hide', 'delete', 'suspend_user', 'rate_limit'];
      for (final dbVal in dbActions) {
        final action = ModerationActionType.fromDb(dbVal);
        expect(action.dbValue, dbVal);
      }
    });

    test('Unknown ModerationActionType fails visibly with FormatException', () {
      expect(() => ModerationActionType.fromDb('ban_forever'), throwsFormatException);
      expect(() => ModerationActionType.fromDb(null), throwsArgumentError);
    });

    test('All canonical ReportReason database values parse and roundtrip', () {
      const dbReasons = ['spam', 'harassment', 'misinformation', 'copyright', 'minor_safety', 'inappropriate', 'other'];
      for (final dbVal in dbReasons) {
        final reason = ReportReason.fromDb(dbVal);
        expect(reason.dbValue, dbVal);
      }
    });

    test('Unknown ReportReason fails visibly with FormatException', () {
      expect(() => ReportReason.fromDb('arbitrary_reason'), throwsFormatException);
      expect(() => ReportReason.fromDb(null), throwsArgumentError);
    });

    test('All canonical ModerationTargetType database values parse and roundtrip', () {
      const dbTargets = ['course', 'lesson', 'study_set', 'word_list', 'curriculum', 'resource', 'question', 'profile'];
      for (final dbVal in dbTargets) {
        final target = ModerationTargetType.fromDb(dbVal);
        expect(target.dbValue, dbVal);
      }
    });

    test('Unknown ModerationTargetType fails visibly with FormatException', () {
      expect(() => ModerationTargetType.fromDb('video'), throwsFormatException);
      expect(() => ModerationTargetType.fromDb(null), throwsArgumentError);
    });

    test('ModerationRole role checks and column alignment with created_at', () {
      final now = DateTime.utc(2026, 10, 1);
      final json = {
        'id': 'role-1',
        'user_id': 'u1',
        'role': 'moderator',
        'granted_by': 'admin-uuid',
        'created_at': now.toIso8601String(),
      };

      final role = ModerationRole.fromJson(json);
      expect(role.id, 'role-1');
      expect(role.userId, 'u1');
      expect(role.isModerator, isTrue);
      expect(role.isAdmin, isFalse);
      expect(role.createdAt, now);

      final adminRole = ModerationRole(
        id: 'role-2',
        userId: 'u2',
        role: 'admin',
        createdAt: now,
      );
      expect(adminRole.isModerator, isTrue);
      expect(adminRole.isAdmin, isTrue);
    });

    test('ModerationAction serialization roundtrip with null moderator_id', () {
      final now = DateTime.utc(2026, 10, 18, 13, 0, 0);
      final action = ModerationAction(
        id: 'act-1',
        reportId: 'rep-12345',
        moderatorId: null,
        action: ModerationActionType.delete,
        targetType: ModerationTargetType.course,
        targetId: 'course-99',
        reason: 'Violation of Terms of Service',
        notes: 'Target reviewed by legal team',
        createdAt: now,
      );

      final json = action.toJson();
      expect(json['action'], 'delete');
      expect(json['target_type'], 'course');
      expect(json['moderator_id'], isNull);

      final deserialized = ModerationAction.fromJson(json);
      expect(deserialized.id, action.id);
      expect(deserialized.action, ModerationActionType.delete);
      expect(deserialized.moderatorId, isNull);
      expect(deserialized.notes, 'Target reviewed by legal team');
    });
  });

  group('ECO-00B: ModerationService RPC Tests', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;
    late ModerationService service;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(mockSupabase.auth).thenReturn(mockAuth);
      service = ModerationService(supabase: mockSupabase);
    });

    test('isModerator returns false when currentUser is null', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await service.isModerator();
      expect(result, isFalse);
      verifyNever(mockSupabase.rpc('is_moderator'));
    });

    test('isModerator returns true when user is authenticated and RPC returns true', () async {
      final mockUser = User(
        id: 'mod-user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockSupabase.rpc('is_moderator'))
          .thenAnswer((_) => FakeRpcFilterBuilder<dynamic>(true));

      final result = await service.isModerator();
      expect(result, isTrue);
      verify(mockSupabase.rpc('is_moderator')).called(1);
    });

    test('isAdmin returns false when unauthenticated', () async {
      when(mockAuth.currentUser).thenReturn(null);

      final result = await service.isAdmin();
      expect(result, isFalse);
      verifyNever(mockSupabase.rpc('is_admin'));
    });

    test('isAdmin returns true when RPC returns true', () async {
      final mockUser = User(
        id: 'admin-user-1',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockSupabase.rpc('is_admin'))
          .thenAnswer((_) => FakeRpcFilterBuilder<dynamic>(true));

      final result = await service.isAdmin();
      expect(result, isTrue);
      verify(mockSupabase.rpc('is_admin')).called(1);
    });

    test('submitReport invokes submit_moderation_report RPC with mapped parameters', () async {
      const generatedReportId = 'rep-created-uuid-123';
      when(
        mockSupabase.rpc(
          'submit_moderation_report',
          params: {
            'p_target_type': 'lesson',
            'p_target_id': 'lesson-123',
            'p_reason': 'harassment',
            'p_description': 'Inappropriate comments',
          },
        ),
      ).thenAnswer((_) => FakeRpcFilterBuilder<dynamic>(generatedReportId));

      final result = await service.submitReport(
        targetType: ModerationTargetType.lesson,
        targetId: 'lesson-123',
        reason: ReportReason.harassment,
        description: 'Inappropriate comments',
      );

      expect(result, generatedReportId);
      verify(
        mockSupabase.rpc(
          'submit_moderation_report',
          params: {
            'p_target_type': 'lesson',
            'p_target_id': 'lesson-123',
            'p_reason': 'harassment',
            'p_description': 'Inappropriate comments',
          },
        ),
      ).called(1);
    });

    test('applyModerationAction invokes apply_moderation_action RPC atomically', () async {
      when(
        mockSupabase.rpc(
          'apply_moderation_action',
          params: {
            'p_report_id': 'rep-123',
            'p_action': 'hide',
            'p_reason': 'Pending investigation',
            'p_notes': 'Reported by community',
          },
        ),
      ).thenAnswer((_) => FakeRpcFilterBuilder<dynamic>(null));

      await service.applyModerationAction(
        reportId: 'rep-123',
        action: ModerationActionType.hide,
        reason: 'Pending investigation',
        notes: 'Reported by community',
      );

      verify(
        mockSupabase.rpc(
          'apply_moderation_action',
          params: {
            'p_report_id': 'rep-123',
            'p_action': 'hide',
            'p_reason': 'Pending investigation',
            'p_notes': 'Reported by community',
          },
        ),
      ).called(1);
    });
  });
}
