import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Card displaying an available educator tutoring or office hours slot (ECO-12).
class TutoringBookingCard extends StatelessWidget {
  final TutoringSessionCore session;
  final void Function(TutoringSessionCore session)? onBook;

  const TutoringBookingCard({
    super.key,
    required this.session,
    this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rateDollars = (session.hourlyRateCents / 100).toStringAsFixed(2);

    return Card(
      key: Key('tutoring_card_${session.id}'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Type Badge & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    session.sessionType.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: session.isBooked ? Colors.grey.shade200 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    session.isBooked ? 'BOOKED' : 'AVAILABLE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: session.isBooked ? Colors.grey.shade700 : Colors.green.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Tutor Name & Domain
            Text(
              session.tutorName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              session.targetDomain,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 10),

            // Time & Rate row
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '${session.durationMinutes} mins',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 16),
                Icon(Icons.payments_outlined, size: 14, color: Colors.green.shade800),
                const SizedBox(width: 4),
                Text(
                  '\$$rateDollars/hr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),

            if (session.meetingUrl != null && session.isBooked) ...[
              const SizedBox(height: 8),
              Text(
                'Meeting Room: ${session.meetingUrl}',
                style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
              ),
            ],

            const SizedBox(height: 12),

            // Book Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: Key('book_session_button_${session.id}'),
                icon: const Icon(Icons.event_available),
                label: Text(session.isBooked ? 'Session Booked' : 'Book Mentorship Session'),
                onPressed: session.isBooked ? null : () => onBook?.call(session),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
