import 'package:flutter/material.dart';
import 'package:learning_pwa/services/study_set_service.dart';

import 'flashcard_screen.dart';
import 'mcq_screen.dart';
import 'concept_screen.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'mixed_mode_screen.dart';

import 'package:learning_pwa/widgets/timer_widget.dart';
import 'package:learning_pwa/providers/timer_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudySetScreen extends StatefulWidget {
  final List<String> lessonIds;
  const StudySetScreen({Key? key, required this.lessonIds}) : super(key: key);

  @override
  State<StudySetScreen> createState() => _StudySetScreenState();
}

class _StudySetScreenState extends State<StudySetScreen> {

  List<ConceptContent> _conceptsToContent(List<Concept> concepts) {
    return concepts.map((c) => ConceptContent(
      id: c.id,
      lessonId: c.lessonId,
      order: 0,
      conceptText: c.conceptText,
      exampleText: c.exampleText,
      keyPoints: null,
      createdAt: c.createdAt,
      updatedAt: c.createdAt,
    )).toList();
  }

  void _launchStudyMode(BuildContext context, StudySet studySet, String mode) {
    if (mode == 'flashcards') {
      if (studySet.terms.isEmpty) {
        _showNoContentDialog(context, 'No flashcards available for this lesson.');
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
      final conceptsContent = _conceptsToContent(studySet.concepts);
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
      if (studySet.terms.isEmpty && studySet.questions.isEmpty && studySet.concepts.isEmpty) {
        _showNoContentDialog(context, 'No study content available for this lesson.');
        return;
      }
      
      // For mixed mode, use lesson provider to get properly ordered content
      final lessonId = studySet.lessonIds.isNotEmpty ? studySet.lessonIds.first : null;
      if (lessonId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Consumer(
              builder: (context, ref, __) {
                final lessonAsync = ref.watch(lessonProvider(lessonId));
                return lessonAsync.when(
                  data: (data) {
                    if (data.lessonContent.isEmpty) {
                      return const Scaffold(
                        body: Center(
                          child: Text('No study content available for this lesson.'),
                        ),
                      );
                    }
                    
                    // Convert lesson content to MixedStudyItem with proper ordering
                    List<MixedStudyItem> orderedItems = [];
                    for (final content in data.lessonContent) {
                      if (content.runtimeType.toString() == 'Term') {
                        orderedItems.add(MixedStudyItem(type: 'flashcard', data: content));
                      } else if (content.runtimeType.toString() == 'Question') {
                        orderedItems.add(MixedStudyItem(type: 'mcq', data: content));
                      } else if (content.runtimeType.toString() == 'ConceptContent') {
                        orderedItems.add(MixedStudyItem(type: 'concept', data: content));
                      } else if (content.runtimeType.toString() == 'TextContent') {
                        orderedItems.add(MixedStudyItem(type: 'text', data: content));
                      }
                      // Content is already ordered by the lesson provider
                    }
                    
                    return MixedModeScreen(preSortedItems: orderedItems);
                  },
                  loading: () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => Scaffold(
                    body: Center(
                      child: Text('Error loading lesson: $e'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        // Fallback to old behavior if no lesson ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MixedModeScreen(
              terms: studySet.terms,
              questions: studySet.questions,
              concepts: _conceptsToContent(studySet.concepts),
            ),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
         title: const Text('Study Set'),
         actions: [
           Consumer(
             builder: (context, ref, _) {
               final timerEnabled = ref.watch(timerProvider.select((s) => s.enabled));
               final timerNotifier = ref.read(timerProvider.notifier);
               return IconButton(
                 icon: Icon(
                   Icons.timer,
                   color: timerEnabled ? Theme.of(context).colorScheme.primary : null,
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
          final timerEnabled = ref.watch(timerProvider.select((s) => s.enabled));
          return Column(
            children: [
              if (timerEnabled) const TimerWidget(),
              Expanded(
                child: FutureBuilder(
                  future: StudySetService().fetchStudySet(widget.lessonIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: \n'+ snapshot.error.toString() + '\nLesson IDs: \\${widget.lessonIds}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Center(
                        child: Text('No study set data found.\nLesson IDs: \\${widget.lessonIds}'),
                      );
                    }
                    final studySet = snapshot.data as StudySet;
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Choose Study Mode:', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.style),
                                label: const Text('Flashcards'),
                                onPressed: () => _launchStudyMode(context, studySet, 'flashcards'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.quiz),
                                label: const Text('MCQ'),
                                onPressed: () => _launchStudyMode(context, studySet, 'mcq'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.lightbulb),
                                label: const Text('Concepts'),
                                onPressed: () => _launchStudyMode(context, studySet, 'concepts'),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.shuffle),
                                label: const Text('Mixed'),
                                onPressed: () => _launchStudyMode(context, studySet, 'mixed'),
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
