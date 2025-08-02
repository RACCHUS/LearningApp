import 'package:flutter/material.dart';
import 'package:learning_pwa/services/study_set_service.dart';

class StudySetScreen extends StatelessWidget {
  final List<String> lessonIds;
  const StudySetScreen({Key? key, required this.lessonIds}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Set')),
      body: FutureBuilder(
        future: StudySetService().fetchStudySet(lessonIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: \\n"+ snapshot.error.toString() + "\\nLesson IDs: $lessonIds'),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text('No study set data found.\\nLesson IDs: $lessonIds'),
            );
          }
          final studySet = snapshot.data as StudySet;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Terms', style: Theme.of(context).textTheme.headlineSmall),
              ...studySet.terms.map((t) => ListTile(
                    title: Text(t.term),
                    subtitle: Text(t.definition),
                  )),
              const Divider(),
              Text('Concepts', style: Theme.of(context).textTheme.headlineSmall),
              ...studySet.concepts.map((c) => ListTile(
                    title: Text(c.conceptText),
                    subtitle: Text(c.exampleText ?? ''),
                  )),
              const Divider(),
              Text('Questions', style: Theme.of(context).textTheme.headlineSmall),
              ...studySet.questions.map((q) => ListTile(
                    title: Text(q.questionText),
                  )),
            ],
          );
        },
      ),
    );
  }
}
