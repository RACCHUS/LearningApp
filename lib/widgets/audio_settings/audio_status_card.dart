import 'package:flutter/material.dart';

/// Widget that displays the current status of audio features
/// Shows whether text-to-speech and voice input are available
class AudioStatusCard extends StatelessWidget {
  final bool canSpeak;
  final bool canListen;

  const AudioStatusCard({
    super.key,
    required this.canSpeak,
    required this.canListen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Features Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              icon: canSpeak ? Icons.check_circle : Icons.error,
              color: canSpeak ? Colors.green : Colors.red,
              text: 'Text-to-Speech: ${canSpeak ? 'Available' : 'Not Available'}',
            ),
            const SizedBox(height: 4),
            _buildStatusRow(
              icon: canListen ? Icons.check_circle : Icons.error,
              color: canListen ? Colors.green : Colors.red,
              text: 'Voice Input: ${canListen ? 'Available' : 'Not Available'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
