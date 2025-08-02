import 'package:flutter/material.dart';
import 'package:learning_pwa/services/study_set_service.dart';

import 'flashcard_screen.dart';
import 'mcq_screen.dart';
import 'concept_screen.dart';
import 'package:learning_pwa/models/concept.dart';
import 'package:learning_pwa/models/concept_content.dart';
import 'mixed_mode_screen.dart';

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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FlashcardScreen(terms: studySet.terms),
        ),
      );
    } else if (mode == 'mcq') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => McqScreen(questions: studySet.questions),
        ),
      );
    } else if (mode == 'concepts') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConceptScreen(concepts: _conceptsToContent(studySet.concepts)),
        ),
      );
    } else if (mode == 'mixed') {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Set')),
      body: FutureBuilder(
        future: StudySetService().fetchStudySet(widget.lessonIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: \n'+ snapshot.error.toString() + '\nLesson IDs: ${widget.lessonIds}'),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text('No study set data found.\nLesson IDs: ${widget.lessonIds}'),
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
    );
  }
}
