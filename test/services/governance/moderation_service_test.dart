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
  group('ECO-00B: Moderation Models Tests', () {
    test('ModerationReport serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 10, 18, 12, 0, 0);
      final report = ModerationReport(
        id: 'rep-12345',
        reporterId: 'usr-reporter-1',
        targetType: ModerationTargetType.lesson,
        targetId: 'lesson-101',
        reason: ReportReason.csamCsae,
        description: 'Harmful content detected',
        status: ReportStatus.pending,
        createdAt: now,
      );

      final json = report.toJson();
      expect(json['id'], 'rep-12345');
      expect(json['target_type'], 'lesson');
      expect(json['reason'], 'csam_csae');
      expect(json['status'], 'pending');

      final deserialized = ModerationReport.fromJson(json);
      expect(deserialized.id, report.id);
      expect(deserialized.targetType, ModerationTargetType.lesson);
      expect(deserialized.reason, ReportReason.csamCsae);
      expect(deserialized.status, ReportStatus.pending);
      expect(deserialized.createdAt, now);
      expect(deserialized.status.isTerminal, isFalse);
    });

    test('ReportStatus terminal checks', () {
      expect(ReportStatus.pending.isTerminal, isFalse);
      expect(ReportStatus.underReview.isTerminal, isFalse);
      expect(ReportStatus.resolvedActionTaken.isTerminal, isTrue);
      expect(ReportStatus.resolvedNoAction.isTerminal, isTrue);
      expect(ReportStatus.dismissed.isTerminal, isTrue);
    });

    test('ModerationRole role checks', () {
      final modRole = ModerationRole(
        id: 'role-1',
        userId: 'u1',
        role: 'moderator',
        grantedAt: DateTime.utc(2026, 10, 1),
      );
      expect(modRole.isModerator, isTrue);
      expect(modRole.isAdmin, isFalse);

      final adminRole = ModerationRole(
        id: 'role-2',
        userId: 'u2',
        role: 'admin',
        grantedAt: DateTime.utc(2026, 10, 1),
      );
      expect(adminRole.isModerator, isTrue);
      expect(adminRole.isAdmin, isTrue);
    });

    test('ModerationAction serialization roundtrip', () {
      final now = DateTime.utc(2026, 10, 18, 13, 0, 0);
      final action = ModerationAction(
        id: 'act-1',
        reportId: 'rep-12345',
        moderatorId: 'mod-1',
        action: ModerationActionType.contentRemoved,
        targetType: ModerationTargetType.course,
        targetId: 'course-99',
        reason: 'Violation of Terms of Service',
        notes: 'Target reviewed by legal team',
        createdAt: now,
      );

      final json = action.toJson();
      expect(json['action'], 'content_removed');
      expect(json['target_type'], 'course');
      expect(json['reason'], 'Violation of Terms of Service');

      final deserialized = ModerationAction.fromJson(json);
      expect(deserialized.id, action.id);
      expect(deserialized.action, ModerationActionType.contentRemoved);
      expect(deserialized.targetType, ModerationTargetType.course);
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
            'p_action': 'content_hidden',
            'p_reason': 'Pending investigation',
            'p_notes': 'Reported by community',
          },
        ),
      ).thenAnswer((_) => FakeRpcFilterBuilder<dynamic>(null));

      await service.applyModerationAction(
        reportId: 'rep-123',
        action: ModerationActionType.contentHidden,
        reason: 'Pending investigation',
        notes: 'Reported by community',
      );

      verify(
        mockSupabase.rpc(
          'apply_moderation_action',
          params: {
            'p_report_id': 'rep-123',
            'p_action': 'content_hidden',
            'p_reason': 'Pending investigation',
            'p_notes': 'Reported by community',
          },
        ),
      ).called(1);
    });
  });
}
