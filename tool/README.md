# 🛠️ Development Tools

This directory contains development and utility scripts for the Learning PWA project.

## 📋 Available Tools

### `import_lesson.dart`
**Purpose**: Import lesson data from JSON files into Supabase database

**Usage**:
```bash
# Run from project root directory
dart tool/import_lesson.dart
```

**Prerequisites**:
1. ✅ **Environment Setup**: Ensure `.env` file exists with valid Supabase credentials
2. ✅ **Database Access**: Supabase project must be accessible with provided credentials
3. ✅ **Sample Data**: Lesson JSON file must exist in `data/samples/sample_lesson_valid.json`

**Features**:
- 🔒 **Secure**: Uses environment variables instead of hardcoded credentials
- 📁 **Organized**: Works with new file structure (`data/samples/`)
- 🛡️ **Error Handling**: Comprehensive validation and error messages
- 📊 **Detailed Logging**: Clear progress and result reporting
- 🔄 **Upsert Operation**: Safely updates existing lessons or creates new ones

**Database Fields Imported**:
- Basic lesson metadata (id, title, description, author)
- Learning attributes (difficulty, estimated_time_minutes)
- Categorization (tags, language)
- Visibility settings (is_public, is_featured)
- Media references (cover_image_url)
- Complete content structure (stored as JSON)
- Timestamps (created_at, updated_at)

**Example Output**:
```
🎯 Lesson Import Tool - Learning PWA
=====================================
🚀 Starting lesson import process...
✅ Environment variables loaded
✅ Connected to Supabase
📖 Loaded lesson: Laptops: Hardware, Displays, and Features
✅ Lesson imported successfully!
📋 Lesson Details:
   ID: 4771cdf2-fa08-44c7-8d07-54d9b2f9280e
   Title: Laptops: Hardware, Displays, and Features
   Content items: 25
   Difficulty: beginner
   Estimated time: 45 minutes
=====================================
🎉 Import process completed!
```

---

## 🚀 Running Development Tools

### From VS Code:
1. Open terminal in VS Code
2. Ensure you're in the project root directory
3. Run: `dart tool/import_lesson.dart`

### From Command Line:
```bash
cd /path/to/LearningApp
dart tool/import_lesson.dart
```

### Troubleshooting:
- **Environment Error**: Check `.env` file exists and contains required variables
- **File Not Found**: Ensure you're running from project root directory
- **Database Error**: Verify Supabase credentials and database permissions
- **JSON Error**: Validate lesson JSON structure in `data/samples/`

---

## 📂 Related Directories

- **`data/samples/`** - Sample lesson JSON files
- **`scripts/development/`** - Other development scripts
- **`database/`** - Database schema and migration files
- **`docs/`** - Project documentation
