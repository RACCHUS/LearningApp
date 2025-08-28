import 'package:flutter/material.dart';
import 'package:learning_pwa/widgets/audio_control_widget.dart';
import 'package:learning_pwa/theme/app_theme.dart';

/// Concept study content widget
/// 
/// Displays concepts with descriptions, examples, and audio controls
/// for comprehensive learning experience.
class ConceptContent extends StatelessWidget {
  final dynamic concept;

  const ConceptContent({
    super.key,
    required this.concept,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main concept with audio control
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  concept.conceptText,
                  style: textTheme.bodyLarge,
                ),
              ),
              AudioControlWidget(
                text: concept.conceptText,
                tooltip: 'Listen to concept',
              ),
            ],
          ),
          
          // Example section (if available)
          if (concept.exampleText != null) ...[
            const SizedBox(height: AppTheme.spacing24),
            const Divider(),
            const SizedBox(height: AppTheme.spacing16),
            
            // Example header with audio
            Row(
              children: [
                Text(
                  'Example:',
                  style: textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                AudioControlWidget(
                  text: concept.exampleText!,
                  tooltip: 'Listen to example',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
            
            // Example content
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                concept.exampleText!,
                style: textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          
          // Key points section (if available)
          if (concept.keyPoints != null && concept.keyPoints!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing24),
            const Divider(),
            const SizedBox(height: AppTheme.spacing16),
            
            Text(
              'Key Points:',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            
            ...concept.keyPoints!.map<Widget>((point) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
          ],
          
          // Additional spacing at bottom for scroll comfort
          const SizedBox(height: AppTheme.spacing24),
        ],
      ),
    );
  }
}
