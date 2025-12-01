import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:learning_pwa/utils/lesson_json_validator.dart';
import 'package:learning_pwa/widgets/content_quality_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced JSON import widget with live preview, better validation, and improved UX
class EnhancedJsonImportWidget extends StatefulWidget {
  final Function(String) onImport;

  const EnhancedJsonImportWidget({
    super.key,
    required this.onImport,
  });

  @override
  State<EnhancedJsonImportWidget> createState() => _EnhancedJsonImportWidgetState();
}

class _EnhancedJsonImportWidgetState extends State<EnhancedJsonImportWidget>
    with SingleTickerProviderStateMixin {
  final _jsonController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;
  
  String? _validationError;
  List<String> _validationWarnings = [];
  List<String> _validationSuggestions = [];
  Map<String, dynamic>? _parsedJson;
  Map<String, dynamic>? _lessonPreview;
  bool _isValidating = false;
  bool _showLineNumbers = true;
  List<Map<String, String>> _recentImports = [];
  
  static const String _prefsKey = 'recent_json_imports';
  static const int _maxRecentImports = 5;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _jsonController.addListener(_onJsonChanged);
    _loadRecentImports();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadRecentImports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentJsonString = prefs.getString(_prefsKey);
      
      if (recentJsonString != null) {
        final List<dynamic> recentList = jsonDecode(recentJsonString);
        setState(() {
          _recentImports = recentList
              .cast<Map<String, dynamic>>()
              .map((item) => Map<String, String>.from(item))
              .toList();
        });
      }
    } catch (e) {
      // Silently fail - recent imports is a nice-to-have feature
      debugPrint('Failed to load recent imports: $e');
    }
  }
  
  Future<void> _saveRecentImport(Map<String, dynamic> lessonData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Extract lesson title and timestamp
      final lesson = lessonData['lesson'] as Map<String, dynamic>? ?? {};
      final title = lesson['title']?.toString() ?? 'Untitled Lesson';
      final timestamp = DateTime.now().toIso8601String();
      
      // Create import record
      final importRecord = {
        'title': title,
        'timestamp': timestamp,
        'json': jsonEncode(lessonData),
      };
      
      // Add to recent imports list (avoid duplicates by title)
      _recentImports.removeWhere((item) => item['title'] == title);
      _recentImports.insert(0, importRecord);
      
      // Keep only the most recent imports
      if (_recentImports.length > _maxRecentImports) {
        _recentImports = _recentImports.sublist(0, _maxRecentImports);
      }
      
      // Save to SharedPreferences
      await prefs.setString(_prefsKey, jsonEncode(_recentImports));
      
      setState(() {});
    } catch (e) {
      debugPrint('Failed to save recent import: $e');
    }
  }

  void _onJsonChanged() {
    // Debounce validation to avoid excessive calls
    if (!_isValidating) {
      _isValidating = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _validateJson();
          _isValidating = false;
        }
      });
    }
  }

  void _validateJson() {
    final jsonText = _jsonController.text.trim();
    
    if (jsonText.isEmpty) {
      setState(() {
        _validationError = null;
        _validationWarnings.clear();
        _validationSuggestions.clear();
        _parsedJson = null;
        _lessonPreview = null;
      });
      return;
    }

    try {
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      
      // Enhanced validation with detailed feedback
      final validationResult = LessonJsonValidator.validate(parsed);
      
      if (!validationResult.isValid) {
        setState(() {
          _validationError = _formatValidationErrors(validationResult.errors);
          _validationWarnings = validationResult.warnings;
          _validationSuggestions = _generateSuggestions(validationResult.errors);
          _parsedJson = null;
          _lessonPreview = null;
        });
      } else {
        setState(() {
          _validationError = null;
          _validationWarnings = validationResult.warnings;
          _validationSuggestions.clear();
          _parsedJson = parsed;
          _lessonPreview = _generateLessonPreview(parsed);
        });
      }
    } catch (e) {
      setState(() {
        _validationError = _formatJsonError(e.toString());
        _validationWarnings.clear();
        _validationSuggestions = _generateJsonSuggestions(e.toString());
        _parsedJson = null;
        _lessonPreview = null;
      });
    }
  }

  String _formatValidationErrors(List<String> errors) {
    return errors.map((error) {
      // Add more context and helpful information to errors
      if (error.contains('required field')) {
        return '❌ $error\n   💡 This field is mandatory for lesson creation';
      } else if (error.contains('invalid format')) {
        return '❌ $error\n   💡 Check the expected format in the documentation';
      } else if (error.contains('length')) {
        return '❌ $error\n   💡 Adjust the content length to meet requirements';
      }
      return '❌ $error';
    }).join('\n\n');
  }

  List<String> _generateSuggestions(List<String> errors) {
    List<String> suggestions = [];
    
    for (String error in errors) {
      if (error.contains('title')) {
        suggestions.add('Add a descriptive title (5-100 characters)');
      } else if (error.contains('content')) {
        suggestions.add('Include at least one content item (term, concept, or MCQ)');
      } else if (error.contains('options')) {
        suggestions.add('MCQ questions must have exactly 4 options');
      } else if (error.contains('correct_answer')) {
        suggestions.add('Ensure correct_answer matches one of the options exactly');
      }
    }
    
    return suggestions;
  }

  String _formatJsonError(String error) {
    if (error.contains('Unexpected character')) {
      return '❌ JSON Syntax Error: Invalid character found\n💡 Check for missing quotes, commas, or brackets';
    } else if (error.contains('Unexpected end')) {
      return '❌ JSON Syntax Error: Incomplete JSON structure\n💡 Make sure all brackets and braces are properly closed';
    } else if (error.contains('duplicate key')) {
      return '❌ JSON Syntax Error: Duplicate field names\n💡 Each field name must be unique within an object';
    }
    return '❌ JSON Parsing Error: $error';
  }

  List<String> _generateJsonSuggestions(String error) {
    List<String> suggestions = [];
    
    if (error.contains('character')) {
      suggestions.add('Use a JSON validator to check syntax');
      suggestions.add('Ensure all strings are wrapped in double quotes');
    } else if (error.contains('end')) {
      suggestions.add('Check that all { } and [ ] are properly matched');
      suggestions.add('Remove any trailing commas');
    }
    
    return suggestions;
  }

  Map<String, dynamic> _generateLessonPreview(Map<String, dynamic> json) {
    final lesson = json['lesson'] as Map<String, dynamic>? ?? {};
    final content = json['content'] as List? ?? [];
    
    return {
      'title': lesson['title'] ?? 'Untitled Lesson',
      'description': lesson['description'] ?? 'No description provided',
      'difficulty': lesson['difficulty_level'] ?? 'beginner',
      'duration': lesson['estimated_duration_minutes'] ?? 30,
      'tags': lesson['tags'] ?? [],
      'contentStats': {
        'total': content.length,
        'terms': content.where((item) => item['type'] == 'term').length,
        'concepts': content.where((item) => item['type'] == 'concept').length,
        'mcqs': content.where((item) => item['type'] == 'mcq').length,
        'text': content.where((item) => item['type'] == 'text').length,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar for Editor and Preview
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.edit),
                child: Text('JSON Editor'),
              ),
              Tab(
                icon: const Icon(Icons.preview),
                child: Text('Live Preview'),
              ),
              Tab(
                icon: const Icon(Icons.analytics),
                child: Text('Quality Analysis'),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildJsonEditor(),
              _buildLivePreview(),
              _buildQualityAnalysis(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJsonEditor() {
    return Row(
      children: [
        // JSON Input Area
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_paste),
                      onPressed: _pasteFromClipboard,
                      tooltip: 'Paste from clipboard',
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearEditor,
                      tooltip: 'Clear editor',
                    ),
                    if (_recentImports.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.history),
                        tooltip: 'Load recent import',
                        onSelected: _loadRecentImport,
                        itemBuilder: (context) => _recentImports.map((import) {
                          final title = import['title'] ?? 'Untitled';
                          final timestamp = import['timestamp'];
                          final timeAgo = timestamp != null
                              ? _formatTimeAgo(DateTime.parse(timestamp))
                              : '';
                          
                          return PopupMenuItem<String>(
                            value: import['json'],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (timeAgo.isNotEmpty)
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_showLineNumbers ? Icons.format_list_numbered : Icons.format_list_numbered_rtl),
                      onPressed: () => setState(() => _showLineNumbers = !_showLineNumbers),
                      tooltip: 'Toggle line numbers',
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      onPressed: _showJsonHelp,
                      tooltip: 'JSON format help',
                    ),
                  ],
                ),
              ),
              
              // JSON Text Field
              Expanded(
                child: Stack(
                  children: [
                    if (_showLineNumbers) _buildLineNumbers(),
                    Padding(
                      padding: EdgeInsets.only(left: _showLineNumbers ? 50 : 8),
                      child: TextField(
                        controller: _jsonController,
                        scrollController: _scrollController,
                        decoration: const InputDecoration(
                          hintText: 'Paste your lesson JSON here...\n\nExample:\n{\n  "lesson": {\n    "title": "Your Lesson Title",\n    "description": "Brief description"\n  },\n  "content": [\n    {\n      "type": "term",\n      "title": "Key Term",\n      "content": "Definition"\n    }\n  ]\n}',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Validation Panel
        Container(
          width: 350,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: _buildValidationPanel(),
        ),
      ],
    );
  }

  Widget _buildLineNumbers() {
    final lines = _jsonController.text.split('\n').length;
    return Container(
      width: 50,
      color: Colors.grey[100],
      child: Column(
        children: List.generate(
          lines,
          (index) => Container(
            height: 20,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationPanel() {
    return Column(
      children: [
        // Status Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: _getStatusColor(),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
            ],
          ),
        ),
        
        // Validation Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_validationError != null) ...[
                  _buildErrorSection(),
                  const SizedBox(height: 16),
                ],
                
                if (_validationSuggestions.isNotEmpty) ...[
                  _buildSuggestionsSection(),
                  const SizedBox(height: 16),
                ],
                
                if (_validationWarnings.isNotEmpty) ...[
                  _buildWarningsSection(),
                  const SizedBox(height: 16),
                ],
                
                if (_parsedJson != null) ...[
                  _buildSuccessSection(),
                  const SizedBox(height: 16),
                ],
                
                _buildQuickActions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Errors',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Text(
            _validationError!,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suggestions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        ..._validationSuggestions.map((suggestion) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildWarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Warnings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        ..._validationWarnings.map((warning) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_outlined, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSuccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ready to Import',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: const Text(
            '✅ JSON is valid and ready for import!',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loadExample,
            icon: const Icon(Icons.description, size: 16),
            label: const Text('Load Example'),
          ),
        ),
        
        const SizedBox(height: 8),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _formatJson,
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('Format JSON'),
          ),
        ),
        
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _parsedJson != null ? _importLesson : null,
            icon: const Icon(Icons.upload, size: 16),
            label: const Text('Import Lesson'),
          ),
        ),
      ],
    );
  }

  Widget _buildLivePreview() {
    if (_lessonPreview == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.preview, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Enter valid JSON to see live preview',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lesson Header Preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lessonPreview!['title'],
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _lessonPreview!['description'],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text('${_lessonPreview!['difficulty']}'),
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                      Chip(
                        label: Text('${_lessonPreview!['duration']} min'),
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Content Statistics
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Overview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildContentStat('Total Items', _lessonPreview!['contentStats']['total'], Icons.list),
                  _buildContentStat('Terms', _lessonPreview!['contentStats']['terms'], Icons.book),
                  _buildContentStat('Concepts', _lessonPreview!['contentStats']['concepts'], Icons.lightbulb),
                  _buildContentStat('MCQs', _lessonPreview!['contentStats']['mcqs'], Icons.quiz),
                  if (_lessonPreview!['contentStats']['text'] > 0)
                    _buildContentStat('Text', _lessonPreview!['contentStats']['text'], Icons.text_fields),
                ],
              ),
            ),
          ),
          
          // Tags Preview
          if (_lessonPreview!['tags'].isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: (_lessonPreview!['tags'] as List)
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentStat(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text('$label: '),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (_validationError != null) return Colors.red;
    if (_validationWarnings.isNotEmpty) return Colors.orange;
    if (_parsedJson != null) return Colors.green;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_validationError != null) return Icons.error;
    if (_validationWarnings.isNotEmpty) return Icons.warning;
    if (_parsedJson != null) return Icons.check_circle;
    return Icons.info;
  }

  String _getStatusText() {
    if (_validationError != null) return 'Invalid JSON';
    if (_validationWarnings.isNotEmpty) return 'Valid with Warnings';
    if (_parsedJson != null) return 'Valid JSON';
    return 'Enter JSON';
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _jsonController.text = data!.text!;
    }
  }

  void _clearEditor() {
    _jsonController.clear();
  }

  void _loadExample() {
    const exampleJson = '''
{
  "lesson": {
    "title": "Python Variable Types",
    "description": "Learn about different data types in Python including integers, floats, strings, and booleans.",
    "estimated_duration_minutes": 30,
    "difficulty_level": "beginner",
    "tags": ["python", "programming", "variables", "data-types"]
  },
  "content": [
    {
      "type": "term",
      "title": "Variable",
      "content": "A named storage location that holds a value which can be changed during program execution.",
      "example": "age = 25"
    },
    {
      "type": "concept",
      "title": "Dynamic Typing",
      "content": "Python automatically determines the data type of a variable based on the value assigned to it.",
      "key_points": [
        "No need to declare variable types",
        "Type determined at runtime",
        "Variables can change types"
      ]
    },
    {
      "type": "mcq",
      "question": "Which of the following is a valid Python variable name?",
      "options": ["2name", "name-2", "name_2", "name 2"],
      "correct_answer": "name_2",
      "explanation": "Variable names can contain letters, numbers, and underscores, but cannot start with a number or contain spaces or hyphens."
    }
  ]
}''';
    _jsonController.text = exampleJson;
  }

  void _formatJson() {
    try {
      final parsed = jsonDecode(_jsonController.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(parsed);
      _jsonController.text = formatted;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot format invalid JSON'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showJsonHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('JSON Format Help'),
        content: const SingleChildScrollView(
          child: Text('''
Required Structure:
{
  "lesson": {
    "title": "string (required)",
    "description": "string (optional)",
    "estimated_duration_minutes": number,
    "difficulty_level": "beginner|intermediate|advanced",
    "tags": ["array", "of", "strings"]
  },
  "content": [
    {
      "type": "term|concept|mcq|text",
      "title": "string",
      "content": "string",
      // Additional fields based on type
    }
  ]
}

Common Issues:
• Use double quotes for strings
• No trailing commas
• Match opening/closing brackets
• Correct field names (case-sensitive)
'''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _importLesson() {
    if (_parsedJson != null) {
      // Save to recent imports before calling onImport
      _saveRecentImport(_parsedJson!);
      widget.onImport(jsonEncode(_parsedJson));
    }
  }
  
  void _loadRecentImport(String? jsonString) {
    if (jsonString != null && jsonString.isNotEmpty) {
      _jsonController.text = jsonString;
      _validateJson();
    }
  }
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildQualityAnalysis() {
    if (_parsedJson == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Quality Analysis Unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter valid JSON in the editor to see quality analysis',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ContentQualityWidget(
      lessonData: _parsedJson!,
      onSuggestionsApplied: (suggestions) {
        // Handle quality suggestions if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quality suggestions noted: ${suggestions.length} items'),
            backgroundColor: Colors.blue,
          ),
        );
      },
    );
  }
}
