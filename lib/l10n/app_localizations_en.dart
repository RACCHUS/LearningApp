// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Learning PWA';

  @override
  String get navLearn => 'Learn';

  @override
  String get navLibrary => 'Library';

  @override
  String get navProgress => 'Progress';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionStudy => 'Study';

  @override
  String get actionReview => 'Review';

  @override
  String get actionPractice => 'Practice';

  @override
  String get actionHelp => 'Help';

  @override
  String get actionSettings => 'Settings';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionClose => 'Close';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionFilter => 'Filter';

  @override
  String get actionStart => 'Start';

  @override
  String get actionFinish => 'Finish';

  @override
  String get modeFlashcards => 'Flashcards';

  @override
  String get modeQuiz => 'Quiz';

  @override
  String get modeReading => 'Reading';

  @override
  String get modeHandsFree => 'Hands-Free Mode';

  @override
  String get modeVoice => 'Voice Practice';

  @override
  String get statusLoading => 'Loading...';

  @override
  String get statusOffline => 'Offline Mode';

  @override
  String get statusOnline => 'Online';

  @override
  String get statusError => 'Error';

  @override
  String get statusSuccess => 'Success';

  @override
  String get statusSyncing => 'Syncing changes...';

  @override
  String get statusUpToDate => 'All data synchronized';

  @override
  String get metricStreak => 'Day Streak';

  @override
  String metricStreakCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString Days Streak',
      one: '1 Day Streak',
    );
    return '$_temp0';
  }

  @override
  String get metricScore => 'Score';

  @override
  String get metricMastery => 'Mastery';

  @override
  String get metricAccuracy => 'Accuracy';

  @override
  String get metricXp => 'XP';

  @override
  String metricLevel(int level) {
    return 'Level $level';
  }

  @override
  String get helpDialogTitle => 'How Can We Help?';

  @override
  String get searchPlaceholder => 'Search lessons, certifications, topics...';

  @override
  String get emptyLibraryMessage => 'No courses or certifications found.';
}
