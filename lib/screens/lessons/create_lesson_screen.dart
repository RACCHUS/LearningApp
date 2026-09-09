import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/core/errors/app_exceptions.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/services/ai_prompt_service.dart';
import 'package:learning_pwa/widgets/enhanced_json_import_widget.dart';
import 'package:learning_pwa/widgets/lesson_builder_widget.dart';
import 'package:learning_pwa/widgets/prompt_display_widget.dart';
import 'package:learning_pwa/widgets/template_selection_widget.dart';
import 'package:learning_pwa/screens/lesson_creation_guide_screen.dart';
import 'package:learning_pwa/theme/semantic_colors.dart';
import 'package:go_router/go_router.dart';

class CreateLessonScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  final int initialBuilderTabIndex;

  const CreateLessonScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialBuilderTabIndex = 0,
  });

  @override
  ConsumerState<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends ConsumerState<CreateLessonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // AI Assistant form data
  final _subjectController = TextEditingController();
  String _targetAudience = 'beginner';
  int _durationMinutes = 30;
  String _difficulty = 'beginner';
  String _contentFocus = 'balanced';

  @override
  void initState() {
    super.initState();
    final initialTab = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _createLessonFromJson(String jsonData) async {
    setState(() => _isLoading = true);
    
    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthSuccess ? authState.user.id : '';
      
      final lessonService = LessonService();
      final lesson = await lessonService.importLessonFromJson(jsonData, userId);
      
      if (mounted) {
        final semantic = Theme.of(context).extension<SemanticColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lesson "${lesson.title}" created successfully!'),
            backgroundColor: semantic.success,
          ),
        );
        Navigator.of(context).pop(lesson);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AppException ? e.getUserMessage() : 'Error creating lesson: $e';
        final semantic = Theme.of(context).extension<SemanticColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: semantic.danger,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLessonFromBuilder({
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> content,
  }) async {
    setState(() => _isLoading = true);
    
    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthSuccess ? authState.user.id : '';
      
      final lessonService = LessonService();
      
      // Create lesson JSON structure
      final lessonJson = {
        'lesson': {
          'title': title,
          'description': description,
          'tags': tags,
          'createdBy': userId,
        },
        'content': content,
      };
      
      final lesson = await lessonService.importLessonFromJson(
        jsonEncode(lessonJson), 
        userId,
      );
      
      if (mounted) {
        final semantic = Theme.of(context).extension<SemanticColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lesson "${lesson.title}" created successfully!'),
            backgroundColor: semantic.success,
          ),
        );
        Navigator.of(context).pop(lesson);
      }
    } catch (e) {
      if (mounted) {
        final msg = e is AppException ? e.getUserMessage() : 'Error creating lesson: $e';
        final semantic = Theme.of(context).extension<SemanticColors>()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: semantic.danger,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Lesson'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LessonCreationGuideScreen(),
              ),
            ),
            icon: const Icon(Icons.help_outline),
            tooltip: 'Lesson Creation Guide',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome),
              text: 'AI Assistant',
            ),
            Tab(
              icon: Icon(Icons.code),
              text: 'JSON Import',
            ),
            Tab(
              icon: Icon(Icons.build),
              text: 'Manual Builder',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating lesson...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAiAssistantTab(),
                EnhancedJsonImportWidget(
                  onImport: _createLessonFromJson,
                ),
                LessonBuilderWidget(
                  initialContentTabIndex: widget.initialBuilderTabIndex,
                  onCreateLesson: _createLessonFromBuilder,
                ),
              ],
            ),
    );
  }

  Widget _buildAiAssistantTab() {
    final semantic = Theme.of(context).extension<SemanticColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: semantic.info),
                        const SizedBox(width: 8),
                        Text(
                          'AI-Assisted Lesson Creation',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: semantic.info,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Fill in your lesson parameters below\n'
                      '2. Generate a customized AI prompt\n'
                      '3. Copy the prompt and use it with ChatGPT, Claude, or any AI tool\n'
                      '4. Import the generated JSON back using the "JSON Import" tab',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Subject Input
            Text(
              'Lesson Subject',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                hintText: 'e.g., Python Variable Types, HTTP Status Codes, CSS Flexbox',
                border: OutlineInputBorder(),
                helperText: 'Be specific - avoid overly broad topics like "Programming" or "Science"',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 24),
            
            // Target Audience
            Text(
              'Prior Knowledge Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'beginner', label: Text('Beginner')),
                ButtonSegment(value: 'intermediate', label: Text('Intermediate')),
                ButtonSegment(value: 'advanced', label: Text('Advanced')),
              ],
              selected: {_targetAudience},
              onSelectionChanged: (selection) {
                setState(() => _targetAudience = selection.first);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Duration Slider
            Text(
              'Estimated Duration: $_durationMinutes minutes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _durationMinutes.toDouble(),
              min: 15,
              max: 120,
              divisions: 21,
              label: '$_durationMinutes min',
              onChanged: (value) {
                setState(() => _durationMinutes = value.round());
              },
            ),
            
            const SizedBox(height: 24),
            
            // Difficulty Level
            Text(
              'Difficulty Level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'beginner', child: Text('Beginner - Basic concepts and definitions')),
                DropdownMenuItem(value: 'intermediate', child: Text('Intermediate - Applied knowledge')),
                DropdownMenuItem(value: 'advanced', child: Text('Advanced - Complex applications')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _difficulty = value);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Content Focus
            Text(
              'Content Focus',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _contentFocus,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'theoretical', child: Text('Theoretical - Theory and understanding')),
                DropdownMenuItem(value: 'practical', child: Text('Practical - Hands-on applications')),
                DropdownMenuItem(value: 'balanced', child: Text('Balanced - Mix of theory and practice')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _contentFocus = value);
              },
            ),
            
            const SizedBox(height: 32),
            
            // Template Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.library_books, color: semantic.warning),
                        const SizedBox(width: 8),
                        Text(
                          'Or Start with a Template',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: semantic.warning,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Browse pre-made templates for common lesson types. Templates include placeholder content that you can customize.',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showTemplateDialog(),
                        icon: const Icon(Icons.library_books),
                        label: const Text('Browse Templates'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Guided Generation Button (multi-prompt)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final params = <String, String>{
                    if (_subjectController.text.trim().isNotEmpty)
                      'subject': _subjectController.text.trim(),
                    'audience': _targetAudience,
                    'duration': _durationMinutes.toString(),
                    'difficulty': _difficulty,
                    'focus': _contentFocus,
                  };
                  context.push(Uri(path: '/guided-generation', queryParameters: params).toString());
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('AI-Guided Generation'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick Generate Button (legacy single-prompt)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _subjectController.text.trim().isEmpty ? null : _generateAndShowPrompt,
                icon: const Icon(Icons.bolt),
                label: const Text('Quick Generate (Single Prompt)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Templates
            const PromptTemplatesWidget(),
          ],
        ),
      ),
    );
  }

  void _generateAndShowPrompt() {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final prompt = AiPromptService.generateLessonCreationPrompt(
      subject: _subjectController.text.trim(),
      targetAudience: _targetAudience,
      durationMinutes: _durationMinutes,
      difficulty: _difficulty,
      contentFocus: _contentFocus,
    );

    Clipboard.setData(ClipboardData(text: prompt));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: semantic.info),
            SizedBox(width: 8),
            Text('AI Prompt Generated'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: semantic.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: semantic.success.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: semantic.success),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Prompt copied to clipboard! Use it with ChatGPT, Claude, or any AI tool.',
                          style: TextStyle(color: semantic.success),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Next steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  '1. Paste this prompt into your AI tool\n'
                  '2. Wait for the JSON response\n'
                  '3. Copy the JSON response\n'
                  '4. Switch to the "JSON Import" tab\n'
                  '5. Paste and import the JSON',
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      prompt,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prompt));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Prompt copied again!')),
              );
            },
            child: const Text('Copy Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Switch to JSON Import tab
              _tabController.animateTo(1);
            },
            child: const Text('Go to JSON Import'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTemplateDialog() {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: semantic.warning.withValues(alpha: 0.12),
                  border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.library_books, color: semantic.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Lesson Templates',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Template selection widget
              Expanded(
                child: TemplateSelectionWidget(
                  onTemplateGenerated: (templateJson) {
                    Navigator.of(context).pop();
                    // Convert to JSON string and import
                    final jsonString = const JsonEncoder.withIndent('  ').convert(templateJson);
                    _createLessonFromJson(jsonString);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
