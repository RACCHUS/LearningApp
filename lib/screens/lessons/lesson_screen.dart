import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/progress_provider.dart';

class LessonScreen extends ConsumerStatefulWidget {
  final String lessonId;

  const LessonScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _saveProgress(int page) {
    final progressState = ref.read(userProgressProvider);
    if (progressState is ProgressLoaded) {
      final progress = progressState.progress.copyWith(lastPosition: page);
      ref.read(userProgressProvider.notifier)._upsertProgress(progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    final progressState = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: lessonAsync.when(
          data: (data) => Text(data.lesson.title),
          loading: () => const Text('Loading...'),
          error: (error, stackTrace) => const Text('Error'),
        ),
      ),
      body: lessonAsync.when(
        data: (data) {
          // On first build, jump to lastPosition if available
          if (!_initialized && progressState is ProgressLoaded && progressState.progress.lastPosition != null) {
            _currentPage = progressState.progress.lastPosition!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pageController.jumpToPage(_currentPage);
            });
            _initialized = true;
          }
          return PageView.builder(
            controller: _pageController,
            itemCount: data.lessonContent.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              _saveProgress(index);
            },
            itemBuilder: (context, index) {
              final content = data.lessonContent[index];
              return ListTile(
                title: Text(content.type),
                subtitle: Text(content.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}