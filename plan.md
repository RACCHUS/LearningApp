# Learning PWA - Project Reference

## **Current Status: Safari Support Implementation Complete** 🍎
- **✅ COMPLETED**: Comprehensive Safari browser support implementation
- **Next Steps**: Test Safari compatibility across different versions and devices
- **See**: `SAFARI_SUPPORT_PLAN.md` for implementation details
- **Priority**: Browser testing and validation on physical Safari devices

## **Safari Support Features Implemented** 🍎

### **Phase 1: Safari Detection & Voice Input Enhancement** ✅
- **SafariCompatibilityService**: Enhanced browser detection with Safari-specific capabilities
- **SafariSpeechProvider**: Safari-optimized speech recognition with fallback handling
- **Safari Version Detection**: Automatic detection of Safari version and platform
- **Speech Recognition Support**: Version-based feature detection (Safari 16.4+ support)

### **Phase 2: User Experience Enhancements** ✅
- **SafariPermissionDialog**: Clear microphone permission instructions for Safari users
- **SafariAwareVoiceInput**: Adaptive voice input widget with manual fallback
- **Safari Audio Service**: User gesture-aware audio context management
- **Browser Status Display**: Real-time Safari capability indicators

### **Phase 3: PWA & Performance Optimizations** ✅
- **Safari Meta Tags**: Apple-specific PWA installation support
- **Enhanced Manifest**: Safari-compatible web app manifest
- **Service Worker Compatibility**: Safari-safe caching strategies
- **Touch Icon Support**: Proper Apple touch icon configuration

### **Phase 4: Testing & Integration** ✅
- **Comprehensive Test Suite**: Safari-specific functionality tests
- **Integration Widgets**: SafariSupportWidget for seamless integration
- **Diagnostic Tools**: Safari capability analysis and troubleshooting
- **Error Handling**: Safari-specific error messages and fallbacks 

## **Tech Stack**
- **Framework**: Flutter Web + Supabase + Riverpod
- **Database**: Supabase PostgreSQL (RLS disabled for development)
- **State Management**: Riverpod providers
- **Audio**: Web Speech API (TTS + Speech Recognition)
- **Navigation**: GoRouter with URL parameters

## **Critical Architecture Notes**

### **Database Structure**
- **Direct foreign keys**: `terms.lesson_id`, `questions.lesson_id`, `concepts.lesson_id`
- **No join tables** - Use individual queries for related data
- **Model Construction**: Manual object creation, NOT `.fromJson()` with Supabase responses

### **Authentication**
- **Guest Mode**: Starts as guest (UUID: `00000000-0000-0000-0000-000000000000`)
- **Google Sign-in**: Upgrades guest session when user authenticates
- **Session Persistence**: Maintains state across page reloads

### **Services Architecture** ✅ Recently Refactored
- **LessonService**: Facade pattern orchestrating specialized services
- **LessonCrudService**: Basic CRUD operations
- **LessonContentService**: Content management (terms, questions, concepts)
- **LessonImportService**: JSON import/export functionality

## **Critical Development Guidelines**

### **Flutter Commands**
- ✅ **Use**: VS Code tasks (Flutter: Run, Flutter: Build Web)
- ❌ **Don't Use**: `flutter run` commands (they fail in this setup)
- ⏱️ **Wait**: 10-15 seconds for commands to complete

### **Database Queries**
- ✅ **Use**: Individual queries for related data
- ❌ **Don't Use**: Complex joins or embedded relationships
- ✅ **Pattern**: Manual model construction from query results

### **Code Quality**
- **Large Files**: Refactor into smaller components before adding features
- **Error Handling**: Comprehensive null safety and defensive programming
- **Audio Features**: Always provide manual alternatives for accessibility

## **Known Working Features** ✅
- Lesson creation and management
- Study modes: Flashcards, MCQ, Concepts, Mixed, Lesson Mode
- Audio features: TTS and voice input (with Safari-specific optimizations)
- Offline support with Hive caching
- PWA capabilities and push notifications (Safari-compatible)
- Responsive design across devices
- **Safari Browser Support**: Complete compatibility layer for Safari 16.4+
- **Cross-Browser Voice Input**: Fallback providers for all major browsers
- **Safari PWA Installation**: Proper Apple touch icons and meta tags

## **Critical Fixes Applied** ✅
- **Service Decomposition**: lesson_service.dart split into specialized services
- **Widget Refactoring**: Large widgets broken into focused components
  - lesson_mode_screen.dart: 300+ lines → 50 lines (83% reduction)
  - lesson_content_pager.dart: Split into page_navigator_widget.dart and content_type_chip.dart
  - Question widgets: Extracted into separate mcq_question_widget.dart, true_false_question_widget.dart, short_answer_question_widget.dart
  - Content rendering: Centralized in lesson_content_renderer.dart
  - Voice input: Centralized in voice_input_handler.dart utility
- **Audio System**: Voice input null safety and error handling
- **Architecture**: Clean separation of concerns throughout codebase
- **Safari Support**: Complete browser compatibility layer
  - SafariCompatibilityService: Browser detection and feature analysis
  - SafariSpeechProvider: Safari-optimized speech recognition
  - SafariAudioService: User gesture-aware audio management
  - Safari-specific UI components and fallbacks

## **Quick Debug**
- **Compilation Issues**: `flutter clean && flutter pub get`
- **Runtime Errors**: Browser F12 console for detailed logs
- **Audio Issues**: Check browser permissions and Web Speech API support
