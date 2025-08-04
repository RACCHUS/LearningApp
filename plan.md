# Learning PWA - Critical Reference

## Project Configuration
- **Framework**: Flutter Web + Supabase + Riverpod + GoRouter
- **Database**: Direct foreign key relationships (lesson_id), RLS disabled
- **Navigation**: URL-based routing with parameters (/lesson/:lessonId)

## 🎉 **SYSTEM STATUS: FULLY OPERATIONAL!**

### Critical Architecture Notes
- **Lesson Creation**: Uses LessonService.importLessonFromJson() with proper field mappings
- **Lesson Loading**: Manual Lesson object creation (not fromJson) + separate content queries
- **Database Schema**: Direct foreign keys (terms.lesson_id, questions.lesson_id, concepts.lesson_id)

### Known Working Components ✅
## Critical Development Guidelines
- **Flutter Commands**: Use VS Code tasks, NOT `flutter run` commands (they fail)
- **Command Timing**: Wait 10-15 seconds for commands to complete before proceeding
- **Error Handling**: Always implement enterprise-level defensive programming with comprehensive null safety
- **Database Queries**: Use individual queries, not complex joins or embedded relationships
## Critical Auth & Security
- **Authentication**: App starts as guest (UUID: 00000000-0000-0000-0000-000000000000), upgrades to Google sign-in when user authenticates.
- **RLS**: Disabled on all tables for now (enable before production).
  
- **Supabase Table Structure**: All content tables (terms, concepts, questions) use direct lesson_id foreign key, no join tables.
- **Database Queries**: Use individual queries for related data (not complex joins or embedded relationships) — this is the professional approach for Supabase/PostgREST and Flutter.
- **Model Construction**: All models (Lesson, Term, Concept, Question) are constructed manually from query results, not from embedded/related JSON.

## Critical Fix Reference
**Lesson Loading Error Fix**: Never use Lesson.fromJson() with Supabase responses - create Lesson objects manually since Supabase doesn't return embedded content arrays.



## Development Log
**Backend:**
- StudySetService implemented: fetches all terms, concepts, and questions for a list of lesson IDs using individual Supabase queries. Combines results into a StudySet model.


**UI/UX:**
- Lesson selection screen implemented (Checkboxes, Riverpod state, Create Study Set button).
- Study Set screen refactor in progress: launching interactive study sessions for selected content type(s) instead of displaying all at once.


### Current Focus

**Redesign Study Set experience for real studying:**
- StudySetScreen now shows a dialog/modal to choose a study mode (mixed, MCQ, concepts, or flashcards).
- All study modes (mixed, MCQ, concepts, flashcards) now launch their interactive flows.
- If there is no content for a selected mode, a user-friendly dialog is shown.
- Mixed mode is fully complete and interactive.
- MCQ, concepts, and flashcards modes are implemented and functional, pending further polish and UX improvements.
- After finishing all MCQ, flashcards, concepts, or mixed mode, a persistent button will appear, allowing the user to exit or review at any time. No dialogs will interrupt the flow.
- Each content type will use its own interactive study flow:
  - Flashcards: one card at a time, flip for answer, next/prev, progress bar.
  - MCQ: one question at a time, show options, select/check answer, feedback, next/prev, progress.
  - Concepts: one concept at a time, next/prev, progress.
- Navigation (next/previous) and progress indicators will be included for all study modes.
- User can focus on one content type at a time, or choose a mixed session.

## Next Steps

- Polish and refine interactive flows for each mode:
  - Flashcards (polish/UX improvements)
  - MCQ (polish/UX improvements)
  - Concepts (polish/UX improvements)
- Add a persistent exit/review button after completing each study mode (MCQ, flashcards, concepts, mixed) so the user can choose to exit or review, rather than being forced to leave. No dialogs will be used for this action.
- Ensure all study modes are fully interactive, polished, and user-friendly.
- Refactor large files (e.g., lesson_screen.dart) into more manageable widgets and parts for maintainability.
- Polish and fix the individual lesson screen (UI/UX, navigation, and study experience).
- Add and refine navigation and progress indicators for all study modes.
- Ensure user can choose and launch desired study mode before starting session.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs