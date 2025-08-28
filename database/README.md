# 🗄️ Database Directory

Database schema, migrations, functions, and utilities for the Learning PWA project.

## 📁 Structure Overview
```
database/
├── schema/                     # 📋 Database schema definitions
│   └── schema.sql             # Main database schema
├── migrations/                 # 🔄 Database migration scripts
│   ├── add_order_and_content_support.sql
│   ├── cleanup_schema.sql
│   └── nuclear_rls_fix.sql
├── functions/                  # ⚙️ Database functions and triggers
│   └── supabase_user_sync.sql
├── seeds/                      # 🌱 Sample data insertion scripts
│   └── import_laptop_lesson_complete.sql
├── debug/                      # 🔍 Diagnostic and testing scripts
│   └── diagnostic_test.sql
└── README.md                  # This documentation
```

---

## 📋 Schema (`schema/`)

### **`schema.sql`** - Main Database Schema
**Purpose**: Complete database structure definition  
**Contains**:
- ✅ **Core tables**: `users`, `lessons`, `terms`, `concepts`, `questions`
- ✅ **Indexes**: Optimized for performance (GIN for tags, user_id indexes)
- ✅ **Relationships**: Proper foreign key constraints
- ✅ **Data types**: UUIDs, timestamps, text arrays

**Key Tables**:
- **`users`**: User accounts and profiles
- **`lessons`**: Main lesson metadata and content
- **`terms`**: Vocabulary definitions with examples
- **`concepts`**: Detailed explanatory content
- **`questions`**: Multiple choice questions with answers

---

## 🔄 Migrations (`migrations/`)

### **Migration Files** (Applied in chronological order):

#### **`add_order_and_content_support.sql`**
- **Purpose**: Adds content ordering and text content support
- **Changes**: 
  - Adds `order_index` to terms, concepts, questions
  - Creates `lesson_texts` table for supplementary content
  - Enables proper content sequencing in lessons

#### **`cleanup_schema.sql`**
- **Purpose**: Schema cleanup and optimization
- **Changes**: Table refinements, constraint updates

#### **`nuclear_rls_fix.sql`** 
- **Purpose**: Row Level Security (RLS) policy fixes
- **Changes**: Corrects permissions and access policies
- **Note**: "Nuclear" indicates comprehensive RLS reset

---

## ⚙️ Functions (`functions/`)

### **`supabase_user_sync.sql`** - User Synchronization
**Purpose**: Automatic user profile creation  
**Functionality**:
- ✅ **Trigger**: `on_auth_user_created` 
- ✅ **Action**: Creates `users` table entry when Supabase auth user is created
- ✅ **Sync**: Maintains consistency between auth.users and public.users
- ✅ **Safety**: Uses `ON CONFLICT DO NOTHING` for idempotency

**Trigger Flow**:
1. User signs up via Supabase Auth
2. Trigger fires automatically
3. Entry created in public.users table
4. Profile data becomes available to application

---

## 🌱 Seeds (`seeds/`)

### **`import_laptop_lesson_complete.sql`** - Sample Lesson Data
**Purpose**: Comprehensive lesson import for testing and demo  
**Content**: CompTIA A+ laptop hardware lesson  
**Data Volume**: 27 content items (terms, concepts, MCQs, text)

**Features**:
- ✅ **Complete lesson structure** with metadata
- ✅ **JSON content column** for flexible data storage
- ✅ **Individual table records** for relational queries
- ✅ **Proper order indexing** for content sequencing
- ✅ **Real-world content** suitable for certification study

**Usage**: Run after schema and migrations for development environment setup

---

## 🔍 Debug (`debug/`)

### **`diagnostic_test.sql`** - Database Diagnostics
**Purpose**: Comprehensive database health and permission testing  
**Test Coverage**:
- ✅ **Table access**: Verifies table existence and readability
- ✅ **Insert operations**: Tests exact Flutter application queries
- ✅ **User verification**: Checks guest user configuration
- ✅ **RLS status**: Validates Row Level Security configuration
- ✅ **Permissions**: Verifies table access permissions

