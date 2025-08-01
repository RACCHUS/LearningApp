import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/models/content_types.dart';
import 'package:learning_pwa/providers/lesson_creation_provider.dart';
import 'package:learning_pwa/widgets/concept_content_widget.dart';
import 'package:learning_pwa/widgets/content_list_item.dart';
import 'package:learning_pwa/widgets/question_content_widget.dart';
import 'package:learning_pwa/widgets/term_content_widget.dart';

class ContentManagementPanel extends ConsumerStatefulWidget {
  const ContentManagementPanel({super.key});

  @override
  ConsumerState<ContentManagementPanel> createState() => _ContentManagementPanelState();
}

class _ContentManagementPanelState extends ConsumerState<ContentManagementPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final Map<int, GlobalKey> _contentFormKeys = {
    0: GlobalKey(),
    1: GlobalKey(),
    2: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    }
  }

  void _addContent(LessonContent content) {
    ref.read(lessonCreationProvider.notifier).addContent(content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content added successfully')),
      );
    }
  }

  void _updateContent(String contentId, LessonContent updatedContent) {
    final notifier = ref.read(lessonCreationProvider.notifier);
    notifier.removeContent(contentId);
    notifier.addContent(updatedContent);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content updated successfully')),
      );
    }
  }

  void _removeContent(String contentId) {
    ref.read(lessonCreationProvider.notifier).removeContent(contentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Content removed')),
      );
    }
  }

  Widget _buildContentForm() {
    switch (_selectedTabIndex) {
      case 0: // Terms
        return _buildTermForm();
      case 1: // Questions
        return _buildQuestionForm();
      case 2: // Concepts
        return _buildConceptForm();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTermForm() {
    return TermContentWidget(
      key: _contentFormKeys[0],
      onSave: _addContent,
    );
  }

  Widget _buildQuestionForm() {
    return QuestionContentWidget(
      key: _contentFormKeys[1],
      onSave: _addContent,
    );
  }

  Widget _buildConceptForm() {
    return ConceptContentWidget(
      key: _contentFormKeys[2],
      onSave: _addContent,
    );
  }

  Widget _buildContentList() {
    final content = ref.watch(lessonCreationProvider).content;
    final filteredContent = content.where((item) {
      return switch (_selectedTabIndex) {
        0 => item is TermContent,
        1 => item is QuestionContent,
        2 => item is ConceptContent,
        _ => false,
      };
    }).toList();

    if (filteredContent.isEmpty) {
      return const Center(
        child: Text('No content yet. Add some using the form above.'),
      );
    }

    return ListView.builder(
      itemCount: filteredContent.length,
      itemBuilder: (context, index) {
        final item = filteredContent[index];
        return ContentListItem(
          content: item,
          onEdit: () => _showEditDialog(item),
          onDelete: () => _removeContent(_getContentId(item)),
        );
      },
    );
  }

  void _showEditDialog(LessonContent content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Content'),
        content: SizedBox(
          width: double.maxFinite,
          child: _buildEditForm(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(LessonContent content) {
    return switch (content) {
      TermContent termContent => TermContentWidget(
          initialContent: termContent,
          onSave: (updated) {
            _updateContent(content.id, updated);
            if (mounted) Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(context),
          onDelete: () {
            _removeContent(content.id);
            if (mounted) Navigator.pop(context);
          },
        ),
      QuestionContent questionContent => QuestionContentWidget(
          initialContent: questionContent,
          onSave: (updated) {
            _updateContent(content.id, updated);
            if (mounted) Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(context),
          onDelete: () {
            _removeContent(content.id);
            if (mounted) Navigator.pop(context);
          },
        ),
      ConceptContent conceptContent => ConceptContentWidget(
          initialContent: conceptContent,
          onSave: (updated) {
            _updateContent(content.id, updated);
            if (mounted) Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(context),
          onDelete: () {
            _removeContent(content.id);
            if (mounted) Navigator.pop(context);
          },
        ),
      _ => const Text('Unsupported content type'),
    };
  }

  String _getContentId(LessonContent content) {
    return switch (content) {
      TermContent() => content.id,
      QuestionContent() => content.id,
      ConceptContent() => content.id,
      _ => throw UnimplementedError('Unknown content type'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.abc), text: 'Terms'),
            Tab(icon: Icon(Icons.quiz), text: 'Questions'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Concepts'),
          ],
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildContentForm(),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Content List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: _buildContentList(),
        ),
      ],
    );
  }
}
