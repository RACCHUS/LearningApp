enum HelpCategory {
  gettingStarted,
  studying,
  practiceAndExams,
  progress,
  goalsAndMotivation,
  creatingContent,
  accountAndSettings,
}

extension HelpCategoryLabel on HelpCategory {
  String get label => switch (this) {
        HelpCategory.gettingStarted => 'Getting started',
        HelpCategory.studying => 'Studying',
        HelpCategory.practiceAndExams => 'Practice & exams',
        HelpCategory.progress => 'Progress',
        HelpCategory.goalsAndMotivation => 'Goals & motivation',
        HelpCategory.creatingContent => 'Creating content',
        HelpCategory.accountAndSettings => 'Account & settings',
      };
}

class HelpTopic {
  final String id;
  final HelpCategory category;
  final String title;
  final String summary;
  final String body;
  final List<String> keywords;
  final String? actionLabel;
  final String? actionRoute;

  const HelpTopic({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.body,
    this.keywords = const [],
    this.actionLabel,
    this.actionRoute,
  });

  String get searchableText => [
        title,
        summary,
        body,
        ...keywords,
      ].join(' ');
}
