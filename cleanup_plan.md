# LearningApp Cleanup Plan

## **Project Architecture**
- **Framework**: Flutter Web PWA + Supabase + Riverpod
- **Structure**: Clean separation - services, providers, models, widgets, screens
- **Key Patterns**: Triple-widget architecture, specialized services, Riverpod state management

## **Cleanup Methodology**

### **1. Initial Assessment**
```bash
# Check project structure
find lib -type f -name "*.dart" | wc -l
# Look for large files needing refactoring
find lib -name "*.dart" -exec wc -l {} + | sort -n | tail -10
```

### **2. Systematic Cleanup Process**
1. **Root level**: Remove outdated/duplicate files first
2. **lib subfolders**: Analyze one by one (components → config → theme → utils → widgets → screens → services → providers → models)
3. **Duplicate detection**: Look for similar filenames, duplicate classes, conflicting functionality
4. **Usage verification**: Always verify before deletion using `grep_search` across codebase

### **3. Critical Checks**

#### **Hive Type ID Conflicts**
```bash
# Check for duplicate Hive type IDs
grep -r "typeId:" lib/models/ | sort
```
- **Used IDs**: 0,1,2,3,4,5,6,7,8,20 (update as needed)
- **Fix conflicts**: Change to unused ID + regenerate with `build_runner`

#### **Provider Naming Conflicts**
```bash
# Check for duplicate provider names
grep -r "final.*Provider.*=" lib/providers/
```

#### **Import/Usage Verification**
```bash
# Before deleting, verify usage
grep -r "import.*filename\|ClassName" lib/
```

### **4. Post-Cleanup**
1. **Regenerate code**: `flutter packages pub run build_runner build --delete-conflicting-outputs`
2. **Clean build**: `flutter clean && flutter pub get`
3. **Verify compilation**: Check for lint errors and fix

## **Common Cleanup Targets**
- Manual Hive adapters (use generated `.g.dart` instead)
- Duplicate screens not in router
- Unused service classes
- Conflicting provider names
- Old/backup files with suffixes (`_old`, `_backup`, `_alt`)

## **Preservation Rules**
- **Always preserve**: Router-registered screens, actively used providers, generated Hive adapters
- **Verify before deletion**: Any file with imports in multiple locations
- **Keep functionality**: Services with extensive integration (e.g., reminder system)
