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
- StudySetService: fetches all terms, concepts, and questions for a list of lesson IDs using individual Supabase queries and combines results into a StudySet model.
- Lesson selection screen: implemented with checkboxes, Riverpod state, and Create Study Set button.
- Study Set screen: launches interactive study sessions for selected content type(s).
- Manual model construction: All models (Lesson, Term, Concept, Question) are constructed manually from query results, not from embedded/related JSON.
- Guest access: App starts as guest and supports full functionality without sign-in; Google sign-in upgrades the session.
- Session persistence: User stays logged in or as guest across all pages.

## Critical Development Guidelines
- **Flutter Commands**: Use VS Code tasks, NOT `flutter run` commands (they fail)
- **Command Timing**: Wait 10-15 seconds for commands to complete before proceeding
- **Error Handling**: Always implement enterprise-level defensive programming with comprehensive null safety
- **Database Queries**: Use individual queries, not complex joins or embedded relationships
- **Refactor large files first**: If a file is getting too large or more features need to be added, refactor it into smaller widgets/parts before adding more code.
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


## Current Focus
- Add notification feature (push or in-app notifications) and settings screen; test both features.

## Next Steps
- Add notification feature and settings screen, and test them.
- Refactor large files first if more features are to be added.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs