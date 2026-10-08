import 'package:learning_pwa/models/help_topic.dart';

const helpTopics = <HelpTopic>[
  HelpTopic(
    id: 'find-learning',
    category: HelpCategory.gettingStarted,
    title: 'Find something to learn',
    summary: 'Browse exams, certifications, courses, subjects, and other learning targets.',
    body:
        'Open Library to search or browse what is available. When you choose something, the app creates a learning context and Learn will show what to do next.',
    keywords: ['start', 'course', 'exam', 'certification', 'subject', 'library', 'browse'],
    actionLabel: 'Open Library',
    actionRoute: '/library',
  ),
  HelpTopic(
    id: 'learning-paths',
    category: HelpCategory.gettingStarted,
    title: 'How learning paths work',
    summary: 'Understand goals, paths, courses, lessons, and learning contexts.',
    body:
        'A learning context is simply what you are focused on right now. It can point to a goal, path, course, lesson, or study set. You can switch contexts without losing progress.',
    keywords: ['path', 'context', 'goal', 'course', 'lesson', 'switch'],
    actionLabel: 'Open Library',
    actionRoute: '/library',
  ),
  HelpTopic(
    id: 'study-timer-breaks',
    category: HelpCategory.studying,
    title: 'Study timer & breaks',
    summary: 'Use the optional timer and break prompts during study sessions.',
    body:
        'The study timer is optional. Start studying first, then use the timer control when you want a structured focus block. Break prompts can help pace longer sessions without changing what you are learning.',
    keywords: ['timer', 'pomodoro', 'break', 'focus block', 'countdown', '25 minutes'],
  ),
  HelpTopic(
    id: 'focus-mode',
    category: HelpCategory.studying,
    title: 'Focus mode',
    summary: 'Hide nonessential study chrome when you want fewer distractions.',
    body:
        'Focus mode is available from supported study screens. It reduces visible controls while keeping the current learning activity and progress available.',
    keywords: ['focus', 'distraction', 'fullscreen', 'study mode', 'hide controls'],
  ),
  HelpTopic(
    id: 'study-batch-size',
    category: HelpCategory.studying,
    title: 'Cards per study session',
    summary: 'Choose how many cards appear in a study batch.',
    body:
        'Cards per study session is a device setting. Use a smaller batch for short sessions or increase it when you want a longer run.',
    keywords: ['cards', 'batch', 'batch size', 'session size', 'flashcards'],
    actionLabel: 'Open Settings',
    actionRoute: '/settings',
  ),
  HelpTopic(
    id: 'recall-before-reveal',
    category: HelpCategory.studying,
    title: 'Recall before reveal',
    summary: 'Prompt yourself to remember an answer before seeing it.',
    body:
        'Recall before reveal encourages active retrieval instead of passive reading. You can turn it on or off in Settings.',
    keywords: ['recall', 'reveal', 'memory', 'active retrieval', 'answer'],
    actionLabel: 'Open Settings',
    actionRoute: '/settings',
  ),
  HelpTopic(
    id: 'flashcards',
    category: HelpCategory.practiceAndExams,
    title: 'Flashcards',
    summary: 'Practice terms and concepts with active recall.',
    body:
        'Flashcards are repeatable practice. Use them to recall the answer before revealing it, then continue reviewing as items become due again.',
    keywords: ['flashcard', 'cards', 'terms', 'definitions', 'practice'],
  ),
  HelpTopic(
    id: 'practice-questions',
    category: HelpCategory.practiceAndExams,
    title: 'Practice questions',
    summary: 'Use questions for retrieval practice and immediate feedback.',
    body:
        'Practice questions help you test what you can retrieve, not just what looks familiar. Feedback appears after answering so you can correct mistakes immediately.',
    keywords: ['quiz', 'question', 'mcq', 'practice', 'feedback'],
  ),
  HelpTopic(
    id: 'mock-exams',
    category: HelpCategory.practiceAndExams,
    title: 'Mock exams',
    summary: 'Use exam-style practice when a learning target provides it.',
    body:
        'Mock exams are for exam-like practice rather than first-run setup. Open the relevant exam or course in Library to see the assessment options available for that target.',
    keywords: ['mock exam', 'practice test', 'exam mode', 'assessment', 'test'],
    actionLabel: 'Open Library',
    actionRoute: '/library',
  ),
  HelpTopic(
    id: 'completion-retention',
    category: HelpCategory.progress,
    title: 'Completion vs retention',
    summary: 'Completion and retention answer different questions.',
    body:
        'Completion shows how much material you have worked through. Retention reflects retrieval history for concepts. Finishing a course does not mean every concept is equally well retained.',
    keywords: ['retention', 'mastery', 'progress', 'completion', 'knowledge', 'remember'],
    actionLabel: 'Open Progress',
    actionRoute: '/progress',
  ),
  HelpTopic(
    id: 'daily-study-goal',
    category: HelpCategory.goalsAndMotivation,
    title: 'Daily study goal',
    summary: 'Set an optional daily time goal after you decide it is useful.',
    body:
        'Daily study goals are optional and are not required to start learning. You can set, change, or remove your device-local goal in Settings at any time.',
    keywords: ['goal', 'daily goal', 'minutes per day', 'study time', 'habit'],
    actionLabel: 'Open Settings',
    actionRoute: '/settings',
  ),
  HelpTopic(
    id: 'motivation',
    category: HelpCategory.goalsAndMotivation,
    title: 'XP, streaks & celebrations',
    summary: 'Control optional motivation mechanics without affecting learning access.',
    body:
        'XP, streaks, and celebrations are optional motivation features. They do not control access to your learning content and can be adjusted in Motivation settings.',
    keywords: ['xp', 'streak', 'celebration', 'motivation', 'levels', 'gamification'],
    actionLabel: 'Open Motivation settings',
    actionRoute: '/settings/motivation',
  ),
  HelpTopic(
    id: 'create-learning-goal',
    category: HelpCategory.creatingContent,
    title: 'Create your own learning goal',
    summary: 'Create a custom target when the catalog does not contain what you need.',
    body:
        'Use Library to create your own learning goal or content. This is useful for a custom course, syllabus, certification plan, or personal topic.',
    keywords: ['create', 'my own', 'custom', 'goal', 'target', 'content'],
    actionLabel: 'Open Library',
    actionRoute: '/library',
  ),
  HelpTopic(
    id: 'account-settings',
    category: HelpCategory.accountAndSettings,
    title: 'Sign in and device settings',
    summary: 'Manage your account and device-local study preferences.',
    body:
        'Use the account control to sign in or open your profile. Settings includes device-local preferences such as notifications, daily goal, study batch size, theme, and recall behavior.',
    keywords: ['sign in', 'login', 'account', 'settings', 'notifications', 'theme'],
    actionLabel: 'Open Settings',
    actionRoute: '/settings',
  ),
];
