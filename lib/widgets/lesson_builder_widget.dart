import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class LessonBuilderWidget extends StatefulWidget {
  final Function({
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> content,
  }) onCreateLesson;

  const LessonBuilderWidget({
    super.key,
    required this.onCreateLesson,
  });

  @override
  State<LessonBuilderWidget> createState() => _LessonBuilderWidgetState();
}

class _LessonBuilderWidgetState extends State<LessonBuilderWidget>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  
  late TabController _contentTabController;
  final List<Map<String, dynamic>> _contentItems = [];
  final List<String> _tags = [];
  
  // Content form controllers
  final _termController = TextEditingController();
  final _definitionController = TextEditingController();
  final _exampleController = TextEditingController();
  
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();
  final _explanationController = TextEditingController();
  int _correctAnswer = 0;
  
  final _conceptTitleController = TextEditingController();
  final _conceptDescriptionController = TextEditingController();
  final _conceptKeyPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contentTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _contentTabController.dispose();
    
    _termController.dispose();
    _definitionController.dispose();
    _exampleController.dispose();
    
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _explanationController.dispose();
    
    _conceptTitleController.dispose();
    _conceptDescriptionController.dispose();
    _conceptKeyPointsController.dispose();
    
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _addTermContent() {
    if (_termController.text.trim().isEmpty || _definitionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Term and definition are required')),
      );
      return;
    }

    final termContent = {
      'id': const Uuid().v4(),
      'type': 'term',
      'term': _termController.text.trim(),
      'definition': _definitionController.text.trim(),
      if (_exampleController.text.trim().isNotEmpty)
        'example': _exampleController.text.trim(),
    };

    setState(() {
      _contentItems.add(termContent);
      _termController.clear();
      _definitionController.clear();
      _exampleController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Term added successfully')),
    );
  }

  void _addQuestionContent() {
    if (_questionController.text.trim().isEmpty ||
        _option1Controller.text.trim().isEmpty ||
        _option2Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question and at least 2 options are required')),
      );
      return;
    }

    final options = [
      _option1Controller.text.trim(),
      _option2Controller.text.trim(),
      if (_option3Controller.text.trim().isNotEmpty) _option3Controller.text.trim(),
      if (_option4Controller.text.trim().isNotEmpty) _option4Controller.text.trim(),
    ];

    final questionContent = {
      'id': const Uuid().v4(),
      'type': 'mcq',
      'question': _questionController.text.trim(),
      'options': options,
      'correctIndex': _correctAnswer,
      if (_explanationController.text.trim().isNotEmpty)
        'explanation': _explanationController.text.trim(),
    };

    setState(() {
      _contentItems.add(questionContent);
      _questionController.clear();
      _option1Controller.clear();
      _option2Controller.clear();
      _option3Controller.clear();
      _option4Controller.clear();
      _explanationController.clear();
      _correctAnswer = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Question added successfully')),
    );
  }

  void _addConceptContent() {
    if (_conceptTitleController.text.trim().isEmpty || 
        _conceptDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required')),
      );
      return;
    }

    final conceptContent = {
      'id': const Uuid().v4(),
      'type': 'concept',
      'title': _conceptTitleController.text.trim(),
      'description': _conceptDescriptionController.text.trim(),
      if (_conceptKeyPointsController.text.trim().isNotEmpty)
        'keyPoints': _conceptKeyPointsController.text
            .trim()
            .split('\n')
            .map((point) => point.trim())
            .where((point) => point.isNotEmpty)
            .toList(),
    };

    setState(() {
      _contentItems.add(conceptContent);
      _conceptTitleController.clear();
      _conceptDescriptionController.clear();
      _conceptKeyPointsController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Concept added successfully')),
    );
  }

  void _removeContentItem(int index) {
    setState(() {
      _contentItems.removeAt(index);
    });
  }

  void _reorderContentItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _contentItems.removeAt(oldIndex);
      _contentItems.insert(newIndex, item);
    });
  }

  void _createLesson() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_contentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one content item')),
      );
      return;
    }

    widget.onCreateLesson(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: _tags,
      content: _contentItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Lesson details section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lesson Details',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Lesson Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a lesson title';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Tags section
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _tagController,
                            decoration: const InputDecoration(
                              hintText: 'Add a tag',
                              border: OutlineInputBorder(),
                            ),
                            onFieldSubmitted: (_) => _addTag(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTag,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    
                    if (_tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  onDeleted: () => _removeTag(tag),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content creation section
            SizedBox(
              height: 500, // Fixed height instead of Expanded since we use SingleChildScrollView
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Lesson Content',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Spacer(),
                          Text(
                            '${_contentItems.length} items',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Content type tabs
                      TabBar(
                        controller: _contentTabController,
                        tabs: const [
                          Tab(icon: Icon(Icons.book), text: 'Terms'),
                          Tab(icon: Icon(Icons.quiz), text: 'Questions'),
                          Tab(icon: Icon(Icons.lightbulb), text: 'Concepts'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Content forms
                      Expanded(
                        child: TabBarView(
                          controller: _contentTabController,
                          children: [
                            _buildTermForm(),
                            _buildQuestionForm(),
                            _buildConceptForm(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content items list
            if (_contentItems.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Content Items (${_contentItems.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ReorderableListView.builder(
                          itemCount: _contentItems.length,
                          onReorder: _reorderContentItems,
                          itemBuilder: (context, index) {
                            final item = _contentItems[index];
                            return _buildContentItemTile(item, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Create lesson button
            FilledButton.icon(
              onPressed: _createLesson,
              icon: const Icon(Icons.create),
              label: const Text('Create Lesson'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _termController,
            decoration: const InputDecoration(
              labelText: 'Term',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _definitionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Definition',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _exampleController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Example (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addTermContent,
            icon: const Icon(Icons.add),
            label: const Text('Add Term'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _questionController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Question',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          ...List.generate(4, (index) {
            final controllers = [
              _option1Controller,
              _option2Controller,
              _option3Controller,
              _option4Controller,
            ];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: _correctAnswer,
                    onChanged: (value) {
                      setState(() {
                        _correctAnswer = value!;
                      });
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        labelText: 'Option ${index + 1}${index < 2 ? ' (required)' : ''}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _explanationController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Explanation (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          
          const SizedBox(height: 16),
          
          ElevatedButton.icon(
            onPressed: _addQuestionContent,
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextFormField(
            controller: _conceptTitleController,
            decoration: const InputDecoration(
              labelText: 'Concept Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conceptDescriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conceptKeyPointsController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Key Points (one per line, optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _addConceptContent,
            icon: const Icon(Icons.add),
            label: const Text('Add Concept'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentItemTile(Map<String, dynamic> item, int index) {
    final type = item['type'] as String;
    String title = '';
    String subtitle = '';
    
    switch (type) {
      case 'term':
        title = item['term'] as String;
        subtitle = item['definition'] as String;
        break;
      case 'mcq':
        title = item['question'] as String;
        subtitle = '${(item['options'] as List).length} options';
        break;
      case 'concept':
        title = item['title'] as String;
        subtitle = item['description'] as String;
        break;
    }

    return Card(
      key: ValueKey(item['id']),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_getIconForType(type)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeContentItem(index),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'term':
        return Icons.book;
      case 'mcq':
        return Icons.quiz;
      case 'concept':
        return Icons.lightbulb;
      default:
        return Icons.help;
    }
  }
}
