import 'package:flutter/material.dart';
import 'package:learning_pwa/services/study_set_service.dart';
import 'package:learning_pwa/services/saved_study_set_service.dart';

import 'flashcard_screen.dart';
import 'mcq_screen.dart';
import 'concept_screen.dart';
import 'mixed_mode_screen.dart';
import 'study_set_mixed_items.dart';

import 'package:learning_pwa/widgets/timer_widget.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:learning_pwa/widgets/error_retry_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/lesson_content.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';

class StudySetScreen extends StatefulWidget {
  final List<String> lessonIds;
  final String? studySetId;

  const StudySetScreen({Key? key, this.lessonIds = const [], this.studySetId})
    : super(key: key);

  @override
  State<StudySetScreen> createState() => _StudySetScreenState();
}

class _StudySetScreenState extends State<StudySetScreen> {
  void _launchStudyMode(BuildContext context, StudySet studySet, String mode) {
    if (mode == 'flashcards') {
      if (studySet.terms.isEmpty) {
        _showNoContentDialog(
          context,
          'No flashcards available for this lesson.',
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(terms: studySet.terms),
        ),
      );
    } else if (mode == 'mcq') {
      if (studySet.questions.isEmpty) {
        _showNoContentDialog(context, 'No MCQs available for this lesson.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => McqScreen(questions: studySet.questions),
        ),
      );
    } else if (mode == 'concepts') {
      final conceptsContent = studySetConceptContent(studySet.concepts);
      if (conceptsContent.isEmpty) {
        _showNoContentDialog(context, 'No concepts available for this lesson.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConceptScreen(concepts: conceptsContent),
        ),
      );
    } else if (mode == 'mixed') {
      if (studySet.terms.isEmpty &&
          studySet.questions.isEmpty &&
          studySet.concepts.isEmpty) {
        _showNoContentDialog(
          context,
          'No study content available for this lesson.',
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Consumer(
            builder: (context, ref, __) {
              final orderedContent = <LessonContent>[];
              var loading = false;
              for (final lessonId in studySet.lessonIds) {
                final lesson = ref.watch(lessonProvider(lessonId));
                loading |= lesson.isLoading;
                final content = lesson.valueOrNull?.lessonContent;
                if (content != null) orderedContent.addAll(content);
              }
              if (loading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return MixedModeScreen(
                preSortedItems: studySetMixedItems(
                  studySet,
                  orderedLessonContent: orderedContent,
                ),
              );
            },
          ),
        ),
      );
    }
  }

  void _showNoContentDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Content'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  late Future<StudySet> _studySetFuture;

  @override
  void initState() {
    super.initState();
    _loadStudySet();
  }

  void _loadStudySet() {
    _studySetFuture = _fetchStudySetData();
  }

  Future<StudySet> _fetchStudySetData() async {
    if (widget.studySetId != null && widget.studySetId!.isNotEmpty) {
      final savedService = SavedStudySetService();
      final savedSet = await savedService.getStudySet(widget.studySetId!);
      final content = await savedService.fetchStudySetContent(savedSet);
      return StudySet(
        lessonIds: savedSet.lessonIds,
        terms: content.terms,
        concepts: content.concepts,
        questions: content.questions,
      );
    }
    return StudySetService().fetchStudySet(widget.lessonIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Set'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final timerEnabled = ref.watch(
                timerProvider.select((s) => s.enabled),
              );
              final timerNotifier = ref.read(timerProvider.notifier);
              return IconButton(
                icon: Icon(
                  Icons.timer,
                  color: timerEnabled
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: timerEnabled ? 'Disable Timer' : 'Enable Timer',
                onPressed: () => timerNotifier.toggleEnabled(!timerEnabled),
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final timerEnabled = ref.watch(
            timerProvider.select((s) => s.enabled),
          );
          return Column(
            children: [
              if (timerEnabled) const TimerWidget(),
              Expanded(
                child: FutureBuilder<StudySet>(
                  future: _studySetFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ErrorRetryView(
                        message: 'Failed to load study set',
                        error: snapshot.error,
                        showDetails: kDebugMode,
                        onRetry: () => setState(() => _loadStudySet()),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Text('No study set data found.'),
                      );
                    }
                    final studySet = snapshot.data!;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Choose Study Mode:',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.style),
                                label: const Text('Flashcards'),
                                onPressed: () => _launchStudyMode(
                                  context,
                                  studySet,
                                  'flashcards',
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.quiz),
                                label: const Text('MCQ'),
                                onPressed: () =>
                                    _launchStudyMode(context, studySet, 'mcq'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.lightbulb),
                                label: const Text('Concepts'),
                                onPressed: () => _launchStudyMode(
                                  context,
                                  studySet,
                                  'concepts',
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Mixed'),
                                onPressed: () => _launchStudyMode(
                                  context,
                                  studySet,
                                  'mixed',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
