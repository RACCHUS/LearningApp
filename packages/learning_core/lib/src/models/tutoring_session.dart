/// Type of tutoring or educator session (ECO-12).
enum TutoringSessionType {
  oneOnOne,
  officeHours,
  groupWorkshop;

  static TutoringSessionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'office_hours':
      case 'officehours':
        return TutoringSessionType.officeHours;
      case 'group_workshop':
      case 'groupworkshop':
      case 'workshop':
        return TutoringSessionType.groupWorkshop;
      case 'one_on_one':
      case 'oneonone':
      default:
        return TutoringSessionType.oneOnOne;
    }
  }

  String toDbString() {
    switch (this) {
      case TutoringSessionType.oneOnOne:
        return 'one_on_one';
      case TutoringSessionType.officeHours:
        return 'office_hours';
      case TutoringSessionType.groupWorkshop:
        return 'group_workshop';
    }
  }

  String get label {
    switch (this) {
      case TutoringSessionType.oneOnOne:
        return '1-on-1 Mentorship';
      case TutoringSessionType.officeHours:
        return 'Open Office Hours';
      case TutoringSessionType.groupWorkshop:
        return 'Group Workshop';
    }
  }
}

/// An educator tutoring session or booking slot (ECO-12).
class TutoringSessionCore {
  final String id;
  final String tutorId;
  final String tutorName;
  final String targetDomain;
  final TutoringSessionType sessionType;
  final DateTime scheduledStartTime;
  final DateTime scheduledEndTime;
  final int hourlyRateCents;
  final String? bookedLearnerId;
  final String? meetingUrl;
  final bool isConfirmed;
  final String? sessionNotes;

  const TutoringSessionCore({
    required this.id,
    required this.tutorId,
    required this.tutorName,
    required this.targetDomain,
    required this.sessionType,
    required this.scheduledStartTime,
    required this.scheduledEndTime,
    this.hourlyRateCents = 0,
    this.bookedLearnerId,
    this.meetingUrl,
    this.isConfirmed = false,
    this.sessionNotes,
  });

  bool get isBooked => bookedLearnerId != null;

  int get durationMinutes =>
      scheduledEndTime.difference(scheduledStartTime).inMinutes;

  factory TutoringSessionCore.fromJson(Map<String, dynamic> json) {
    return TutoringSessionCore(
      id: json['id'] as String? ?? '',
      tutorId: json['tutor_id'] as String? ?? '',
      tutorName: json['tutor_name'] as String? ?? '',
      targetDomain: json['target_domain'] as String? ?? '',
      sessionType: TutoringSessionType.fromString(
          json['session_type'] as String? ?? 'one_on_one'),
      scheduledStartTime: DateTime.parse(json['scheduled_start_time'] as String? ??
          DateTime.now().toIso8601String()),
      scheduledEndTime: DateTime.parse(json['scheduled_end_time'] as String? ??
          DateTime.now().toIso8601String()),
      hourlyRateCents: (json['hourly_rate_cents'] as num?)?.toInt() ?? 0,
      bookedLearnerId: json['booked_learner_id'] as String?,
      meetingUrl: json['meeting_url'] as String?,
      isConfirmed: json['is_confirmed'] as bool? ?? false,
      sessionNotes: json['session_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tutor_id': tutorId,
        'tutor_name': tutorName,
        'target_domain': targetDomain,
        'session_type': sessionType.toDbString(),
        'scheduled_start_time': scheduledStartTime.toUtc().toIso8601String(),
        'scheduled_end_time': scheduledEndTime.toUtc().toIso8601String(),
        'hourly_rate_cents': hourlyRateCents,
        if (bookedLearnerId != null) 'booked_learner_id': bookedLearnerId,
        if (meetingUrl != null) 'meeting_url': meetingUrl,
        'is_confirmed': isConfirmed,
        if (sessionNotes != null) 'session_notes': sessionNotes,
      };
}
