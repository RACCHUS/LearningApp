# Learning PWA - Project Reference

## **Current Status: Major Refactoring Complete ✅**
- **Next Steps**: 

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
- Audio features: TTS and voice input (with fallbacks)
- Offline support with Hive caching
- PWA capabilities and push notifications
- Responsive design across devices

## **Critical Fixes Applied** ✅
- **Service Decomposition**: lesson_service.dart split into specialized services
- **Widget Refactoring**: Large widgets broken into focused components
- **Audio System**: Voice input null safety and error handling
- **Architecture**: Clean separation of concerns throughout codebase

## **Quick Debug**
- **Compilation Issues**: `flutter clean && flutter pub get`
- **Runtime Errors**: Browser F12 console for detailed logs
- **Audio Issues**: Check browser permissions and Web Speech API support
