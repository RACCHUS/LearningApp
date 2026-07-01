# 🛠️ Development Tools

This directory contains development and utility scripts for the Learning PWA project.

## 📋 Available Tools

### `import_lesson.dart`
**Purpose**: Import lesson JSON files into the Supabase database — single files, entire folders, or validate without importing.

**Supports two JSON formats automatically:**
- **Simple format** — `{ title, description, tags, concepts[], terms[], questions[] }` (used by `assets/lessons/`)
- **Database format** — `{ lesson: {...}, content: [{type, ...}] }` (used by `data/samples/`)

**Usage**:
```bash
# Import a single lesson file
dart tool/import_lesson.dart assets/lessons/prog_01_variables.json

# Import all lessons in a folder
dart tool/import_lesson.dart assets/lessons/

# Import data samples
dart tool/import_lesson.dart data/samples/

# Validate files without importing (dry run)
dart tool/import_lesson.dart assets/lessons/ --dry-run

# List all lessons currently in the database
dart tool/import_lesson.dart --list

# Import the file currently open in VS Code (via task)
# Use: Terminal > Run Task > "Import: Current File as Lesson"
```

**Prerequisites**:
1. ✅ **Environment Setup**: `.env` file with `SUPABASE_URL` and `SUPABASE_ANON_KEY`
2. ✅ **Database Access**: Supabase project must be accessible

**Features**:
- 📁 **Flexible Input**: Single file, multiple files, or entire directories
- 🔄 **Auto-Detection**: Automatically detects simple vs database JSON format
- 🔍 **Dry Run**: Validate lesson files without touching the database
- 📋 **List Mode**: See what's already in the database
- 🛡️ **Validation**: Checks structure before importing
- 🔄 **Upsert**: Safely updates existing lessons or creates new ones

**VS Code Tasks** (Terminal > Run Task):
| Task | Description |
|------|-------------|
| Import: All Asset Lessons | Imports everything in `assets/lessons/` |
| Import: Data Samples | Imports everything in `data/samples/` |
| Import: Validate Lessons (Dry Run) | Validates without importing |
| Import: List Database Lessons | Shows lessons in the database |
| Import: Current File as Lesson | Imports the file you have open |

**Example Output**:
```
🎯 Lesson Import Tool - Learning PWA
=====================================
📁 Found 5 lesson file(s) to process

✅ prog_01_variables.json — format: simple, title: "Variables & Data Types"
✅ prog_02_control_flow.json — format: simple, title: "Control Flow"
✅ prog_03_functions.json — format: simple, title: "Functions"
✅ prog_04_data_structures.json — format: simple, title: "Data Structures"
✅ prog_05_oop.json — format: simple, title: "OOP"

✅ Connected to Supabase

📥 Importing 5 lesson(s)...
   ✅ Variables & Data Types
      18 content items | beginner | tags: [programming, beginner]
   ...

=====================================
🎉 Done! 5 imported, 0 errors
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
