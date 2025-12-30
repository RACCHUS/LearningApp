import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_pwa/utils/haptic_utils.dart';

/// Celebration mode settings
enum CelebrationMode {
  on,
  off,
  auto, // Automatically disable on low-end devices
}

/// Provider for celebration settings
final celebrationModeProvider = StateProvider<CelebrationMode>((ref) {
  return CelebrationMode.auto;
});

/// Provider to track if celebration should play
final celebrationTriggerProvider = StateProvider<CelebrationType?>((ref) {
  return null;
});

/// Types of celebrations with different intensities
enum CelebrationType {
  lessonComplete,
  courseComplete,
  streakMilestone,
  achievementUnlock,
}

/// Performance-aware celebration overlay with confetti animation.
/// 
/// Automatically disables on:
/// - Small screens (< 500px width)
/// - Web platform (performance concerns)
/// - User preference set to off
/// - Low-end devices (auto mode)
class CelebrationOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const CelebrationOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<CelebrationOverlay> createState() => _CelebrationOverlayState();

  /// Check if celebrations should animate based on context and settings
  static bool shouldAnimate(BuildContext context, CelebrationMode mode) {
    // Always skip on web for performance
    if (kIsWeb) return false;

    // Check screen size - skip on small screens
    final size = MediaQuery.of(context).size;
    if (size.width < 500) return false;

    // Check user preference
    switch (mode) {
      case CelebrationMode.off:
        return false;
      case CelebrationMode.on:
        return true;
      case CelebrationMode.auto:
        // Auto mode - could add device capability checks here
        // For now, enable on devices with reasonable screen size
        return size.width >= 500;
    }
  }

  /// Trigger a celebration with persistence check
  static Future<void> trigger(
    WidgetRef ref,
    CelebrationType type, {
    bool checkCooldown = true,
  }) async {
    if (checkCooldown) {
      final prefs = await SharedPreferences.getInstance();
      final lastCelebration = prefs.getInt('last_celebration_${type.name}') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Cooldown: 5 seconds between same celebration type
      if (now - lastCelebration < 5000) return;
      
      await prefs.setInt('last_celebration_${type.name}', now);
    }

    ref.read(celebrationTriggerProvider.notifier).state = type;
  }
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _playCelebration(CelebrationType type) {
    final mode = ref.read(celebrationModeProvider);
    
    if (!CelebrationOverlay.shouldAnimate(context, mode)) {
      // Still play haptic even if visual is disabled
      HapticUtils.success();
      return;
    }

    // Configure based on celebration type
    switch (type) {
      case CelebrationType.lessonComplete:
        HapticUtils.success();
        _confettiController.play();
        break;
      case CelebrationType.courseComplete:
        HapticUtils.milestone();
        _confettiController.play();
        break;
      case CelebrationType.streakMilestone:
        HapticUtils.milestone();
        _confettiController.play();
        break;
      case CelebrationType.achievementUnlock:
        HapticUtils.success();
        _confettiController.play();
        break;
    }

    // Clear trigger after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ref.read(celebrationTriggerProvider.notifier).state = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen for celebration triggers
    ref.listen<CelebrationType?>(celebrationTriggerProvider, (previous, next) {
      if (next != null && previous != next) {
        _playCelebration(next);
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        
        // Confetti from top center
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 20, // Limited for performance
            maxBlastForce: 20,
            minBlastForce: 8,
            emissionFrequency: 0.05,
            gravity: 0.2,
            colors: [
              colorScheme.primary,
              colorScheme.secondary,
              colorScheme.tertiary,
              Colors.amber,
              Colors.orange,
              Colors.pink,
            ],
            createParticlePath: (size) {
              // Simple circle particles for better performance
              final path = Path();
              path.addOval(Rect.fromCircle(
                center: Offset.zero,
                radius: size.width / 2,
              ));
              return path;
            },
          ),
        ),
      ],
    );
  }
}

/// Compact celebration widget for inline use
class CelebrationBurst extends StatefulWidget {
  final bool trigger;
  final Widget child;

  const CelebrationBurst({
    super.key,
    required this.trigger,
    required this.child,
  });

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward().then((_) => _controller.reverse());
      HapticUtils.success();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
