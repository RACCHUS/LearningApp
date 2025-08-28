# 🛠️ Scripts Directory

Development and utility scripts for the Learning PWA project.

## 📁 Structure
```
scripts/
└── README.md     # This file
```

## 📋 Status: Scripts Moved to Test Directory

The development scripts that were previously in this folder have been **moved to the test directory** for better organization:

- `test_import.dart` → `test/integration/test_import.dart`
- `test_lesson_creation.dart` → `test/integration/test_lesson_creation.dart`

## 🎯 Why the Move?

These files were **testing functionality** rather than being utility scripts, so they belong in the `test/` directory following Dart/Flutter conventions:

### **New Test Organization:**
```
test/
├── model_test.dart              # Unit Tests
├── offline_mode_test.dart       # Service Tests  
├── progress_sync_test.dart      # Service Tests
├── test_helper.dart             # Test Utilities
├── integration/                 # Integration Tests
│   ├── test_import.dart         # ✅ MOVED - Import testing
│   ├── test_lesson_creation.dart # ✅ MOVED - Service testing
│   └── README.md               # Integration test docs
└── README.md                   # Main test documentation
```

## 🚀 Running Tests

**Integration Tests** (formerly scripts):
```bash
# Run from project root directory
dart test/integration/test_import.dart
dart test/integration/test_lesson_creation.dart
```

**All Tests**:
```bash
flutter test
```

## 📖 Documentation

- **Integration Tests**: See [`test/integration/README.md`](../test/integration/README.md)
- **All Tests**: See [`test/README.md`](../test/README.md)

## 🔮 Future Scripts

This directory is reserved for **actual utility scripts** such as:
- Build automation scripts
- Deployment utilities  
- Data migration scripts
- Development environment setup
- Code generation utilities

---

*Scripts directory - Reorganized: August 26, 2025*  
*Testing files moved to proper test directory structure*
