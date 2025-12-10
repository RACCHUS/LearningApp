# Test Coverage Plan

**Current Status**: 358 tests passing (100% pass rate)

## Critical Gaps (Priority 1) - Core Business Logic

### 1. Provider Tests (State Management) - **CRITICAL**
**Missing Coverage**: 15+ providers with NO tests

#### High Priority Providers:
- [ ] `LessonCreationProvider` (lesson_creation_provider.dart)
  - State: title, description, tags, content, isLoading, error
  - Methods: updateTitle, updateDescription, addTag, removeTag, addContent, removeContent, updateContent, reset
  - **Why Critical**: Core lesson creation workflow - untested state transitions

- [ ] `StudyProvider` (study_provider.dart)  
  - State: currentLesson, currentMode, currentContent, currentIndex, completedLessons, reminders
  - Methods: selectLesson, setMode, next, previous, markLessonAsCompleted, addReminder, cancelReminder
  - **Why Critical**: Primary study session management - user progress tracking

- [ ] `ProgressProvider` (progress_provider.dart)
  - State: ProgressInitial, ProgressLoading, ProgressLoaded, ProgressError
  - Methods: startLesson, recordProgress, syncProgress  
  - **Why Critical**: User progress persistence and sync - data integrity risk

- [ ] `GlobalVoiceProvider` (global_voice_provider.dart)
  - State: isListening, lastCommand, error
  - Methods: startListening, stopListening, handleCommand, navigateToRoute
  - **Why Critical**: Global navigation and voice command handling

- [ ] `HandsFreeSettingsProvider` (hands_free_settings_provider.dart)
  - State: HandsFreeSettings with 8+ configuration options
  - Methods: toggleHandsFree, setConfidenceThreshold, setVoiceTimeout, etc.
  - **Why Critical**: Accessibility feature configuration

- [ ] `ConnectivityProvider` (connectivity_provider.dart)
  - State: boolean (isConnected)
  - Methods: Stream subscription management
  - **Why Critical**: Offline/online state management for sync operations

- [ ] `EnhancedAudioProvider` (enhanced_audio_provider.dart)
  - Complex audio state with playback, recording, voice commands
  - **Why Critical**: Core audio lesson feature

#### Medium Priority Providers:
- [ ] `ReminderProvider` (reminder_provider.dart) - User engagement
- [ ] `AppInitializationProvider` (app_initialization_provider.dart) - Startup sequence
- [ ] `RouterProvider` (router_provider.dart) - Navigation state

### 2. Service Layer Tests - **CRITICAL**

#### Untested Services:
- [ ] `AudioService` (audio_service.dart)
  - Text-to-speech, playback control, language support
  - **Why Critical**: Core audio functionality used throughout app

- [ ] `EnhancedVoiceInputService` (enhanced_voice_input_service.dart)
  - Speech recognition, phrase accumulation, command parsing
  - **Why Critical**: Voice input for hands-free mode

- [ ] `VoiceCommandParser` (voice_command_parser.dart)
  - Command pattern matching, intent extraction
  - **Why Critical**: Voice command interpretation accuracy

- [ ] `ContentQualityService` (content_quality_service.dart) - **HAS TESTS** (1 test)
  - Need comprehensive coverage: readability, accessibility, structure analysis
  - Currently only tests basic quality scoring

- [ ] `LessonService` (lesson_service.dart)
  - CRUD operations, lesson loading, filtering
  - **Why Critical**: Core lesson data management

- [ ] `ProgressService` (progress_service.dart)
  - Analytics, streaks, achievements, deadlines
  - **Why Critical**: User progress tracking and gamification

- [ ] `LocalLessonService` (local_lesson_service.dart)
  - Offline lesson storage and retrieval
  - **Why Critical**: Offline functionality

- [ ] `DataSyncService` (data_sync_service.dart)
  - Bi-directional sync between local and remote
  - **Why Critical**: Data consistency

- [ ] `ImportExportService` (import_export_service.dart)
  - JSON import/export, bulk operations, backup/restore
  - **Why Critical**: Data portability and backup

