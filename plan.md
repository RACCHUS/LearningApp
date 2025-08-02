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

## Next Step
- **Combine Lessons for Study Sets**: Implement feature to allow users to select and combine multiple lessons into a custom study set. Requires UI for selection/combination and backend support for grouped lesson queries.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs