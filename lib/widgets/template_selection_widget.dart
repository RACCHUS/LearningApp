import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/lesson_template_service.dart';

class TemplateSelectionWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onTemplateGenerated;

  const TemplateSelectionWidget({
    Key? key,
    required this.onTemplateGenerated,
  }) : super(key: key);

  @override
  State<TemplateSelectionWidget> createState() => _TemplateSelectionWidgetState();
}

class _TemplateSelectionWidgetState extends State<TemplateSelectionWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategory = 'Programming';
  LessonTemplate? _selectedTemplate;
  Map<String, String> _placeholderValues = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _showPreview = false;
  Map<String, dynamic>? _generatedTemplate;

  @override
  void initState() {
    super.initState();
    final categories = LessonTemplateService.getAllTemplates().keys.toList();
    _tabController = TabController(length: categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = LessonTemplateService.getAllTemplates();
    final categories = templates.keys.toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Templates',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a template to get started quickly with pre-structured content',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Category tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            onTap: (index) {
              setState(() {
                _selectedCategory = categories[index];
                _selectedTemplate = null;
                _placeholderValues.clear();
                _controllers.clear();
                _showPreview = false;
              });
            },
            tabs: categories.map((category) => Tab(text: category)).toList(),
          ),
          
          const SizedBox(height: 20),
          
          Expanded(
            child: _selectedTemplate == null
                ? _buildTemplateGrid()
                : _buildCustomizationView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    final templates = LessonTemplateService.getAllTemplates()[_selectedCategory] ?? [];
    
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(LessonTemplate template) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _selectTemplate(template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                template.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  _buildDifficultyChip(template.difficulty),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${template.estimatedDuration}m',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.quiz, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${template.contentStructure.values.fold(0, (sum, count) => sum + count)} items',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        color = Colors.green;
        break;
      case 'intermediate':
        color = Colors.orange;
        break;
      case 'advanced':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCustomizationView() {
    return Column(
      children: [
        // Header with back button
        Row(
          children: [
            IconButton(
              onPressed: () => setState(() {
                _selectedTemplate = null;
                _placeholderValues.clear();
                _controllers.clear();
                _showPreview = false;
              }),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                _selectedTemplate!.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!_showPreview)
              ElevatedButton.icon(
                onPressed: _canGenerateTemplate() ? _generateTemplate : null,
                icon: const Icon(Icons.visibility),
                label: const Text('Preview'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => widget.onTemplateGenerated(_generatedTemplate!),
                icon: const Icon(Icons.check),
                label: const Text('Use Template'),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Expanded(
          child: _showPreview
              ? _buildPreviewView()
              : _buildPlaceholderForm(),
        ),
      ],
    );
  }

  Widget _buildPlaceholderForm() {
    final placeholders = _selectedTemplate!.getPlaceholders();
    final suggestions = _selectedTemplate!.getPlaceholderSuggestions();
    
    if (placeholders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'This template is ready to use!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('No customization needed.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _generatedTemplate = _selectedTemplate!.template;
                widget.onTemplateGenerated(_generatedTemplate!);
              },
              child: const Text('Use Template'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Text(
          'Customize Template',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fill in the placeholders to customize your lesson template:',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        
        ...placeholders.map((placeholder) => _buildPlaceholderField(
          placeholder,
          suggestions[placeholder] ?? [],
        )),
      ],
    );
  }

  Widget _buildPlaceholderField(String placeholder, List<String> suggestions) {
    if (!_controllers.containsKey(placeholder)) {
      _controllers[placeholder] = TextEditingController();
      _controllers[placeholder]!.addListener(() {
        setState(() {
          _placeholderValues[placeholder] = _controllers[placeholder]!.text;
        });
      });
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            placeholder.replaceAll('_', ' ').toLowerCase(),
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          
          if (suggestions.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: suggestions.map((suggestion) => ActionChip(
                label: Text(suggestion),
                onPressed: () {
                  _controllers[placeholder]!.text = suggestion;
                  setState(() {
                    _placeholderValues[placeholder] = suggestion;
                  });
                },
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          
          TextFormField(
            controller: _controllers[placeholder],
            decoration: InputDecoration(
              hintText: 'Enter ${placeholder.replaceAll('_', ' ').toLowerCase()}',
              border: const OutlineInputBorder(),
              suffixIcon: _placeholderValues[placeholder]?.isNotEmpty == true
                  ? IconButton(
                      onPressed: () {
                        _controllers[placeholder]!.clear();
                        setState(() {
                          _placeholderValues.remove(placeholder);
                        });
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Template Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _showPreview = false),
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Copy to clipboard
                Clipboard.setData(ClipboardData(
                  text: const JsonEncoder.withIndent('  ').convert(_generatedTemplate),
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Template copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(
                const JsonEncoder.withIndent('  ').convert(_generatedTemplate),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _selectTemplate(LessonTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _placeholderValues.clear();
      _controllers.clear();
      _showPreview = false;
    });
  }

  bool _canGenerateTemplate() {
    if (_selectedTemplate == null) return false;
    final placeholders = _selectedTemplate!.getPlaceholders();
    return placeholders.every((placeholder) => 
        _placeholderValues[placeholder]?.isNotEmpty == true);
  }

  void _generateTemplate() {
    if (_selectedTemplate == null) return;
    
    setState(() {
      _generatedTemplate = _selectedTemplate!.generateCustomTemplate(_placeholderValues);
      _showPreview = true;
    });
  }
}
