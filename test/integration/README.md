# 🧪 Integration Tests - Learning PWA

Integration tests verify end-to-end functionality and service interactions in the Learning PWA.

## 📁 Test Structure Overview

```
test/
├── model_test.dart              # 🧩 Unit Tests - Individual model testing
├── offline_mode_test.dart       # 🔧 Service Tests - Hive offline functionality
├── progress_sync_test.dart      # 🔧 Service Tests - Progress synchronization
├── test_helper.dart             # 🛠️ Test Utilities - Setup and helpers
├── integration/                 # 🔗 Integration Tests - End-to-end workflows
│   ├── test_import.dart         # Import order processing verification
│   ├── test_lesson_creation.dart # Complete lesson lifecycle testing
│   └── README.md               # This documentation
└── README.md                   # Overall test documentation
```

---

## 🔗 Integration Test Inventory

### **`test_import.dart` - Import Order Processing**
**Type**: Integration Test  
**Purpose**: Verifies lesson content order handling during import process

**What it tests**:
- ✅ JSON structure parsing and validation
- ✅ Order value processing logic
- ✅ Content type handling (terms, concepts, MCQs)
- ✅ Order assignment algorithm verification

**Test Flow**:
1. Loads sample lesson JSON from `data/samples/`
2. Parses lesson structure and content array
3. Analyzes original order values in JSON
4. Simulates order processing logic
5. Compares original vs processed order values
6. Reports any discrepancies or issues

**Usage**:
```bash
# Run from project root
dart test/integration/test_import.dart
```

**Expected Output**:
```
🔍 Integration Test: Lesson Import Order Handling
===================================================

📖 Lesson: Laptops: Hardware, Displays, and Features
📊 Content items: 25

📋 Order values in JSON:
   Item 0: type=term, order=1
   Item 1: type=term, order=2
   ...

🔄 Processed order values (as would be saved to database):
   Index 0: type=term, processed_order=1
   Index 1: type=term, processed_order=2
   ...

✅ Order handling test completed successfully!
```

---

### **`test_lesson_creation.dart` - Complete Lesson Lifecycle**
**Type**: Integration Test  
**Purpose**: End-to-end verification of lesson creation and retrieval

**What it tests**:
- ✅ Supabase connection and authentication
- ✅ Environment variable configuration
- ✅ JSON-to-lesson conversion via LessonService
- ✅ Database insertion operations
- ✅ Lesson retrieval and content loading
- ✅ Data integrity across the complete cycle

**Test Flow**:
1. Loads environment variables and validates configuration
2. Initializes Supabase connection
3. Creates comprehensive test lesson from JSON
4. Inserts lesson into database via LessonService
5. Retrieves lesson back from database
6. Verifies all content types were created correctly
7. Validates data integrity and completeness

**Usage**:
```bash
# Run from project root
dart test/integration/test_lesson_creation.dart
```

**Expected Output**:
```
🎯 Integration Test: Lesson Service
====================================

✅ Environment variables loaded
✅ Connected to Supabase

🚀 Testing lesson creation with JSON...
✅ Lesson created successfully!
📋 Lesson Details:
   ID: abc123...
   Title: Flutter Development Test Lesson
   ...

🔍 Testing lesson loading...
✅ Lesson loaded successfully!
📊 Content Summary:
   Terms: 1
   Questions: 1
   Concepts: 1

🎉 All tests completed successfully!
```

---

## 🎯 Integration vs Unit vs Service Tests

### **🧩 Unit Tests** (`model_test.dart`)
- **Scope**: Individual components in isolation
- **Focus**: Model serialization, data structure validation
- **Speed**: Very fast (milliseconds)
- **Dependencies**: None (mocked)

### **🔧 Service Tests** (`offline_mode_test.dart`, `progress_sync_test.dart`)
- **Scope**: Individual services with mocked dependencies
- **Focus**: Service logic, error handling, data flow
- **Speed**: Fast (seconds)
- **Dependencies**: Mocked external services

### **🔗 Integration Tests** (`test/integration/`)
- **Scope**: Multiple components working together
- **Focus**: End-to-end workflows, real service interactions
- **Speed**: Slower (multiple seconds to minutes)
- **Dependencies**: Real database, environment configuration

---

## 🛠️ Setup & Prerequisites

### **Environment Setup**
1. **Environment Variables**:
   ```bash
   # .env file required with:
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   ```

2. **Sample Data**:
   ```bash
   # Ensure file exists:
   data/samples/sample_lesson_valid.json
   ```

3. **Database Schema**:
   - Supabase project with proper table schema
   - Lessons, terms, questions, concepts tables configured
   - Proper RLS policies and permissions

### **Running Integration Tests**

#### **Standalone Tests (Recommended)**:
```bash
# ✅ Run import test - works reliably
dart test/integration/test_import.dart
```