**Diagnostic Steps**:
1. Count existing lessons (table access test)
2. Perform sample lesson insert (operation test)
3. Verify guest user exists (authentication test)
4. Check RLS policies (security test)
5. Validate table permissions (access control test)

---

## 🚀 Database Setup Workflow

### **Initial Setup** (New Environment):
```bash
# 1. Create schema
psql -f database/schema/schema.sql

# 2. Apply migrations (in order)
psql -f database/migrations/add_order_and_content_support.sql
psql -f database/migrations/cleanup_schema.sql
psql -f database/migrations/nuclear_rls_fix.sql

# 3. Install functions and triggers
psql -f database/functions/supabase_user_sync.sql

# 4. Load sample data (optional)
psql -f database/seeds/import_laptop_lesson_complete.sql
```

### **Development Testing**:
```bash
# Run diagnostics to verify setup
psql -f database/debug/diagnostic_test.sql
```

### **Migration Application** (Existing Environment):
```bash
# Apply new migrations as they are created
psql -f database/migrations/[new_migration_file].sql
```

---

## 🔧 Database Integration

### **Supabase Configuration**:
- **Local Development**: Uses local Supabase instance (port 54322)
- **Production**: Connects to Supabase cloud instance
- **Authentication**: Integrated with Supabase Auth via triggers
- **Real-time**: Supports real-time subscriptions for live updates

### **Application Integration**:
- **Service Layer**: `lib/services/lesson_service.dart` executes these queries
- **Configuration**: `lib/config/supabase_config.dart` manages connection
- **Environment**: Uses `.env` file for secure credential management

### **Data Flow**:
1. **Schema**: Defines structure and relationships
2. **Migrations**: Evolve schema over time
3. **Functions**: Handle automatic data processing
4. **Seeds**: Provide development and test data
5. **Debug**: Verify everything works correctly

---

## 📊 Schema Highlights

### **Key Design Decisions**:
- ✅ **UUID Primary Keys**: Better for distributed systems
- ✅ **JSONB Content Storage**: Flexible lesson content structure
- ✅ **Relational Tables**: Structured queries and joins
- ✅ **GIN Indexes**: Fast array and JSONB queries
- ✅ **Timestamp Tracking**: Automatic created/updated timestamps
- ✅ **Cascade Deletions**: Maintain referential integrity

### **Performance Optimizations**:
- ✅ **Indexed Tags**: Fast lesson categorization queries
- ✅ **User ID Indexes**: Quick user-specific data retrieval  
- ✅ **Order Indexing**: Efficient content sequencing
- ✅ **Constraint Validation**: Data integrity at database level

### **Security Features**:
- ✅ **Row Level Security**: User-based data access control
- ✅ **Function Security**: Secure trigger execution
- ✅ **Guest User Support**: Anonymous lesson access capability

---

## 🔮 Future Enhancements

### **Planned Migrations**:
- Audio content support (file references, transcripts)
- Multi-language lesson support
- Advanced progress tracking
- Lesson versioning and history

### **Optimization Opportunities**:
- Materialized views for complex queries
- Partition large tables by date
- Additional indexes based on query patterns
- Caching strategies for frequently accessed data

### **Development Tools**:
- Automated migration testing
- Data validation scripts
- Performance monitoring queries
- Backup and restore procedures

---

## 📈 Current Status

| Component | Status | Files | Purpose |
|-----------|--------|-------|---------|
| **Schema** | ✅ Complete | 1 | Database structure |
| **Migrations** | ✅ Active | 3 | Schema evolution |
| **Functions** | ✅ Working | 1 | User synchronization |
| **Seeds** | ✅ Available | 1 | Sample data |
| **Debug** | ✅ Ready | 1 | Diagnostics |

### **Integration Status**:
- ✅ **Supabase**: Fully configured and connected
- ✅ **Flutter App**: Successfully consuming database
- ✅ **Authentication**: User sync working correctly
- ✅ **Content Storage**: JSON and relational data both supported

---

*Database documentation - Last updated: August 28, 2025*  
*Schema and migration files for Learning PWA Supabase database*
