import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/daily_goal_provider.dart';
import 'package:learning_pwa/models/lesson_progress.dart';
import 'package:learning_pwa/services/analytics/active_study_tracker.dart';
import 'package:learning_pwa/services/hive_service.dart';
import 'package:learning_pwa/services/progress_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Measures only a foreground lesson reader with recent learner input.
///
/// Not a page-open timer, and not a claim of mastery. Events are saved locally
/// before RPC sync. No frame-based writes, direct table DML or scored evidence.
class ActiveLessonStudyCapture extends ConsumerStatefulWidget {
  final String lessonId;
  final Widget child;

  const ActiveLessonStudyCapture({
    super.key,
    required this.lessonId,
    required this.child,
  });

  @override
  ConsumerState<ActiveLessonStudyCapture> createState() =>
      _ActiveLessonStudyCaptureState();
}

class _ActiveLessonStudyCaptureState extends ConsumerState<ActiveLessonStudyCapture>
    with WidgetsBindingObserver {
  final ActiveStudyTracker _tracker = ActiveStudyTracker();
  final HiveService _hive = HiveService();
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<void> _saveQueue = Future<void>.value();
  late final Future<void> _hiveReady = _hive.init();
  Timer? _ticker;
  StreamSubscription<AuthState>? _authSubscription;
  String _learnerId = 'local-user';
  bool _appVisible = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _learnerId = _supabase.auth.currentUser?.id ?? 'local-user';
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appVisible = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    if (_appVisible) _tracker.resume(DateTime.now());
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKey);
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) => _onTick());
    _authSubscription =
        _supabase.auth.onAuthStateChange.listen((_) => _reconcile());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reconcile();
  }

  @override
  void didUpdateWidget(covariant ActiveLessonStudyCapture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      _stop(oldWidget.lessonId);
      _reconcile();
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) _onInteraction();
    return false; // Never consume keys from lessons, inputs or assistive tools.
  }

  bool get _currentRouteVisible =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  void _reconcile() {
    if (!mounted) return;
    final nextLearner = _supabase.auth.currentUser?.id ?? 'local-user';
    if (nextLearner != _learnerId) {
      _stop(widget.lessonId);
      _learnerId = nextLearner;
    }

    if (!_appVisible || !_currentRouteVisible) {
      _stop(widget.lessonId);
    } else if (!_tracker.isForeground) {
      // Visibility alone earns nothing until a fresh input event arrives.
      _tracker.resume(DateTime.now());
    }
  }

  void _onTick() {
    if (!mounted) return;
    _reconcile();
    if (_tracker.isForeground) {
      _enqueue(_tracker.tick(DateTime.now()), widget.lessonId, _learnerId);
    }
  }

  void _onInteraction() {
    if (!mounted) return;
    _reconcile();
    if (_tracker.isForeground) {
      _enqueue(_tracker.interaction(DateTime.now()),
          widget.lessonId, _learnerId);
    }
  }

  void _stop(String lessonId) {
    if (!_tracker.isForeground) return;
    _enqueue(_tracker.pause(DateTime.now()), lessonId, _learnerId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _reconcile();
  }

  void _enqueue(
      List<ActiveStudyInterval> intervals, String lessonId, String learnerId) {
    if (intervals.isEmpty) return;
    // Snapshot these values. A logout or account switch must not reattribute
    // a pending event to the new authenticated user.
    _saveQueue = _saveQueue.then((_) async {
      await _hiveReady;
      for (final interval in intervals) {
        final record = UserProgress(
          id: const Uuid().v4(),
          userId: learnerId,
          lessonId: lessonId,
          studyMode: StudyMode.lesson,
          date: interval.end,
          questionsAnswered: 0,
          correctCount: 0,
          lessonCompleted: false,
          studyTimeSeconds: interval.seconds,
          isSynced: false,
          metadata: {
            'sync_active_interval': true,
            'active_time_measured': true,
            'interval_start': interval.start.toIso8601String(),
            'interval_end': interval.end.toIso8601String(),
          },
        );
        await _hive.cacheProgress(record);
      }
      if (mounted) ref.invalidate(dailyGoalProgressProvider);
    }).catchError((Object error, StackTrace stack) {
      // Do not forge an ACK; a write error means time is unavailable.
      debugPrint('Unable to cache active-study interval: $error');
    });

    // Local persistence is never blocked by network availability. The normal
    // offline sync service also retries pending interval actions on reconnect.
    unawaited(_saveQueue.then((_) => _attemptSync(learnerId)));
  }

  Future<void> _attemptSync(String learnerId) async {
    if (_syncing || _supabase.auth.currentUser?.id != learnerId) return;
    _syncing = true;
    try {
      await ProgressSyncService(_hive, _supabase).syncProgress();
    } catch (error) {
      debugPrint('Active-study events remain queued offline: $error');
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _authSubscription?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKey);
    WidgetsBinding.instance.removeObserver(this);
    _stop(widget.lessonId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onInteraction(),
      onPointerSignal: (_) => _onInteraction(), // Wheel / trackpad scroll.
      onPointerMove: (event) {
        if (event.buttons != 0) _onInteraction(); // Actual drag, not hover.
      },
      child: widget.child,
    );
  }
}
