# Critical Refactoring Plan

## Executive Summary

Analysis of the codebase identified **10 files** exceeding professional standards (300+ lines for widgets, 400+ lines for services). These files exhibit **God Class** anti-patterns, violate **Single Responsibility Principle (SRP)**, and contain code that is difficult to test, maintain, and extend.

**Total Lines Requiring Refactoring:** ~7,500 lines  
**Estimated Effort:** 3-5 days  
**Risk Level:** Medium (incremental refactoring recommended)

---

## Priority Matrix

| Priority | File | Lines | Severity | Effort |
|----------|------|-------|----------|--------|
| 🔴 P1 | `screens/course_management_screen.dart` | 985 | Critical | High |
| 🔴 P1 | `widgets/enhanced_json_import_widget.dart` | 966 | Critical | High |
| 🔴 P1 | `widgets/content_quality_widget.dart` | 854 | Critical | Medium |
| 🟠 P2 | `services/content_quality_service.dart` | 775 | High | Medium |
| 🟠 P2 | `services/audio_lesson_orchestrator.dart` | 725 | High | Medium |
| 🟠 P2 | `services/global_voice_service.dart` | 612 | High | Medium |
| 🟠 P2 | `services/course_service.dart` | 607 | High | Low |
| 🟡 P3 | `services/lesson_template_service.dart` | 596 | Medium | Low |
| 🟡 P3 | `services/import_export_service.dart` | 577 | Medium | Low |
| 🟡 P3 | `services/hive_service.dart` | 472 | Medium | Low |

---

## Detailed Refactoring Specifications

### 1. 🔴 `course_management_screen.dart` (985 lines)

**Problem:** Contains 7 embedded classes (CourseCard, CreateCourseForm, CourseAnalyticsView, CourseDetailsScreen, EditCourseScreen, etc.) all in one file.

**Violations:**
- SRP: One file manages list view, card UI, form creation, analytics, and detail views
- God Class: Screen acts as both UI and partial business logic
- Testability: Cannot test individual components in isolation

**Refactoring Plan:**

```
lib/screens/course_management/
├── course_management_screen.dart       # ~80 lines - Main screen with TabBar
├── widgets/
│   ├── course_card.dart                # ~120 lines - Individual course card
│   ├── course_list_view.dart           # ~80 lines - Course list with RefreshIndicator
│   └── course_analytics_chart.dart     # ~100 lines - Analytics visualization
├── forms/
│   ├── create_course_form.dart         # ~200 lines - Course creation form
│   └── edit_course_form.dart           # ~180 lines - Course editing form
└── views/
    ├── courses_tab.dart                # ~60 lines - Courses tab content
    ├── analytics_tab.dart              # ~80 lines - Analytics tab content
    └── course_details_screen.dart      # ~150 lines - Full course details
```

**Implementation Steps:**
1. Extract `CourseCard` widget to separate file
2. Extract `CreateCourseForm` to forms directory
3. Extract `CourseAnalyticsView` to views directory
4. Create barrel file for exports
5. Update imports in main screen

---

### 2. 🔴 `enhanced_json_import_widget.dart` (966 lines)

**Problem:** Monolithic widget handling JSON editing, validation, preview, quality analysis, and recent imports management.

**Violations:**
- SRP: Single widget does parsing, validation, preview generation, history management
- Complexity: 25+ private methods with mixed concerns
- State Management: Local state managing multiple unrelated concerns

**Refactoring Plan:**

```
lib/widgets/json_import/
├── enhanced_json_import_widget.dart    # ~100 lines - Main container with tabs
├── editors/
│   ├── json_editor_panel.dart          # ~150 lines - Code editor with line numbers
│   └── json_toolbar.dart               # ~80 lines - Editor toolbar buttons
├── validation/
│   ├── json_validation_panel.dart      # ~120 lines - Validation results display
│   ├── json_validator.dart             # ~100 lines - Core validation logic (move from utils)
│   └── validation_suggestions.dart     # ~60 lines - Suggestion display widgets
├── preview/
│   ├── lesson_preview_panel.dart       # ~100 lines - Live lesson preview
│   └── preview_stats_card.dart         # ~50 lines - Preview statistics
└── history/
    ├── import_history_manager.dart     # ~80 lines - History persistence
    └── recent_imports_menu.dart        # ~60 lines - Recent imports popup
```

**Implementation Steps:**
1. Extract validation logic to dedicated validator class
2. Create `JsonEditorPanel` with toolbar
3. Extract `JsonValidationPanel` for error/warning display
4. Create `LessonPreviewPanel` for preview tab
5. Move history management to separate manager class

---

### 3. 🔴 `content_quality_widget.dart` (854 lines)

**Problem:** Widget contains 5 full tab implementations with complex scoring visualizations.

**Violations:**
- SRP: Handles overview, readability, accessibility, structure, and suggestions
- UI Complexity: Deeply nested widget trees
- Reusability: Score displays duplicated across tabs

**Refactoring Plan:**

