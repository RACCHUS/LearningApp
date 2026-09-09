import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_prompt_service.dart';
import '../widgets/lesson_builder_widget.dart';

/// Enhanced lesson creation screen with multiple creation modes
class EnhancedLessonCreationScreen extends ConsumerStatefulWidget {
  const EnhancedLessonCreationScreen({super.key});

  @override
  ConsumerState<EnhancedLessonCreationScreen> createState() =>
      _EnhancedLessonCreationScreenState();
}

class _EnhancedLessonCreationScreenState
    extends ConsumerState<EnhancedLessonCreationScreen> {
  CreationMode _selectedMode = CreationMode.modeSelection;
  
  // AI Assistant form data
  final _subjectController = TextEditingController();
  String _targetAudience = 'beginner';
  int _durationMinutes = 30;
  String _difficulty = 'beginner';
  String _contentFocus = 'balanced';

  @override
  void dispose() {
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Lesson'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_selectedMode) {
      case CreationMode.modeSelection:
        return _buildModeSelection();
      case CreationMode.aiAssisted:
        return _buildAiAssistedCreation();
      case CreationMode.jsonImport:
        return _buildJsonImport();
      case CreationMode.manualBuilder:
        return LessonBuilderWidget(
          onCreateLesson: ({
            required String title,
            required String description,
            required List<String> tags,
            required List<Map<String, dynamic>> content,
          }) {
            // Handle lesson creation here
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lesson created successfully!')),
            );
          },
        );
      case CreationMode.templateLibrary:
        return _buildTemplateLibrary();
    }
  }

  Widget _buildModeSelection() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'How would you like to create your lesson?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildModeOption(
              icon: Icons.smart_toy,
              title: 'AI-Assisted Creation',
              description: 'Generate lesson content with AI prompts\nbased on your subject and preferences',
              mode: CreationMode.aiAssisted,
              color: Colors.purple,
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              icon: Icons.upload_file,
              title: 'JSON Import',
              description: 'Import from existing JSON file\nwith enhanced validation',
              mode: CreationMode.jsonImport,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              icon: Icons.build,
              title: 'Manual Builder',
              description: 'Build step-by-step with\nvisual form editor',
              mode: CreationMode.manualBuilder,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildModeOption(
              icon: Icons.library_books,
              title: 'Template Library',
              description: 'Start from proven templates\nfor common subjects',
              mode: CreationMode.templateLibrary,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required IconData icon,
    required String title,
    required String description,
    required CreationMode mode,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => setState(() => _selectedMode = mode),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiAssistedCreation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedMode = CreationMode.modeSelection),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI-Assisted Lesson Creation',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'How it works',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue[700],
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
                      '4. Import the generated JSON back into the app',
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
              'Target Audience',
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
                DropdownMenuItem(value: 'conceptual', child: Text('Conceptual - Theory and understanding')),
                DropdownMenuItem(value: 'practical', child: Text('Practical - Hands-on applications')),
                DropdownMenuItem(value: 'balanced', child: Text('Balanced - Mix of theory and practice')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _contentFocus = value);
              },
            ),
            
            const SizedBox(height: 32),
            
            // Generate Prompt Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _subjectController.text.trim().isEmpty ? null : _generateAndCopyPrompt,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI Prompt'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Additional Options
            OutlinedButton.icon(
              onPressed: _showPromptTemplates,
              icon: const Icon(Icons.text_snippet),
              label: const Text('View Prompt Templates'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJsonImport() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedMode = CreationMode.modeSelection),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'JSON Import (Enhanced)',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Icon(Icons.construction, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Enhanced JSON Import Coming Soon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will include:\n'
              '• Enhanced validation with helpful error messages\n'
              '• Live preview of imported content\n'
              '• Automatic content quality suggestions\n'
              '• Schema validation and auto-completion',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => setState(() => _selectedMode = CreationMode.manualBuilder),
              child: const Text('Use Manual Builder for Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateLibrary() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedMode = CreationMode.modeSelection),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Template Library',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Icon(Icons.library_books, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Template Library Coming Soon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'This will include:\n'
              '• Subject-specific templates (Programming, Science, etc.)\n'
              '• Industry standard formats (CompTIA, etc.)\n'
              '• Community-shared templates\n'
              '• Custom template creation and sharing',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => setState(() => _selectedMode = CreationMode.aiAssisted),
              child: const Text('Try AI-Assisted Creation'),
            ),
          ],
        ),
      ),
    );
  }

  void _generateAndCopyPrompt() {
    final prompt = AiPromptService.generateLessonCreationPrompt(
      subject: _subjectController.text.trim(),
      targetAudience: _targetAudience,
      durationMinutes: _durationMinutes,
      difficulty: _difficulty,
      contentFocus: _contentFocus,
    );

    Clipboard.setData(ClipboardData(text: prompt));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('AI prompt copied to clipboard!')),
          ],
        ),
        action: SnackBarAction(
          label: 'View Prompt',
          onPressed: () => _showPromptDialog(prompt),
        ),
      ),
    );
  }

  void _showPromptDialog(String prompt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generated AI Prompt'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              prompt,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: prompt));
              Navigator.of(context).pop();
            },
            child: const Text('Copy Again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPromptTemplates() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Prompt Templates'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTemplateOption(
                'Content Improvement',
                'Analyze and improve existing lesson content',
                () => _copyTemplate('improvement'),
              ),
              _buildTemplateOption(
                'Series Splitting',
                'Break broad topics into focused lesson series',
                () => _copyTemplate('splitting'),
              ),
              _buildTemplateOption(
                'JSON Validation',
                'Validate and fix lesson JSON structure',
                () => _copyTemplate('validation'),
              ),
              _buildTemplateOption(
                'Subject Templates',
                'Generate templates for specific subject areas',
                () => _copyTemplate('templates'),
              ),
            ],
          ),
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

  Widget _buildTemplateOption(String title, String description, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.copy),
      onTap: () {
        onTap();
        Navigator.of(context).pop();
      },
    );
  }

  void _copyTemplate(String type) {
    String prompt;
    switch (type) {
      case 'improvement':
        prompt = AiPromptService.generateContentImprovementPrompt('[PASTE_YOUR_LESSON_CONTENT_HERE]');
        break;
      case 'splitting':
        prompt = AiPromptService.generateSeriesSplittingPrompt('[ENTER_BROAD_TOPIC_HERE]');
        break;
      case 'validation':
        prompt = AiPromptService.generateValidationPrompt('[PASTE_YOUR_JSON_HERE]');
        break;
      case 'templates':
        prompt = AiPromptService.generateTemplatePrompt('[ENTER_SUBJECT_AREA_HERE]');
        break;
      default:
        prompt = 'Unknown template type';
    }

    Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$type template copied to clipboard!')),
    );
  }
}

enum CreationMode {
  modeSelection,
  aiAssisted,
  jsonImport,
  manualBuilder,
  templateLibrary,
}
