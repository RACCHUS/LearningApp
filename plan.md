# Learning PWA Technical Reference

## Project Configuration
- **Framework**: Flutter Web
- **Backend**: Supabase
- **State Management**: Riverpod
- **Authentication**: Supabase Auth
- **Offline Support**: Hive + IndexedDB

## Known Issues & Solutions

### HiveService Initialization
- **Problem**: LateInitializationError when multiple instances created
- **Solution**: Use global singleton pattern in main.dart
- **Implementation**: All providers reference the same HiveService instance

### Navigation System
- **Current**: Simple MaterialApp navigation
- **Note**: GoRouter removed to prevent context errors
- **Workaround**: Navigation buttons show SnackBar messages

### Data Handling
- **Supabase**: Comprehensive try-catch blocks for null handling
- **Offline**: Graceful fallback to empty lists on errors
- **Pattern**: Individual error handling for online/offline data fetching

### Deprecated APIs (Non-critical)
- `withOpacity()` → `withValues()`
- `surfaceVariant` → `surfaceContainerHighest`
- `androidAllowWhileIdle` parameter updates

## Architecture Components
- **Content System**: BaseLesson → Lesson hierarchy
  - Content types: TermContent, QuestionContent, ConceptContent, TextContent
- **Key Services**: 
  - HiveService (singleton pattern)
  - LessonService 
  - ProgressSyncService
  - LessonCreationService
- **Main Screens**: 
  - create_lesson_screen.dart (modular design, 170 lines)
  - home_screen.dart (SnackBar navigation)
- **Testing**: Mockito-based unit tests

## Feature Development Plan

### Lesson Creation System
**Phase 1: JSON Import Lesson Creation**
- **Import Interface**: Text field for JSON input with validation
- **JSON Schema**: Support for lesson metadata, content blocks, and questions
- **Validation**: Real-time JSON syntax and schema validation
- **Preview**: Show parsed lesson structure before saving
- **Storage**: Save to both Hive (offline) and Supabase (online sync)

**Phase 2: User-Friendly Lesson Builder**
- **Step-by-Step Wizard**: Multi-step lesson creation process
- **Content Blocks**: Add/remove/reorder different content types
  - Text blocks with rich formatting
  - Term definitions with explanations
  - Multiple choice questions with feedback
  - Concept explanations with examples
- **Live Preview**: Real-time preview of lesson as it's built
- **Templates**: Pre-defined lesson structures for quick start
- **Drag & Drop**: Intuitive content reordering interface

**JSON Schema Structure**:
```json
{
  "title": "string",
  "description": "string", 
  "category": "string",
  "difficulty": "beginner|intermediate|advanced",
  "estimatedDuration": "number (minutes)",
  "content": [
    {
      "type": "text|term|question|concept",
      "id": "string",
      "data": { /* type-specific content */ }
    }
  ]
}
```

## Implementation Status

### ✅ **Lesson Creation Feature - COMPLETED**
**Phase 1: JSON Import Lesson Creation**
- ✅ **Import Interface**: Text field for JSON input with comprehensive validation
- ✅ **JSON Schema Validator**: Real-time syntax and schema validation with detailed error messages
- ✅ **Preview System**: Live preview showing parsed lesson structure before saving
- ✅ **Storage Integration**: Saves to both Hive (offline) and Supabase (online sync)

**Phase 2: User-Friendly Lesson Builder**
- ✅ **Multi-tab Interface**: Separate tabs for Terms, Questions, and Concepts
- ✅ **Content Creation Forms**: Dedicated forms for each content type with validation
- ✅ **Content Management**: Add/remove/reorder content items with drag & drop
- ✅ **Live Content List**: Real-time display of added content with preview
- ✅ **Navigation Integration**: Seamlessly integrated with home screen

### 🔧 **Bug Fixes Applied**
- ✅ **JSON Import Structure**: Fixed `importLessonFromJson` to handle nested `{lesson, content}` structure
- ✅ **Null Safety**: Enhanced null handling in `getLessonsForUser` method
- ✅ **Content Types**: Added TextContent import and proper type handling
- ✅ **Error Handling**: Return empty lists instead of throwing exceptions

### 🗄️ **Database Schema Fixes Applied**
- ✅ **Lessons Table**: Changed `created_by` → `user_id` (nullable), added `updated_at` field
- ✅ **Terms Table**: Added `lesson_id`, `created_at`, `updated_at` fields, made `created_by` nullable
- ✅ **Questions Table**: Added `lesson_id`, `created_at`, `updated_at` fields, made `created_by` nullable  
- ✅ **Concepts Table**: Added `lesson_id`, `created_at`, `updated_at`, `key_points` fields, made `created_by` nullable
- ✅ **Junction Tables**: Removed unnecessary `lesson_terms`, `lesson_questions`, `lesson_concepts`
- ✅ **RLS Policies**: Updated to handle optional `user_id` (supports public lessons)
- ✅ **Indexes**: Added performance indexes for `lesson_id` foreign keys
- ✅ **Flexibility**: Optional `user_id` allows both owned and public/shared lessons

### ❌ **Previous Issues - FIXED**
- ✅ **Supabase 404 Error**: Fixed by updating schema to match service expectations
  - **Root Cause**: Schema had `created_by` field but service expected `user_id`
  - **Solution**: Updated schema.sql with correct field names and missing fields
- ✅ **Null Iteration Error**: Fixed by adding missing `updated_at` fields  
  - **Root Cause**: Service expected `updated_at` field that didn't exist in schema
  - **Solution**: Added `updated_at` to all content tables with proper defaults

**Files Created/Modified:**
- `lib/screens/lessons/create_lesson_screen.dart` - Main lesson creation interface
- `lib/widgets/lesson_json_import_widget.dart` - JSON import with validation
- `lib/widgets/lesson_builder_widget.dart` - User-friendly lesson builder
- `lib/utils/lesson_json_validator.dart` - Comprehensive JSON validation
- `lib/screens/home_screen.dart` - Updated navigation to lesson creation
- `schema.sql` - **CRITICAL**: Updated database schema to match service expectations

## Common Troubleshooting
1. **Compilation Errors**: Run `flutter clean && flutter pub get`
2. **Hive Issues**: Ensure singleton HiveService initialization in main.dart
3. **Navigation**: Use SnackBar messages instead of router navigation
4. **Data Sync**: Check try-catch blocks in providers for Supabase calls
5. **⚠️ CRITICAL WORKFLOW ISSUE**: Always wait for terminal command outputs before proceeding
   - **Problem**: Repeatedly not waiting for `flutter analyze` outputs
   - **Impact**: Missing critical compilation errors and warnings
   - **Solution**: Use `get_terminal_output` and wait for results before making assumptions
   - **Required for**: `flutter analyze`, `flutter test`, `flutter build`, all diagnostic commands