```
lib/widgets/content_quality/
├── content_quality_widget.dart         # ~100 lines - Main container with TabBar
├── tabs/
│   ├── overview_tab.dart               # ~120 lines
│   ├── readability_tab.dart            # ~120 lines
│   ├── accessibility_tab.dart          # ~120 lines
│   ├── structure_tab.dart              # ~100 lines
│   └── suggestions_tab.dart            # ~100 lines
├── components/
│   ├── quality_score_header.dart       # ~80 lines - Overall score display
│   ├── score_circle_indicator.dart     # ~40 lines - Reusable circular score
│   ├── metric_card.dart                # ~50 lines - Individual metric display
│   └── issue_list_tile.dart            # ~40 lines - Accessibility issue item
└── models/
    └── quality_display_models.dart     # ~60 lines - UI-specific view models
```

**Implementation Steps:**
1. Extract `QualityScoreHeader` as reusable component
2. Create individual tab widgets
3. Extract reusable `MetricCard` and `ScoreCircleIndicator`
4. Create view models to simplify data passing

---

### 4. 🟠 `content_quality_service.dart` (775 lines)

**Problem:** Single service handles readability analysis, accessibility checks, terminology consistency, structure analysis, and suggestion generation.

**Violations:**
- SRP: One class does 5+ distinct analysis types
- Testability: Cannot test readability without loading entire service
- Extensibility: Adding new analysis types requires modifying monolith

**Refactoring Plan:**

```
lib/services/content_quality/
├── content_quality_service.dart        # ~80 lines - Facade coordinating analyzers
├── analyzers/
│   ├── readability_analyzer.dart       # ~150 lines - Flesch-Kincaid, sentence analysis
│   ├── accessibility_analyzer.dart     # ~120 lines - WCAG compliance checks
│   ├── structure_analyzer.dart         # ~100 lines - Content type distribution
│   └── terminology_analyzer.dart       # ~80 lines - Consistency checking
├── generators/
│   └── suggestion_generator.dart       # ~100 lines - Improvement suggestions
└── models/
    └── quality_models.dart             # ~150 lines - Report data classes
```

**Implementation Steps:**
1. Extract text analysis utilities to `readability_analyzer.dart`
2. Move accessibility checks to dedicated analyzer
3. Create `SuggestionGenerator` for all suggestion logic
4. Update service to delegate to analyzers (Facade pattern)

---

### 5. 🟠 `audio_lesson_orchestrator.dart` (725 lines)

**Problem:** Orchestrator manages state, audio playback, voice commands, content processing, and progress tracking.

**Violations:**
- SRP: Mixed orchestration with direct service calls
- State Complexity: Multiple stream controllers with interleaved logic
- Error Handling: Try-catch blocks scattered throughout

**Refactoring Plan:**

```
lib/services/audio_lesson/
├── audio_lesson_orchestrator.dart      # ~150 lines - High-level orchestration only
├── state/
│   ├── audio_lesson_state_machine.dart # ~100 lines - State transitions
│   └── lesson_progress_tracker.dart    # ~80 lines - Progress stream management
├── handlers/
│   ├── content_playback_handler.dart   # ~120 lines - Audio playback logic
│   ├── voice_command_handler.dart      # ~100 lines - Voice command processing
│   └── navigation_handler.dart         # ~80 lines - Next/previous/repeat
└── utils/
    └── audio_lesson_utils.dart         # ~60 lines - Shared utilities
```

**Implementation Steps:**
1. Extract state machine for cleaner state transitions
2. Create `ContentPlaybackHandler` for TTS interactions
3. Extract `VoiceCommandHandler` for command processing
4. Simplify orchestrator to coordinate handlers

---

### 6. 🟠 `global_voice_service.dart` (612 lines)

**Problem:** Service handles voice recognition, command routing, phrase accumulation, navigation, and confirmation dialogs.

**Violations:**
- SRP: Mixes voice capture with command routing and UI concerns
- Coupling: Direct router and context dependencies
- Testability: Cannot test command parsing without full service

**Refactoring Plan:**

```
lib/services/voice/
├── global_voice_service.dart           # ~100 lines - Service facade
├── recognition/
│   ├── voice_recognizer.dart           # ~100 lines - Speech recognition wrapper
│   └── phrase_accumulator.dart         # ~80 lines - Multi-word phrase handling
├── routing/
│   ├── voice_command_router.dart       # ~120 lines - Command to action mapping
│   └── navigation_handler.dart         # ~80 lines - Route navigation
└── ui/
    └── voice_confirmation_manager.dart # ~80 lines - Confirmation dialog handling
```

**Implementation Steps:**
1. Extract `PhraseAccumulator` for multi-word command handling
2. Create `VoiceCommandRouter` for command→action mapping
3. Move navigation logic to dedicated handler
4. Separate UI concerns (confirmation dialogs)

---

### 7. 🟠 `course_service.dart` (607 lines)

**Problem:** Static service with 300+ lines of mock data mixed with business logic.

**Violations:**
- SRP: Business logic mixed with mock/test data
- Maintainability: Mock data obscures actual service methods
- Real Implementation: Will require significant changes when connecting to backend

