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
UI/UX update: Improve the visual appearance of the app across all screens, making it look much better while maintaining or improving performance.

## Design Audit Findings
- Home Screen: Needs more whitespace, card elevation, consistent color palette, improved typography, and hover/focus effects for web.
- Lesson Page: Pager navigation is good, but should add transitions, bolder text, and better spacing. Use illustrations/icons for empty states.
- Set Creator UI: Missing search bar, needs better layout, tags as chips, and improved button styling.
- General: Use Material 3, Google Fonts, consistent spacing, and optimize for performance and responsiveness.

## Next Steps
1. Redesign the Home Page for a modern, beautiful, and performant look (colors, cards, typography, spacing, hover effects).
2. Redesign the Lesson Page for better readability, transitions, and visual hierarchy.
3. Redesign the Set Creator UI, add a search bar, and improve tag/filter UI.
4. Test all UI/UX improvements across browsers and devices for responsiveness and speed.

## Testing Plan
- For push notifications:
  - Firebase and FCM are integrated and initialized at startup.
  - Use test devices/browsers (Chrome, Edge) to verify push notification delivery at scheduled times.
  - Use Firebase Console to send test notifications.
- For in-app reminders:
  - Open the app in Safari/iOS and verify in-app reminders appear at scheduled times when the app is open.
- For settings:
  - Change notification times and theme, reload the app, and verify settings persist.
  - Disable notifications and verify no notifications are received.
- For Edge Functions:
  - Deploy a test function and trigger it manually to verify push notification delivery.

## Notes
- Push notifications are not supported on Safari/iOS via FCM; fallback to in-app reminders for those users.
- Supabase Edge Functions have a free tier suitable for most development and small production use cases.
- All notification and theme settings are stored per device/browser for simplicity.
- Notification delivery (push and in-app) remains untested as of now; testing will be performed after settings screen implementation.

## Quick Debug
- **Compilation**: `flutter clean && flutter pub get`
- **Browser Console**: F12 for runtime errors and debug logs