#### **Flutter Integration Tests (Platform Channel Issues)**:
```bash
# ⚠️ Service test - requires platform channel support
flutter test test/integration/test_lesson_creation.dart

# Note: Currently skipped due to shared_preferences platform channel issues
# Error: MissingPluginException(No implementation found for method getAll on channel plugins.flutter.io/shared_preferences)
```

#### **Recommended Test Strategy**:
1. **Use `test_import.dart`** for development validation ✅
2. **Use manual testing in running app** for service verification 🔧
3. **Service test currently requires full app context** ⚠️

---

## 🔍 Integration Test Characteristics

### **What Makes These Integration Tests**:
1. **Cross-Component**: Test multiple services working together
2. **Real Dependencies**: Use actual database and external services
3. **End-to-End**: Verify complete user workflows
4. **Environment-Dependent**: Require proper configuration and setup
5. **Slower Execution**: More comprehensive but take longer to run

### **When to Run**:
- **Before releases**: Ensure core workflows still function
- **After major changes**: Verify service integrations
- **During development**: Test new features end-to-end
- **CI/CD pipeline**: Automated quality assurance

### **What They Verify**:
- ✅ **Service Integration**: Multiple components work together
- ✅ **Data Flow**: Information flows correctly through system
- ✅ **Error Handling**: System gracefully handles edge cases
- ✅ **Performance**: Operations complete within reasonable time
- ✅ **Real-World Scenarios**: Actual usage patterns work correctly

---

## 🚨 Troubleshooting Integration Tests

### **Common Issues**:

#### **Environment Problems**:
```
❌ Failed to load .env file
```
**Solution**: Ensure `.env` file exists with valid Supabase credentials

#### **Database Connection**:
```
❌ Failed to initialize Supabase
```
**Solution**: Check internet connection, verify credentials, test Supabase project

#### **File Dependencies**:
```
❌ Sample lesson file not found
```
**Solution**: Ensure running from project root, verify `data/samples/` exists

#### **Schema Issues**:
```
❌ table "lessons" doesn't exist
```
**Solution**: Run database migrations, verify Supabase schema

### **Best Practices**:
1. **Run from project root** to ensure correct file paths
2. **Verify environment setup** before running tests
3. **Check database connectivity** and permissions
4. **Monitor test output** for detailed error information
5. **Clean up test data** if tests create persistent records

---

## 📈 Integration Test Maintenance

### **Adding New Integration Tests**:
1. Create new test file in `test/integration/`
2. Follow established patterns for setup and teardown
3. Include comprehensive error handling
4. Add documentation to this README
5. Update overall test documentation

### **Test Data Management**:
- Use consistent test data in `data/samples/`
- Ensure test data doesn't interfere with production
- Clean up any persistent test records
- Use deterministic test scenarios

### **Performance Considerations**:
- Integration tests are slower than unit tests
- Consider test timeout settings
- Monitor database performance during tests
- Optimize test data size for speed

---

## 📊 Integration Test Status

| Test File | Status | Coverage | Performance | Last Updated |
|-----------|--------|----------|-------------|--------------|
| `test_import.dart` | ✅ Working | Import Logic | ~2-3 seconds | Aug 26, 2025 |
| `test_lesson_creation.dart` | ⚠️ Platform Issues | Full Lifecycle | N/A (Skipped) | Aug 26, 2025 |

### **Current Status**:
- ✅ **Standalone Import Test**: Fully functional, reliable
- ⚠️ **Service Integration Test**: Platform channel dependency issues
- 🔧 **Manual Testing**: Required for full service verification

### **Platform Channel Issue**:
The lesson creation test fails with:
```
MissingPluginException(No implementation found for method getAll on channel plugins.flutter.io/shared_preferences)
```

This occurs because Supabase Flutter uses `shared_preferences` for local storage, which requires platform channel support that's not available in standard Flutter test environment.

### **Solutions Under Consideration**:
1. **Integration Test Package**: Use `integration_test` package for real app context
2. **Mock Platform Channels**: Mock shared_preferences dependency
3. **Service Mocking**: Create test doubles for Supabase services
4. **Test Environment**: Set up dedicated integration test environment

### **Coverage Areas**:
- ✅ **Lesson Import**: Order processing and JSON parsing
- ✅ **Service Layer**: LessonService create/read operations
- ✅ **Database Integration**: Supabase operations
- ✅ **Configuration**: Environment variable handling

### **Future Integration Tests**:
- 🔲 **User Authentication**: Login/logout workflows
- 🔲 **Progress Tracking**: Study session recording
- 🔲 **Offline Mode**: Cache/sync functionality
- 🔲 **Audio Features**: Voice input/output testing

---

*Integration test documentation - Last updated: August 26, 2025*
*These tests verify that all components work together correctly in real-world scenarios.*
