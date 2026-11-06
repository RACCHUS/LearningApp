import 'package:flutter/material.dart';
import 'package:learning_core/learning_core.dart';

/// Card displaying creator profile and evidence-based learning gain ranking (OPP-2).
class CreatorChannelCard extends StatelessWidget {
  final CreatorProfileCore creator;
  final List<VideoInteractiveModule> modules;
  final void Function(VideoInteractiveModule module)? onSelectModule;

  const CreatorChannelCard({
    super.key,
    required this.creator,
    this.modules = const [],
    this.onSelectModule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metric = LearningGainCalculator.calculateChannelMetrics(
      channelId: creator.id,
      channelName: creator.channelName,
      modules: modules,
    );

    return Card(
      key: Key('creator_channel_card_${creator.id}'),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator info header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Text(
                    creator.channelName.isNotEmpty ? creator.channelName[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.displayName ?? creator.channelName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${creator.channelName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                // Measured Learning Gain Badge (OPP-2 differentiator)
                _buildGainBadge(context, metric),
              ],
            ),

            if (creator.bio != null && creator.bio!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                creator.bio!,
                style: theme.textTheme.bodySmall,
              ),
            ],

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Ranking Philosophy Subtitle
            Row(
              children: [
                Icon(Icons.verified, size: 14, color: theme.colorScheme.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ranked by measured learning gain (Hake g) - Not by likes or view counts',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Interactive Modules List
            if (modules.isNotEmpty) ...[
              Text(
                'Interactive Modules (${modules.length})',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...modules.map((mod) => _buildModuleTile(context, mod)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGainBadge(BuildContext context, CreatorChannelGainMetric metric) {
    final theme = Theme.of(context);
    final gainPct = (metric.averageNormalizedGain * 100).toInt();

    Color bgColor;
    Color fgColor;

    switch (metric.aggregateCategory) {
      case LearningGainCategory.high:
        bgColor = Colors.green.shade100;
        fgColor = Colors.green.shade900;
        break;
      case LearningGainCategory.medium:
        bgColor = Colors.blue.shade100;
        fgColor = Colors.blue.shade900;
        break;
      case LearningGainCategory.low:
        bgColor = Colors.amber.shade100;
        fgColor = Colors.amber.shade900;
        break;
      case LearningGainCategory.loss:
        bgColor = Colors.red.shade100;
        fgColor = Colors.red.shade900;
        break;
    }

    return Container(
      key: const Key('channel_gain_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fgColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph, size: 14, color: fgColor),
              const SizedBox(width: 4),
              Text(
                'Gain: $gainPct%',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            metric.aggregateCategory.toDbString().toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fgColor),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTile(BuildContext context, VideoInteractiveModule mod) {
    final theme = Theme.of(context);
    final prequestionCount = mod.prequestions.length;
    final retrievalCount = mod.retrievalCheckpoints.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: ListTile(
        key: Key('module_tile_${mod.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          mod.sourceType == VideoSourceType.youtube ? Icons.smart_display : Icons.video_library,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          mod.title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(
              VideoEmbedResolver.formatTimestamp(mod.durationSeconds),
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(width: 8),
            if (prequestionCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$prequestionCount prequestions',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            if (retrievalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$retrievalCount checkpoints',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onSelectModule?.call(mod),
      ),
    );
  }
}
