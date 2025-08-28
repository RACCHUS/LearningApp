# 📄 Sample Lesson Data

Sample JSON files containing lesson data for development and testing.

## 📋 Files

### 🎯 **sample_lesson.json** - Flutter Introduction *(Moved to Assets)*
- **Topic**: Flutter development basics
- **Size**: 53 lines, 5 content items
- **Location**: `assets/sample_lesson.json` (moved from here for proper asset loading)
- **Used by**: Lesson import widget (`lib/widgets/lesson_json_import_widget.dart`)
- **Purpose**: Simple demonstration data for UI components

**Content breakdown**:
- 2 Concepts (What is Flutter, Hot Reload)
- 1 Term (Widget)
- 2 MCQs (Programming language, ListView widget)

### 🎯 **sample_lesson_valid.json** - CompTIA A+ Laptops
- **Topic**: CompTIA A+ laptop hardware and displays
- **Size**: 378 lines, 27 content items
- **Used by**: Integration tests (`test/integration/test_import.dart`)
- **Purpose**: Comprehensive test data for order processing verification

**Content breakdown**:
- 7 Terms (SODIMM, Docking Station, OLED, M.2 SSD, etc.)
- 6 Concepts (laptop displays, input devices, etc.)
- 12 MCQs (hardware identification questions)
- 2 Text content items

## 🔧 Technical Details

### **JSON Schema Compliance**:
Both files follow the standard lesson import schema:
- Lesson metadata (id, title, description, tags)
- Content array with proper typing
- Sequential order values for content items

### **Order Processing**:
The `sample_lesson_valid.json` specifically tests:
- Sequential order values (1-27)
- Mixed content types in proper order
- Order preservation during import process

### **Content Type Coverage**:
- ✅ Terms with definitions and examples
- ✅ Concepts with detailed descriptions  
- ✅ MCQs with options and explanations
- ✅ Text content for supplementary material

## 🎯 Usage Examples

### **Loading in Widgets**:
```dart
// Now properly loads from assets
final sampleJson = await rootBundle.loadString('sample_lesson.json');
```

### **Integration Testing**:
```dart
final file = File('data/samples/sample_lesson_valid.json');
final jsonData = jsonDecode(await file.readAsString());
```

## 🧪 Testing Coverage

These samples provide test coverage for:
- JSON parsing and validation
- Content type handling
- Order sequence processing
- Mixed content import workflows
- UI demonstration capabilities

---

*Sample data files for Learning PWA - Last updated: August 27, 2025*
