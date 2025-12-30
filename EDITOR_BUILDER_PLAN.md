# Lesson Editor & Course Builder Implementation Plan

## Overview
Build UI screens to create/edit lessons with mixed content types and organize lessons into courses (subjects).

---

## Phase 1: Lesson Editor

### 1.1 Create `LessonEditorScreen`
**File:** `lib/screens/lesson_editor_screen.dart`

**Features:**
- Create new lesson or edit existing
- Set title, description, tags
- Tabbed interface for content types: Terms | Questions | Concepts
- Floating action button to add content items
- Drag-to-reorder within each tab
- Save/publish button in app bar

**State Management:**
```dart
// lib/providers/lesson_editor_provider.dart
class LessonEditorState {
  final String? lessonId;  // null = new lesson
  final String title;
  final String? description;
  final List<String> tags;
  final List<Term> terms;
  final List<Question> questions;
  final List<Concept> concepts;
  final bool isDirty;
  final bool isSaving;
}
```

### 1.2 Content Item Editors (Bottom Sheets)

**Term Editor:** `lib/widgets/editors/term_editor_sheet.dart`
- Term text field
- Definition text field
- Optional example field
- Save/Cancel buttons

**Question Editor:** `lib/widgets/editors/question_editor_sheet.dart`
- Question type dropdown (multiple_choice, true_false, fill_in_blank)
- Question text field
- Dynamic options list (add/remove)
- Correct answer selector
- Optional explanation field

**Concept Editor:** `lib/widgets/editors/concept_editor_sheet.dart`
- Title field
- Content/explanation field (multiline)
- Optional key points list

### 1.3 Content List Tiles
**File:** `lib/widgets/editors/content_list_tile.dart`
- Reusable tile with drag handle, edit, delete
- Preview of content (truncated)
- Type indicator icon

---

## Phase 2: Course Builder

### 2.1 Create `CourseBuilderScreen`
**File:** `lib/screens/course_builder_screen.dart`

**Features:**
- Create new course or edit existing
- Set title, description, category, difficulty, image
- Section: "Lessons in this course" with drag-to-reorder
- Button to add lessons (opens lesson picker)
- Toggle required/optional per lesson
- Save/publish button

**State Management:**
```dart
// lib/providers/course_builder_provider.dart
class CourseBuilderState {
  final String? courseId;  // null = new course
  final String title;
  final String description;
  final String category;
  final String difficulty;
  final List<String> tags;
  final List<CourseLessonItem> lessons;  // with order, required flag
  final bool isDirty;
  final bool isSaving;
}
```

### 2.2 Lesson Picker Dialog
**File:** `lib/widgets/editors/lesson_picker_dialog.dart`
- Search/filter lessons
- Show lesson previews (title, content counts)
- Multi-select mode
- "Add Selected" button
- Option to create new lesson inline

### 2.3 Course Lesson Tile
**File:** `lib/widgets/editors/course_lesson_tile.dart`
- Drag handle for reordering
- Lesson title + content count preview
- Required/optional toggle
- Remove button
- Tap to preview/edit lesson

---

## Phase 3: Navigation & Integration

### 3.1 Entry Points
- Home screen: "Create Lesson" / "Create Course" buttons
- Lesson detail: "Edit" button in app bar
- Course detail: "Edit Course" button
- Long-press on lesson card → Edit option

### 3.2 Routes
```dart
// Add to router
'/lesson/new'           → LessonEditorScreen()
'/lesson/:id/edit'      → LessonEditorScreen(lessonId: id)
'/course/new'           → CourseBuilderScreen()
'/course/:id/edit'      → CourseBuilderScreen(courseId: id)
```

---

## File Structure
```
lib/
├── screens/
│   ├── lesson_editor_screen.dart
│   └── course_builder_screen.dart
├── providers/
│   ├── lesson_editor_provider.dart
│   └── course_builder_provider.dart
└── widgets/
    └── editors/
        ├── term_editor_sheet.dart
        ├── question_editor_sheet.dart
        ├── concept_editor_sheet.dart
        ├── content_list_tile.dart
        ├── lesson_picker_dialog.dart
        └── course_lesson_tile.dart
```

---

## Implementation Order

1. **Lesson Editor Provider** - State management first
2. **Content Editor Sheets** - Term, Question, Concept
3. **Content List Tile** - Reusable component
4. **Lesson Editor Screen** - Main screen assembly
5. **Course Builder Provider** - State management
6. **Lesson Picker Dialog** - For adding lessons to course
7. **Course Lesson Tile** - Reusable component
8. **Course Builder Screen** - Main screen assembly
9. **Navigation Integration** - Routes and entry points
10. **Tests** - Unit tests for providers

---

## Dependencies
- `flutter_reorderable_list` or built-in `ReorderableListView`
- Existing: `LessonService`, `CourseService`
- Existing: `Term`, `Question`, `Concept`, `Lesson`, `Course` models

---

## Validation Rules

**Lesson:**
- Title required (min 3 chars)
- At least 1 content item (term, question, or concept)

**Course:**
- Title required (min 3 chars)
- At least 1 lesson

---

## Success Criteria
- [x] Can create lesson with mixed terms, questions, concepts
- [x] Can edit existing lesson and add/remove content
- [x] Can reorder content within lesson
- [x] Can create course and add multiple lessons
- [x] Can reorder lessons within course
- [x] Can set lessons as required/optional
- [x] Changes prompt on back navigation (unsaved changes dialog)
- [x] All editors work on mobile and desktop
