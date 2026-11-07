import 'package:flutter/material.dart';

/// Card displaying a creator resource offer with transparent revenue share (ECO-12).
class ResourceOfferCard extends StatelessWidget {
  final String resourceId;
  final String title;
  final String targetDomain;
  final String creatorName;
  final int priceCents;
  final bool hasAccess;
  final void Function(String resourceId)? onUnlock;

  const ResourceOfferCard({
    super.key,
    required this.resourceId,
    required this.title,
    required this.targetDomain,
    required this.creatorName,
    required this.priceCents,
    this.hasAccess = false,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceDollars = (priceCents / 100).toStringAsFixed(2);
    final creatorNet = ((priceCents * 0.85) / 100).toStringAsFixed(2);
    final platformFee = ((priceCents * 0.15) / 100).toStringAsFixed(2);

    return Card(
      key: Key('resource_offer_card_$resourceId'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    targetDomain.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasAccess)
                  Container(
                    key: Key('unlocked_badge_$resourceId'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade800),
                    ),
                    child: Text(
                      'UNLOCKED / ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Creator
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'by $creatorName',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 12),

            // Pricing & Transparency Breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Offer Price:', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '\$$priceDollars',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Creator Net (85%):',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                      Text(
                        '\$$creatorNet',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Platform Fee (15%):',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                      Text(
                        '\$$platformFee',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: Key('unlock_button_$resourceId'),
                icon: Icon(hasAccess ? Icons.check : Icons.lock_open),
                label: Text(hasAccess ? 'Open Enrolled Resource' : 'Unlock Full Access (\$$priceDollars)'),
                style: hasAccess
                    ? ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white)
                    : null,
                onPressed: () => onUnlock?.call(resourceId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
