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
- Study Set screen implemented (displays combined content).



**What Was Tried:**
- Added a "Create Study Set" button to the Home page to navigate to the lesson selection screen using `/lesson-selection` route.
- When clicking the button, received error: `Page not found: GoException: no routes for location: /lesson-selection`.
- Confirmed that the route for lesson selection was not yet registered in GoRouter.
- Registered the lesson selection screen route in GoRouter.
- Able to reach the lesson selection screen from Home.
- When selecting lessons and clicking "Create Study Set", received error:

  > Navigator.onGenerateRoute was null, but the route named "/study-set?..." was referenced. To use the Navigator API with named routes (pushNamed, ...), the Navigator must be provided with an onGenerateRoute handler.
- Updated navigation to use GoRouter's context.push for study set screen.
- After selecting two lessons and creating the set, landed on a screen that showed the error message and lesson IDs:
  > snapshot.error.toString() and Lesson IDs: [b9..., 23...]

## In Progress
- Null safety and debug output added to Term.fromJson, Concept.fromJson, and Question.fromJson to prevent null assignment to non-nullable fields and diagnose issues.
- User is now testing the flow again after these model fixes.

### Previous Debug Output (for reference)
```
DEBUG: fetchStudySet called with lessonIds: [b9475fcb-6d78-44a8-b999-e99dd96d56db, 2343d6b6-fa98-485d-952b-2a3f9a1bd3df]
DEBUG: termsResponse: [{id: fda07434-62ff-4820-9cbf-7ccd6f1658e6, lesson_id: 2343d6b6-fa98-485d-952b-2a3f9a1bd3df, term: Widget, definition: The basic building block of Flutter UIs, example: Text, Container, and Row are all widgets, created_at: 2025-08-01T20:23:00.245+00:00, updated_at: 2025-08-01T20:23:00.245+00:00, user_id: 00000000-0000-0000-0000-000000000000}]
DEBUG: conceptsResponse: [{id: 365d44d3-a782-4b47-a443-e359c42bffaa, lesson_id: 2343d6b6-fa98-485d-952b-2a3f9a1bd3df, concept_text: State Management, example_text: How to manage state in Flutter apps, key_points: [], created_at: 2025-08-01T20:23:00.245+00:00, updated_at: 2025-08-01T20:23:00.245+00:00, user_id: 00000000-0000-0000-0000-000000000000}]
DEBUG: questionsResponse: [{id: 5a8c3fc8-0151-4a66-9a5c-a5ce49584f31, lesson_id: 2343d6b6-fa98-485d-952b-2a3f9a1bd3df, question_text: What is Flutter?, options: [A programming language, A UI toolkit, A database, A design pattern], correct_answer: 1, type: mcq, explanation: Flutter is Google's UI toolkit for building natively compiled applications., created_at: 2025-08-01T20:23:00.245+00:00, updated_at: 2025-08-01T20:23:00.245+00:00, user_id: 00000000-0000-0000-0000-000000000000}]
ERROR in StudySetService parsing: TypeError: null: type 'Null' is not a subtype of type 'String'
package:learning_pwa/models/term.dart 23:21 fromJson
package:learning_pwa/services/study_set_service.dart 33:61 <fn>
... (see console for full stack trace)
```

### Current Focus
- Await new debug output or error after user test to confirm if the parsing issue is resolved or if further model or data fixes are needed.

## Next Steps
- Analyze the new error message and stack trace (if any) shown on the Study Set screen to determine the root cause (query, data, or model issue).
- Use the lesson IDs and error details to further debug and fix the data loading problem in StudySetService or model parsing.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs