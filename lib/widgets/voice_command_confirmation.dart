import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/services/voice_command_corrector.dart';

/// Widget for confirming voice command corrections with the user
class VoiceCommandConfirmationDialog extends ConsumerStatefulWidget {
  final CorrectionSuggestion suggestion;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final VoidCallback? onTryAgain;

  const VoiceCommandConfirmationDialog({
    super.key,
    required this.suggestion,
    this.onConfirm,
    this.onReject,
    this.onTryAgain,
  });

  @override
  ConsumerState<VoiceCommandConfirmationDialog> createState() => 
      _VoiceCommandConfirmationDialogState();
}

class _VoiceCommandConfirmationDialogState 
    extends ConsumerState<VoiceCommandConfirmationDialog> {
  Timer? _autoCloseTimer;
  int _remainingSeconds = 5;

  @override
  void initState() {
    super.initState();
    _startAutoCloseTimer();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _startAutoCloseTimer() {
    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        // Auto-reject if no response
        widget.onReject?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Voice Command Clarification',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // What was heard
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I heard:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.suggestion.originalInput}"',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // What is suggested
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you mean:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${widget.suggestion.suggestedCommand}"',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(widget.suggestion.confidence * 100).toStringAsFixed(0)}% confidence',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                // Yes button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _autoCloseTimer?.cancel();
                      widget.onConfirm?.call();
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Yes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // No button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _autoCloseTimer?.cancel();
                      widget.onReject?.call();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('No'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Try Again button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _autoCloseTimer?.cancel();
                      widget.onTryAgain?.call();
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('Try Again'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Auto-close countdown
            if (_remainingSeconds > 0)
              Text(
                'Auto-closing in $_remainingSeconds seconds...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact overlay for voice confirmation (non-blocking)
class VoiceCommandConfirmationOverlay extends ConsumerStatefulWidget {
  final CorrectionSuggestion suggestion;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  const VoiceCommandConfirmationOverlay({
    super.key,
    required this.suggestion,
    this.onConfirm,
    this.onReject,
  });

  @override
  ConsumerState<VoiceCommandConfirmationOverlay> createState() => 
      _VoiceCommandConfirmationOverlayState();
}

class _VoiceCommandConfirmationOverlayState 
    extends ConsumerState<VoiceCommandConfirmationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
    
    // Auto-close after 3 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 3), () {
      widget.onReject?.call();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.mic,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Did you mean "${widget.suggestion.suggestedCommand}"?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'I heard: "${widget.suggestion.originalInput}"',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          _autoCloseTimer?.cancel();
                          widget.onConfirm?.call();
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Yes'),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          _autoCloseTimer?.cancel();
                          widget.onReject?.call();
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('No'),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to show voice confirmation dialog
Future<bool?> showVoiceConfirmationDialog(
  BuildContext context,
  CorrectionSuggestion suggestion,
) {
  final completer = Completer<bool?>();
  
  showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => VoiceCommandConfirmationDialog(
      suggestion: suggestion,
      onConfirm: () {
        Navigator.of(context).pop(true);
        completer.complete(true);
      },
      onReject: () {
        Navigator.of(context).pop(false);
        completer.complete(false);
      },
      onTryAgain: () {
        Navigator.of(context).pop(null);
        completer.complete(null);
      },
    ),
  );
  
  return completer.future;
}
