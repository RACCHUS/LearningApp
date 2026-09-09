import 'package:flutter/material.dart';
import 'package:learning_pwa/services/safari_compatibility_service.dart';

/// Safari-specific permission request dialog
/// Provides clear instructions for Safari users on how to grant microphone access
class SafariPermissionDialog extends StatefulWidget {
  final VoidCallback? onPermissionGranted;
  final VoidCallback? onPermissionDenied;
  final VoidCallback? onFallbackToManual;

  const SafariPermissionDialog({
    super.key,
    this.onPermissionGranted,
    this.onPermissionDenied,
    this.onFallbackToManual,
  });

  @override
  State<SafariPermissionDialog> createState() => _SafariPermissionDialogState();
}

class _SafariPermissionDialogState extends State<SafariPermissionDialog> {
  bool _showDetailedInstructions = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSafariMobile = SafariCompatibilityService.isSafariMobile;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.mic,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Microphone Access'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Safari logo and version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.laptop_mac,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSafariMobile ? 'Safari Mobile' : 'Safari Desktop',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        if (SafariCompatibilityService.safariVersion.isNotEmpty)
                          Text(
                            'Version ${SafariCompatibilityService.safariVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Main instruction
            Text(
              'This app needs microphone access to recognize your voice commands.',
              style: theme.textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 12),
            
            // Safari-specific instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Safari Requirements',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Safari requires a button tap to access the microphone\n'
                    '2. The browser will show a permission dialog\n'
                    '3. Click "Allow" to enable voice commands',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Compatibility warnings
            if (SafariCompatibilityService.compatibilityWarnings.isNotEmpty) ...[
              ExpansionTile(
                title: Text(
                  'Safari Compatibility Info',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                initiallyExpanded: _showDetailedInstructions,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showDetailedInstructions = expanded;
                  });
                },
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: SafariCompatibilityService.compatibilityWarnings
                          .map((warning) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $warning',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],
            
            // Fallback options
            const SizedBox(height: 12),
            
            Text(
              'Alternative Options:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            ...SafariCompatibilityService.fallbackOptions.entries
                .take(2) // Show top 2 fallback options
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${entry.key}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )),
          ],
        ),
      ),
      actions: [
        // Manual input fallback
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onFallbackToManual?.call();
          },
          child: const Text('Use Text Input'),
        ),
        
        // Cancel
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPermissionDenied?.call();
          },
          child: const Text('Cancel'),
        ),
        
        // Allow microphone access
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onPermissionGranted?.call();
          },
          icon: const Icon(Icons.mic),
          label: const Text('Allow Microphone'),
        ),
      ],
    );
  }
}

/// Show Safari permission dialog
Future<void> showSafariPermissionDialog(
  BuildContext context, {
  VoidCallback? onPermissionGranted,
  VoidCallback? onPermissionDenied,
  VoidCallback? onFallbackToManual,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return SafariPermissionDialog(
        onPermissionGranted: onPermissionGranted,
        onPermissionDenied: onPermissionDenied,
        onFallbackToManual: onFallbackToManual,
      );
    },
  );
}

/// Safari browser capability status widget
class SafariBrowserStatus extends StatelessWidget {
  const SafariBrowserStatus({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SafariCompatibilityService.isSafari) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.laptop_mac,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Safari Browser Detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            _buildStatusRow(
              'Version',
              SafariCompatibilityService.safariVersion.isNotEmpty
                  ? SafariCompatibilityService.safariVersion
                  : 'Unknown',
              SafariCompatibilityService.safariVersion.isNotEmpty,
            ),
            
            _buildStatusRow(
              'Platform',
              SafariCompatibilityService.isSafariMobile ? 'Mobile' : 'Desktop',
              true,
            ),
            
            _buildStatusRow(
              'Voice Recognition',
              SafariCompatibilityService.supportsSpeechRecognition ? 'Supported' : 'Not Supported',
              SafariCompatibilityService.supportsSpeechRecognition,
            ),
            
            _buildStatusRow(
              'Reliable Speech',
              SafariCompatibilityService.hasReliableSpeechSupport ? 'Yes' : 'Limited',
              SafariCompatibilityService.hasReliableSpeechSupport,
            ),
            
            if (SafariCompatibilityService.isPrivateBrowsing)
              _buildStatusRow(
                'Private Browsing',
                'Active (may limit features)',
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Icon(
            isGood ? Icons.check_circle : Icons.warning,
            color: isGood ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isGood ? Colors.green.shade700 : Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
