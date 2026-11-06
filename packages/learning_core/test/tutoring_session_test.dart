import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('TutoringSessionCore (ECO-12)', () {
    test('serializes and evaluates session duration and booking status', () {
      final start = DateTime.utc(2026, 11, 10, 14, 0);
      final end = DateTime.utc(2026, 11, 10, 15, 0);

      final session = TutoringSessionCore(
        id: 'session-cna-1',
        tutorId: 'tutor-nurse-miller',
        tutorName: 'Nurse Miller, RN',
        targetDomain: 'Certified Nursing Assistant (CNA)',
        sessionType: TutoringSessionType.oneOnOne,
        scheduledStartTime: start,
        scheduledEndTime: end,
        hourlyRateCents: 3500, // $35/hr
        bookedLearnerId: 'learner-42',
        meetingUrl: 'https://meet.example.com/cna-prep-42',
        isConfirmed: true,
      );

      expect(session.durationMinutes, equals(60));
      expect(session.isBooked, isTrue);
      expect(session.sessionType.label, equals('1-on-1 Mentorship'));

      final json = session.toJson();
      final roundTrip = TutoringSessionCore.fromJson(json);

      expect(roundTrip.id, equals('session-cna-1'));
      expect(roundTrip.tutorName, equals('Nurse Miller, RN'));
      expect(roundTrip.isConfirmed, isTrue);
      expect(roundTrip.hourlyRateCents, equals(3500));
    });
  });
}
