import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/widgets/lesson_content_renderer.dart';

class LessonModeScreen extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonModeScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonModeScreen> createState() => _LessonModeScreenState();
}

class _LessonModeScreenState extends ConsumerState<LessonModeScreen> {
  int pageIndex = 0;

  @override
  void dispose() {
    super.dispose();
  }

  void nextPage(int total) {
    setState(() {
      pageIndex = (pageIndex + 1).clamp(0, total - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    return lessonAsync.when(
      data: (lessonData) {
        final contentList = lessonData.lessonContent;
        final content = contentList[pageIndex];

        return Scaffold(
          appBar: AppBar(
            title: Text(lessonData.lesson.title),
            actions: [
              if (pageIndex < contentList.length - 1)
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => nextPage(contentList.length),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: LinearProgressIndicator(
                    value: (pageIndex + 1) / contentList.length,
                    minHeight: 8,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('Progress: ${pageIndex + 1}/${contentList.length}'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LessonContentRenderer(
                      content: content,
                      onNext: () => nextPage(contentList.length),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
