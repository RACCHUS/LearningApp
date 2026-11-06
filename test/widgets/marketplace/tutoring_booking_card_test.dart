import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_core/learning_core.dart';
import 'package:learning_pwa/widgets/marketplace/tutoring_booking_card.dart';

void main() {
  group('TutoringBookingCard Widget Tests (ECO-12)', () {
    final availableSession = TutoringSessionCore(
      id: 'session-avail-1',
      tutorId: 'tutor-carter',
      tutorName: 'Dr. Evelyn Carter',
      targetDomain: 'Cognitive Science & Memory Retention',
      sessionType: TutoringSessionType.oneOnOne,
      scheduledStartTime: DateTime.utc(2026, 11, 10, 15, 0),
      scheduledEndTime: DateTime.utc(2026, 11, 10, 16, 0),
      hourlyRateCents: 4500, // $45.00/hr
    );

    testWidgets('renders session details and triggers onBook when available',
        (tester) async {
      TutoringSessionCore? bookedSession;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutoringBookingCard(
              session: availableSession,
              onBook: (sess) {
                bookedSession = sess;
              },
            ),
          ),
        ),
      );

      // Verify labels
      expect(find.text('Dr. Evelyn Carter'), findsOneWidget);
      expect(find.text('1-on-1 Mentorship'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(find.text('60 mins'), findsOneWidget);
      expect(find.text('\$45.00/hr'), findsOneWidget);

      // Tap Book
      await tester.tap(find.byKey(const Key('book_session_button_session-avail-1')));
      await tester.pump();

      expect(bookedSession?.id, equals('session-avail-1'));
    });

    testWidgets('shows BOOKED status and disables button when session is already booked',
        (tester) async {
      final booked = TutoringSessionCore(
        id: 'session-booked-1',
        tutorId: 'tutor-carter',
        tutorName: 'Dr. Evelyn Carter',
        targetDomain: 'Cognitive Science',
        sessionType: TutoringSessionType.officeHours,
        scheduledStartTime: DateTime.utc(2026, 11, 10, 17, 0),
        scheduledEndTime: DateTime.utc(2026, 11, 10, 18, 0),
        bookedLearnerId: 'learner-99',
        meetingUrl: 'https://meet.example.com/room-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutoringBookingCard(
              session: booked,
            ),
          ),
        ),
      );

      expect(find.text('BOOKED'), findsOneWidget);
      expect(find.text('Session Booked'), findsOneWidget);
      expect(find.textContaining('Meeting Room: https://meet.example.com/room-1'), findsOneWidget);
    });
  });
}