- [ ] `LessonCreationService` (lesson_creation_service.dart)
  - Lesson creation validation and persistence
  - **Why Critical**: Content creation workflow

- [ ] `GlobalVoiceService` (global_voice_service.dart)
  - Global voice command handling
  - **Why Critical**: Navigation via voice

- [ ] `SafariAudioService` (safari_audio_service.dart)
  - Safari-specific audio workarounds
  - **Why Critical**: Browser compatibility

- [ ] `ConnectivityService` (connectivity_service.dart)
  - Network status monitoring
  - **Why Critical**: Offline/online transitions

- [ ] `NotificationService` (notification_service.dart)
  - PWA notification scheduling
  - **Why Critical**: User engagement and reminders

### 3. Model Tests - **MEDIUM PRIORITY**

**Current Coverage**: Basic model tests exist (model_test.dart)

#### Missing Model Tests:
- [ ] `Lesson` model - Full serialization/deserialization with all content types
- [ ] `LessonContent` subtypes - TermContent, QuestionContent, ConceptContent
- [ ] `AudioSettings` - More edge cases beyond current tests
- [ ] `AudioLessonSettings` - Validation and defaults
- [ ] `HandsFreeSettings` - Configuration validation
- [ ] `Reminder` - Scheduling logic
- [ ] `Course` models - Full course structure
- [ ] `LocalLesson` - Offline storage format

### 4. Utility Tests - **MEDIUM PRIORITY**

- [ ] `VoiceCommandRouter` - **HAS TESTS** but needs edge cases
  - Additional test scenarios: ambiguous commands, multi-word answers
  
- [ ] `VoiceCommandCorrector` (voice_command_corrector.dart)
  - Fuzzy matching, suggestion ranking
  
- [ ] `VoiceInputHandler` (voice_input_handler.dart)
  - Input debouncing, command buffering

- [ ] `MathUtils` (math_utils.dart) - Statistical functions

## Priority 2 - Widget Tests

### Critical Widget Coverage Gaps:

- [ ] **Study Widgets** (highest user interaction)
  - `McqContent` - Answer selection, feedback, voice input
  - `FlashcardContent` - Flip animation, reveal/hide
  - `ConceptContent` - Reading flow
  - `StudyContentRouter` - Content type switching

- [ ] **Audio Widgets**
  - `AudioMCQWidget` - Voice answer handling
  - `AudioFlashcardWidget` - Audio flashcard flow
  - `AudioConceptWidget` - Concept reading
  - `HandsFreeIndicator` - Status display
  - `AudioControlWidget` - Playback controls

- [ ] **Lesson Creation Widgets**
  - `LessonBuilderWidget` - Content editing flow
  - `ContentCreationWidget` - Form validation
  - `McqContentForm` - Option management
  - `ContentPreviewList` - Content ordering

- [ ] **Voice Widgets**
  - `VoiceCommandConfirmationDialog` - User confirmation flow
  - `GlobalVoiceIndicator` - Status visualization
  - `SafariAwareVoiceInput` - Browser-specific handling

- [ ] **Progress Widgets**
  - `ProgressStatsOverview` - Data display
  - `SyncStatusIndicator` - Sync state visualization

**Current Widget Coverage**: 2 tests (EmptyState, CategoryChip)
**Target**: 30+ widget tests for critical user flows

## Priority 3 - Integration Tests

### Critical Integration Scenarios:

- [ ] **End-to-End Study Session**
  - Start lesson → Answer questions → Complete → Save progress → Sync
  
- [ ] **Offline → Online Sync**
  - Study offline → Track progress → Go online → Verify sync
  
- [ ] **Voice Command Flow**
  - Enable hands-free → Issue commands → Navigate → Answer questions
  
- [ ] **Lesson Creation Flow**
  - Create lesson → Add content → Save → Load → Verify

- [ ] **Audio Lesson Flow**
  - Start audio lesson → Listen → Voice commands → Progress tracking

## Priority 4 - Browser Compatibility Tests

- [ ] `SafariCompatibilityService` - Safari-specific features
- [ ] `BrowserCompatibilityService` - Cross-browser detection
- [ ] Safari audio playback edge cases
- [ ] PWA installation and service worker behavior

