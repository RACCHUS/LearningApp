import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// Application title displayed in browser tabs and system headers
  ///
  /// In en, this message translates to:
  /// **'Learning PWA'**
  String get appTitle;

  /// Primary navigation destination for active study sessions and daily learning
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// Primary navigation destination for exploring courses, certifications, and career pathways
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Primary navigation destination for viewing learning analytics, mastery, and streaks
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// Navigation destination for user preferences and configuration
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Call to action button to begin a study session
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get actionStudy;

  /// Call to action button to review previously learned items
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get actionReview;

  /// Button to practice skills or pronunciation
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get actionPractice;

  /// Button to access the searchable help dialog and user guide
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get actionHelp;

  /// Button or title for settings and configuration
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get actionSettings;

  /// Button to cancel an action or dismiss a dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Button to save changes or settings
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Button to submit answers or forms
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// Button to retry a failed operation or quiz attempt
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// Button to close a modal dialog or drawer
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Button to proceed to the next step or lesson
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Button or action to search the catalog
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// Button to filter content or search results
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get actionFilter;

  /// Button to start an assessment or module
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// Button to complete or conclude an activity
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get actionFinish;

  /// Spaced repetition flashcard study mode
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get modeFlashcards;

  /// Assessment and practice quiz mode
  ///
  /// In en, this message translates to:
  /// **'Quiz'**
  String get modeQuiz;

  /// Reading comprehension study mode
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get modeReading;

  /// Voice-enabled hands-free interaction mode
  ///
  /// In en, this message translates to:
  /// **'Hands-Free Mode'**
  String get modeHandsFree;

  /// Speech and phonics pronunciation practice mode
  ///
  /// In en, this message translates to:
  /// **'Voice Practice'**
  String get modeVoice;

  /// General loading indicator message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get statusLoading;

  /// Badge or message indicating the application is operating offline
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get statusOffline;

  /// Indicator that network connectivity is active
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get statusOnline;

  /// General error status header
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// General success status header
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get statusSuccess;

  /// Status message while offline learning outbox events are syncing
  ///
  /// In en, this message translates to:
  /// **'Syncing changes...'**
  String get statusSyncing;

  /// Status message when offline sync is complete
  ///
  /// In en, this message translates to:
  /// **'All data synchronized'**
  String get statusUpToDate;

  /// Label for consecutive active learning days
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get metricStreak;

  /// Formatted streak count with plural support
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 Day Streak} other{{count} Days Streak}}'**
  String metricStreakCount(num count);

  /// Label for assessment or quiz score
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get metricScore;

  /// Label for knowledge mastery percentage
  ///
  /// In en, this message translates to:
  /// **'Mastery'**
  String get metricMastery;

  /// Label for response accuracy percentage
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get metricAccuracy;

  /// Label for experience points
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get metricXp;

  /// Learner level indicator
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String metricLevel(int level);

  /// Header title of the accessible help dialog
  ///
  /// In en, this message translates to:
  /// **'How Can We Help?'**
  String get helpDialogTitle;

  /// Placeholder text inside the search bar
  ///
  /// In en, this message translates to:
  /// **'Search lessons, certifications, topics...'**
  String get searchPlaceholder;

  /// Message displayed when a catalog search or filter produces no results
  ///
  /// In en, this message translates to:
  /// **'No courses or certifications found.'**
  String get emptyLibraryMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