**Refactoring Plan:**

```
lib/services/course/
├── course_service.dart                 # ~150 lines - Public API facade
├── course_repository.dart              # ~100 lines - Data access abstraction
├── course_validators.dart              # ~60 lines - Validation logic
└── mock/
    └── mock_course_data.dart           # ~300 lines - All mock data (dev only)
```

**Implementation Steps:**
1. Extract mock data to separate file (conditionally loaded)
2. Create repository interface for future backend integration
3. Move validation to dedicated class
4. Keep service as thin facade

---

### 8. 🟡 `lesson_template_service.dart` (596 lines)

**Problem:** Service contains template definitions inline, making it 80% data and 20% logic.

**Violations:**
- Data vs Logic: Templates should be external (JSON/YAML)
- Maintainability: Non-technical users cannot modify templates
- i18n: No support for localized templates

**Refactoring Plan:**

```
lib/services/templates/
├── lesson_template_service.dart        # ~100 lines - Template loading and selection
├── template_loader.dart                # ~60 lines - Load from assets
└── template_validator.dart             # ~40 lines - Validate template structure

assets/templates/
├── programming/
│   ├── language_intro.json
│   └── data_structures.json
├── it/
│   └── networking.json
└── general/
    └── basic_intro.json
```

**Implementation Steps:**
1. Convert template definitions to JSON files in assets
2. Create template loader to read from assets
3. Add template caching for performance
4. Keep service as thin orchestration layer

---

### 9. 🟡 `import_export_service.dart` (577 lines)

**Problem:** Service handles import, export, backup, restore, history, and favorites—too many responsibilities.

**Violations:**
- SRP: 6+ distinct operations in one file
- Format Coupling: All export formats in one class
- History/Favorites: Should be separate persistence concern

**Refactoring Plan:**

```
lib/services/import_export/
├── import_export_service.dart          # ~80 lines - Public facade
├── importers/
│   ├── json_importer.dart              # ~80 lines
│   ├── csv_importer.dart               # ~80 lines
│   └── bulk_importer.dart              # ~60 lines
├── exporters/
│   ├── json_exporter.dart              # ~60 lines
│   ├── markdown_exporter.dart          # ~80 lines
│   └── pdf_exporter.dart               # ~60 lines (placeholder)
├── backup/
│   └── backup_service.dart             # ~100 lines - Backup/restore
└── history/
    └── import_history_service.dart     # ~60 lines - History persistence
```

---

### 10. 🟡 `hive_service.dart` (472 lines)

**Problem:** Single service manages all Hive box operations for 6+ entity types.

**Violations:**
- SRP: One class for lessons, progress, settings, local lessons, etc.
- Cohesion: Unrelated operations grouped together
- Scaling: Adding new entities requires modifying monolith

**Refactoring Plan:**

```
lib/services/storage/
├── hive_service.dart                   # ~50 lines - Initialization and box management
├── repositories/
│   ├── lesson_repository.dart          # ~80 lines - Lesson CRUD
│   ├── local_lesson_repository.dart    # ~60 lines - Local lesson operations
│   ├── progress_repository.dart        # ~80 lines - User progress
│   └── settings_repository.dart        # ~50 lines - App settings
└── adapters/
    └── hive_adapters.dart              # ~40 lines - Adapter registration
```

**Implementation Steps:**
1. Create repository interface per entity type
2. Move operations to respective repositories
3. Keep HiveService for initialization only
4. Update providers to inject repositories

---

## Implementation Order

### Phase 1: Foundation (Day 1)
1. Create directory structures
2. Extract `content_quality_service.dart` analyzers (lowest risk, well-isolated)
3. Extract `course_service.dart` mock data

### Phase 2: Services (Day 2)
4. Refactor `audio_lesson_orchestrator.dart`
5. Refactor `global_voice_service.dart`
6. Refactor `import_export_service.dart`

### Phase 3: UI Components (Days 3-4)
7. Refactor `enhanced_json_import_widget.dart`
8. Refactor `content_quality_widget.dart`
9. Refactor `course_management_screen.dart`

### Phase 4: Storage & Templates (Day 5)
10. Refactor `hive_service.dart` into repositories
11. Externalize `lesson_template_service.dart` templates

---

## Testing Strategy

For each refactored component:
1. **Unit Tests:** Test extracted classes in isolation
2. **Integration Tests:** Verify facade still coordinates correctly
3. **Widget Tests:** For UI extractions, test rendered output
4. **Regression Tests:** Run existing test suite after each phase

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Breaking existing functionality | Incremental extraction with barrel file exports |
| Import path changes | Use barrel files to maintain stable API |
| State management changes | Keep stream controllers in original locations initially |
| Performance regression | Profile before/after each phase |

---

## Success Metrics

- [ ] No file exceeds 300 lines (widgets) or 400 lines (services)
- [ ] Each class has single, clear responsibility
- [ ] Test coverage increases by 20%+
- [ ] New features can be added without modifying existing classes
- [ ] Code review time reduced by clearer file boundaries
