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
- StudySetScreen now launches a study session for the selected content type(s) instead of showing all content at once.
- Each content type (flashcards, MCQ, concepts) uses its own interactive study flow:
  - Flashcards: one card at a time, flip for answer, next/prev, progress bar.
  - MCQ: one question at a time, show options, select/check answer, feedback, next/prev, progress.
  - Concepts: one concept at a time, next/prev, progress.
- Navigation (next/previous) and progress indicators included for all study modes.
- User can focus on one content type at a time, or choose a mixed session (coming next).

## Next Steps

- Complete StudySetScreen refactor: mode selection UI and navigation to interactive study flows.
- Implement and polish interactive flows for each mode (flashcards, MCQ, concepts).
- Implement and polish "mixed" mode: present a shuffled sequence of flashcards, MCQs, and concepts, one at a time, with navigation and progress.
- Add and refine navigation and progress indicators for all study modes.
- Ensure user can choose and launch desired study mode before starting session.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs