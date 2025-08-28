# 📊 Data Directory

Sample data and configuration files for the Learning PWA project.

## 📁 Structure
```
data/
├── samples/
│   ├── sample_lesson_valid.json   # Complex CompTIA lesson (378 lines)
│   └── README.md                  # Sample documentation
└── README.md                      # This file
```

## 📋 Sample Files Overview

### **`sample_lesson.json`** - Simple Flutter Lesson *(Moved to Assets)*
**Purpose**: Basic sample for UI widget demonstrations  
**Size**: 53 lines  
**Content**: 5 items (2 concepts, 1 term, 2 MCQs)  
**Location**: `assets/sample_lesson.json` (moved from data/samples/)  
**Used by**: `lib/widgets/lesson_json_import_widget.dart`

**Structure**:
- **Lesson**: "Introduction to Flutter"
- **Content Types**: Concepts, Terms, MCQs
- **Topic**: Flutter development basics
- **Complexity**: Simple, beginner-friendly

### **`sample_lesson_valid.json`** - Complex CompTIA Lesson  
**Purpose**: Comprehensive test data for integration testing  
**Size**: 378 lines  
**Content**: 27 items (7 terms, 6 concepts, 12 MCQs, 2 text)  
**Used by**: `test/integration/test_import.dart`

**Structure**:
- **Lesson**: "Laptops: Hardware, Displays, and Features"
- **Content Types**: Terms, Concepts, MCQs, Text content
- **Topic**: CompTIA A+ hardware certification
- **Complexity**: Comprehensive, real-world example

## 🎯 File Usage

### **In Application Code**:
```dart
// Used by lesson import widget for sample data
rootBundle.loadString('sample_lesson.json')
```

### **In Integration Tests**:
```dart
// Used by integration tests for comprehensive testing
File('data/samples/sample_lesson_valid.json')
```

## 📝 Data Structure

Both files follow the standard lesson JSON schema:

```json
{
  "lesson": {
    "id": "unique-id",
    "title": "Lesson Title",
    "description": "Lesson description",
    "tags": ["tag1", "tag2"],
    // ... other lesson metadata
  },
  "content": [
    {
      "type": "term|concept|mcq|text",
      "order": 1,
      // ... content-specific fields
    }
    // ... more content items
  ]
}
```

## 🔧 Content Types Supported

### **Terms**:
- `term`: The vocabulary word
- `definition`: Clear explanation
- `example`: Usage example
- `tags`: Categorization

### **Concepts**:
- `title`: Concept name
- `description`: Detailed explanation

### **Multiple Choice Questions (MCQ)**:
- `question`: Question text
- `options`: Array of answer choices
- `correctIndex`: Index of correct answer
- `explanation`: Why the answer is correct

### **Text Content**:
- `content`: Free-form text content
- `title`: Optional section title

## 🎯 Best Practices

### **Adding New Sample Data**:
1. **Follow schema structure** - Match existing JSON format
2. **Include proper metadata** - ID, title, description, tags
3. **Assign sequential order** - Content items should have proper order values
4. **Validate JSON** - Ensure proper syntax and structure
5. **Update documentation** - Add entries to this README

### **File Naming Convention**:
- `sample_[topic].json` - For basic samples
- `sample_[topic]_valid.json` - For comprehensive test data
- Use underscores, lowercase letters
- Include descriptive topic names

## 🔍 Validation

### **JSON Structure Validation**:
Both files are validated by:
- **Integration tests** - Automatic parsing verification
- **Widget code** - Runtime JSON loading and parsing
- **Manual testing** - Through the lesson import interface

### **Content Validation**:
- All required fields present
- Proper data types
- Sequential order values
- Valid content type specifications

## 📈 Usage Statistics

| File | Size | Content Items | Location | Used By | Purpose |
|------|------|---------------|----------|---------|---------|
| `sample_lesson.json` | 53 lines | 5 items | `assets/` | UI Widget | Demo/Sample |
| `sample_lesson_valid.json` | 378 lines | 27 items | `data/samples/` | Integration Tests | Comprehensive Testing |

## 🔮 Future Enhancements

### **Potential Additions**:
- **sample_lesson_minimal.json** - Absolute minimum required fields
- **sample_lesson_audio.json** - With audio content references
- **sample_lesson_multilingual.json** - Multiple language support
- **samples/topics/** - Organized by subject area

### **Schema Evolution**:
- Support for nested content structures
- Audio/video content references
- Interactive content types
- Adaptive difficulty levels

---

*Last Updated: August 27, 2025*  
*Sample data for Learning PWA development and testing*
