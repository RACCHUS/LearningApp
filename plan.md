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
- JSON lesson import with field mapping (title→concept_text, question→question_text, etc.)
- GoRouter navigation with deep linking
- Database CRUD operations via direct foreign key relationships
- Guest user support (UUID: 00000000-0000-0000-0000-000000000000)

## Critical Fix Reference
**Lesson Loading Error Fix**: Never use Lesson.fromJson() with Supabase responses - create Lesson objects manually since Supabase doesn't return embedded content arrays.
