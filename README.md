# Learning PWA

A Flutter-based Progressive Web App for creating, organizing, and studying educational content with AI-powered lesson generation and voice interaction.

## Features

### Core Learning
- **Lesson Management**: Create, view, and organize lessons with terms, questions, and concepts
- **Courses**: Group related lessons into structured courses with progress tracking
- **Study Sets**: Create custom study sessions from multiple lessons
- **Content Picker**: Granular selection of individual terms, questions, or concepts for focused study

### Voice Interaction
- **Speech-to-Text**: Answer questions using voice input
- **Text-to-Speech**: Audio playback of content for hands-free learning
- **Voice Commands**: Navigate and control the app using voice commands
- **Fuzzy Matching**: Smart answer validation that handles speech recognition inaccuracies

### Offline Support
- **Local Storage**: Lessons cached using Hive for offline access
- **Sync Status**: Visual indicators for sync state of each lesson
- **Background Sync**: Automatic synchronization when connectivity is restored

### AI Integration
- **Gemini-Powered Generation**: Generate lessons from text, images, or prompts
- **Smart Content Extraction**: Automatically parse terms, questions, and concepts

## Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **Local Storage**: Hive
- **Routing**: GoRouter
- **Push Notifications**: Firebase Cloud Messaging
- **Voice**: flutter_tts, speech_to_text

## Project Structure

```
lib/
├── main.dart              # App entry point
├── components/            # Reusable UI components
├── config/                # App configuration
├── core/                  # Core utilities and constants
├── models/                # Data models (Lesson, Term, Question, etc.)
├── providers/             # Riverpod providers and state management
├── screens/               # Screen widgets organized by feature
│   ├── auth/              # Login, registration
│   ├── courses/           # Course browsing and details
│   ├── home/              # Home screen components
│   ├── lessons/           # Lesson creation and selection
│   ├── study/             # Study session screens
│   └── study_sets/        # Study set management
├── services/              # Business logic and API clients
├── theme/                 # Design tokens and theming
├── utils/                 # Utility functions
└── widgets/               # Shared widgets
```

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK 3.0+
- Supabase project (or local instance)
- Firebase project (for push notifications)

### Environment Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd LearningApp
   ```

2. Create a `.env` file in the root directory:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   GEMINI_API_KEY=your_gemini_api_key (optional)
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Generate Hive adapters:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Database Setup

The app uses Supabase as its backend. See [database/README.md](database/README.md) for:
- Schema documentation
- Migration instructions
- Seed data

Key tables:
- `lessons` - Lesson content with terms, questions, concepts (JSONB)
- `courses` - Course metadata
- `course_lessons` - Course-to-lesson relationships
- `study_sets` - Saved study set configurations
- `course_progress`, `study_set_progress` - Progress tracking

### Running the App

```bash
# Web (Chrome)
flutter run -d chrome

# Desktop
flutter run -d windows  # or macos/linux

# Mobile
flutter run -d <device_id>
```

## Architecture

### State Management

The app uses Riverpod for state management with the following provider patterns:

- **StateNotifierProvider**: For mutable state (study progress, selections)
- **FutureProvider**: For async data loading (lessons, courses)
- **Provider**: For services and computed values

### Key Providers

| Provider | Purpose |
|----------|---------|
| `authProvider` | Authentication state |
| `lessonsProvider` | Lesson list and operations |
| `courseServiceProvider` | Course CRUD operations |
| `studySetProvider` | Study set state management |
| `contentSelectionProvider` | Content picker selections |

### Services

| Service | Purpose |
|---------|---------|
| `LessonService` | Lesson CRUD with Supabase |
| `CourseService` | Course management |
| `SavedStudySetService` | Persisted study sets |
| `SyncService` | Offline sync management |
| `VoiceInputService` | Speech recognition |
| `VoiceFeedbackService` | Text-to-speech |

## Key Screens

### Home Screen
Three-tab layout for navigating content:
- **Lessons**: Grid view of all lessons with search and filters
- **Courses**: User's courses with progress indicators
- **Study Sets**: Saved study set configurations

### Course Detail
View course info, lesson list, and study actions:
- Course metadata (category, difficulty, description)
- Ordered lesson list with content counts
- "Study All" for full course study session

### Content Picker
Granular content selection for custom study:
- Tabbed view: Terms, Questions, Concepts
- Select/deselect individual items
- Shows source lesson for context

### Study Session
Interactive study with multiple modes:
- Flashcard view with flip animation
- Q&A with text or voice input
- Progress tracking and scoring

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/lessons_provider_test.dart

# Run with coverage
flutter test --coverage
```

See [test/README.md](test/README.md) for testing guidelines.

## Deployment

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for:
- Web deployment (Firebase Hosting, Vercel)
- Mobile builds (Android, iOS)
- Environment configuration

## Contributing

1. Create a feature branch
2. Follow existing code patterns and naming conventions
3. Add tests for new functionality
4. Update relevant documentation
5. Submit a pull request

## License

This project is private and not licensed for public use.

---

For additional documentation, see:
- [CAREER_SKILLS_PLAN.md](CAREER_SKILLS_PLAN.md) - Career paths and skills system implementation plan
- [EDITOR_BUILDER_PLAN.md](EDITOR_BUILDER_PLAN.md) - Lesson editor and course builder plan
- [RELIABILITY_FIXES_PLAN.md](RELIABILITY_FIXES_PLAN.md) - Reliability fixes audit trail