## Implementation Plan

### Phase 1 (Week 1) - Core Providers
**Target**: 100+ new tests

1. LessonCreationProvider (15 tests)
2. StudyProvider (20 tests)
3. ProgressProvider (15 tests)
4. GlobalVoiceProvider (12 tests)
5. HandsFreeSettingsProvider (10 tests)
6. ConnectivityProvider (8 tests)
7. EnhancedAudioProvider (25 tests)

**Approach**:
- Mock Supabase client in all tests
- Use ProviderContainer for isolated testing
- Test state transitions and side effects
- Verify error handling

### Phase 2 (Week 2) - Core Services
**Target**: 80+ new tests

1. AudioService (15 tests)
2. EnhancedVoiceInputService (20 tests)
3. VoiceCommandParser (15 tests)
4. LessonService (15 tests)
5. ProgressService (15 tests)

**Approach**:
- Mock external dependencies (Supabase, Hive, platform channels)
- Test edge cases and error conditions
- Verify state management integration

### Phase 3 (Week 3) - Widgets
**Target**: 50+ new tests

1. Study widgets (20 tests)
2. Audio widgets (15 tests)
3. Lesson creation widgets (10 tests)
4. Voice widgets (5 tests)

**Approach**:
- Use `ProviderScope` with overrides
- Test user interactions with `tester.tap()`, `tester.enterText()`
- Verify UI state updates
- Test accessibility

### Phase 4 (Week 4) - Integration & Polish
**Target**: 20+ new tests

1. End-to-end flows (10 tests)
2. Browser compatibility (5 tests)
3. Edge cases and regressions (5 tests)

## Testing Standards

### Test Structure:
```dart
group('ComponentName', () {
  late MockDependency mockDep;
  late ServiceUnderTest service;
  
  setUp(() {
    mockDep = MockDependency();
    service = ServiceUnderTest(mockDep);
  });
  
  tearDown(() {
    // Cleanup
  });
  
  group('methodName', () {
    test('should handle success case', () {
      // Arrange
      when(mockDep.method()).thenAnswer((_) async => result);
      
      // Act
      final result = await service.method();
      
      // Assert
      expect(result, expected);
      verify(mockDep.method()).called(1);
    });
    
    test('should handle error case', () {
      // Test error handling
    });
  });
});
```

### Coverage Targets:
- **Providers**: 90%+ line coverage
- **Services**: 85%+ line coverage  
- **Models**: 95%+ line coverage
- **Widgets**: 70%+ line coverage (focus on logic)
- **Overall Goal**: 80%+ line coverage

## Test File Organization

```
test/
├── providers/
│   ├── lesson_creation_provider_test.dart
│   ├── study_provider_test.dart
│   ├── progress_provider_test.dart
│   ├── global_voice_provider_test.dart
│   └── ... (15+ provider tests)
├── services/
│   ├── audio_service_test.dart
│   ├── voice_input_service_test.dart
│   ├── lesson_service_test.dart
│   └── ... (15+ service tests)
├── models/
│   └── ... (existing + additional model tests)
├── widgets/
│   ├── study/
│   │   ├── mcq_content_test.dart
│   │   └── flashcard_content_test.dart
│   ├── audio/
│   │   └── audio_control_widget_test.dart
│   └── ... (30+ widget tests)
├── integration/
│   ├── study_session_flow_test.dart
│   ├── offline_sync_flow_test.dart
│   └── voice_command_flow_test.dart
└── utils/
    └── ... (utility tests)
```

## Metrics to Track

- Test count: 358 → 600+ (target)
- Line coverage: Unknown → 80%+
- Provider coverage: ~10% → 90%+
- Service coverage: ~5% → 85%+
- Widget coverage: <5% → 70%+
- Test execution time: Monitor and keep under 2 minutes

## Success Criteria

✅ All critical providers have comprehensive tests  
✅ Core services have 85%+ coverage  
✅ Main user flows covered by integration tests  
✅ No regressions in existing 358 passing tests  
✅ CI/CD pipeline runs all tests successfully  
✅ Test suite completes in under 2 minutes
