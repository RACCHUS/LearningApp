import 'package:flutter/material.dart';
import '../../models/community/community_resource.dart';
import '../../services/community/community_resource_service.dart';

/// Screen allowing educators to author, edit, and submit standalone resources
/// with authoritative citations and AI draft assistance (ECO-06, Phase 3).
class ResourceAuthoringScreen extends StatefulWidget {
  final CommunityResourceService resourceService;
  final String authorId;
  final String authorName;
  final String? authorHeadline;
  final CommunityResource? existingResource;

  const ResourceAuthoringScreen({
    super.key,
    required this.resourceService,
    required this.authorId,
    required this.authorName,
    this.authorHeadline,
    this.existingResource,
  });

  @override
  State<ResourceAuthoringScreen> createState() =>
      _ResourceAuthoringScreenState();
}

class _ResourceAuthoringScreenState extends State<ResourceAuthoringScreen> {
  late CommunityResourceContentType _contentType;
  late TextEditingController _titleController;
  late TextEditingController _topicController;
  late TextEditingController _descController;
  late TextEditingController _lessonMarkdownController;
  late String _selectedSubjectId;

  final List<ResourceCitation> _citations = [];
  final List<Map<String, String>> _flashcardInputs = [];
  final List<Map<String, String>> _guideSectionInputs = [];

  bool _isAiAssisted = false;
  bool _isSaving = false;

  static const List<Map<String, String>> _canonicalSubjects = [
    {'id': 'workplace_safety', 'name': 'Workplace Safety & OSHA'},
    {'id': 'foundational_literacy', 'name': 'Foundational Literacy & ABE'},
    {'id': 'florida_licensure', 'name': 'Florida Professional Licensure'},
    {'id': 'food_and_health', 'name': 'Food Safety & Life Health'},
  ];

  @override
  void initState() {
    super.initState();
    final res = widget.existingResource;
    _contentType = res?.contentType ?? CommunityResourceContentType.lesson;
    _titleController = TextEditingController(text: res?.title ?? '');
    _topicController = TextEditingController(text: res?.topic ?? '');
    _descController = TextEditingController(text: res?.description ?? '');
    _lessonMarkdownController =
        TextEditingController(text: res?.lessonMarkdown ?? '');
    _selectedSubjectId = res?.subjectId ?? _canonicalSubjects.first['id']!;
    _isAiAssisted = res?.isAiAssisted ?? false;

    if (res != null) {
      _citations.addAll(res.citations);
      for (final fc in res.flashcards) {
        _flashcardInputs.add({
          'front': fc.front,
          'back': fc.back,
          'tip': fc.tip ?? '',
        });
      }
      for (final s in res.guideSections) {
        _guideSectionInputs.add({
          'heading': s.heading,
          'body': s.bodyMarkdown,
          'takeaway': s.keyTakeaway ?? '',
        });
      }
    } else {
      // Default empty items
      _flashcardInputs.add({'front': '', 'back': '', 'tip': ''});
      _guideSectionInputs.add({'heading': '', 'body': '', 'takeaway': ''});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _descController.dispose();
    _lessonMarkdownController.dispose();
    super.dispose();
  }

  Future<void> _handleAiDraft() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic first to generate an AI draft.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final draft = await widget.resourceService.generateAiDraft(
        topic: topic,
        subjectId: _selectedSubjectId,
        contentType: _contentType,
        authorId: widget.authorId,
        authorName: widget.authorName,
        authorHeadline: widget.authorHeadline,
      );

      setState(() {
        _titleController.text = draft.title;
        _descController.text = draft.description;
        _isAiAssisted = true;
        _citations.clear();
        _citations.addAll(draft.citations);

        if (draft.lessonMarkdown != null) {
          _lessonMarkdownController.text = draft.lessonMarkdown!;
        }

        _flashcardInputs.clear();
        for (final fc in draft.flashcards) {
          _flashcardInputs.add({
            'front': fc.front,
            'back': fc.back,
            'tip': fc.tip ?? '',
          });
        }

        _guideSectionInputs.clear();
        for (final gs in draft.guideSections) {
          _guideSectionInputs.add({
            'heading': gs.heading,
            'body': gs.bodyMarkdown,
            'takeaway': gs.keyTakeaway ?? '',
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI draft generated! Review and verify citations before submitting.'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating AI draft: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSave({bool submitForReview = false}) async {
    final title = _titleController.text.trim();
    final topic = _topicController.text.trim();
    if (title.isEmpty || topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and topic are required.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final id = widget.existingResource?.id ??
          'res_${now.millisecondsSinceEpoch}_${widget.authorId.hashCode.abs()}';

      final flashcards = _flashcardInputs
          .where((f) => f['front']!.isNotEmpty && f['back']!.isNotEmpty)
          .map((f) => FlashcardCard(
                id: '${id}_fc_${f.hashCode.abs()}',
                front: f['front']!,
                back: f['back']!,
                tip: f['tip']!.isNotEmpty ? f['tip'] : null,
              ))
          .toList();

      final guideSections = _guideSectionInputs
          .where((s) => s['heading']!.isNotEmpty && s['body']!.isNotEmpty)
          .map((s) => StudyGuideSection(
                id: '${id}_gs_${s.hashCode.abs()}',
                heading: s['heading']!,
                bodyMarkdown: s['body']!,
                keyTakeaway: s['takeaway']!.isNotEmpty ? s['takeaway'] : null,
              ))
          .toList();

      final resource = CommunityResource(
        id: id,
        authorId: widget.authorId,
        authorName: widget.authorName,
        authorHeadline: widget.authorHeadline,
        subjectId: _selectedSubjectId,
        topic: topic,
        title: title,
        description: _descController.text.trim(),
        contentType: _contentType,
        status: CommunityResourceStatus.draft,
        license: 'CC-BY-4.0',
        isAiAssisted: _isAiAssisted,
        citations: List.from(_citations),
        lessonMarkdown: _lessonMarkdownController.text.trim().isNotEmpty
            ? _lessonMarkdownController.text.trim()
            : null,
        flashcards: flashcards,
        guideSections: guideSections,
        createdAt: widget.existingResource?.createdAt ?? now,
        updatedAt: now,
      );

      final saved = await widget.resourceService.saveResourceDraft(resource);

      if (submitForReview) {
        await widget.resourceService.submitResourceForReview(saved.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(submitForReview
                ? 'Resource submitted for editorial review!'
                : 'Draft saved successfully.'),
            backgroundColor: submitForReview ? Colors.green : Colors.blue,
          ),
        );
        Navigator.of(context).pop(saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving resource: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addCitationDialog() {
    final authCodeController = TextEditingController();
    final titleController = TextEditingController();
    final jurisController = TextEditingController(text: 'US-Federal');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Regulatory Citation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: authCodeController,
              decoration: const InputDecoration(
                labelText: 'Authority Code',
                hintText: 'e.g. 29 CFR 1910.1200 or FAC 61J2',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Standard / Title',
                hintText: 'e.g. Hazard Communication Standard',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: jurisController,
              decoration: const InputDecoration(
                labelText: 'Jurisdiction',
                hintText: 'e.g. US OSHA or State of Florida',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (authCodeController.text.trim().isNotEmpty) {
                setState(() {
                  _citations.add(ResourceCitation(
                    id: 'cit_${DateTime.now().millisecondsSinceEpoch}',
                    authorityCode: authCodeController.text.trim(),
                    title: titleController.text.trim(),
                    jurisdiction: jurisController.text.trim(),
                    verified: true,
                  ));
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add Citation'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingResource == null
            ? 'Author New Resource'
            : 'Edit Resource'),
        actions: [
          TextButton.icon(
            key: const Key('ai_draft_button'),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI Draft'),
            onPressed: _isSaving ? null : _handleAiDraft,
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content Type Selector
                  Text('Resource Format', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<CommunityResourceContentType>(
                    segments: const [
                      ButtonSegment(
                        value: CommunityResourceContentType.lesson,
                        label: Text('Lesson'),
                        icon: Icon(Icons.menu_book),
                      ),
                      ButtonSegment(
                        value: CommunityResourceContentType.flashcardSet,
                        label: Text('Flashcards'),
                        icon: Icon(Icons.style),
                      ),
                      ButtonSegment(
                        value: CommunityResourceContentType.studyGuide,
                        label: Text('Guide'),
                        icon: Icon(Icons.auto_stories),
                      ),
                    ],
                    selected: {_contentType},
                    onSelectionChanged: (newSelection) {
                      setState(() => _contentType = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Canonical Subject Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Canonical Subject',
                      border: OutlineInputBorder(),
                    ),
                    items: _canonicalSubjects.map((s) {
                      return DropdownMenuItem(
                        value: s['id'],
                        child: Text(s['name']!),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSubjectId = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Topic & Title
                  TextField(
                    key: const Key('resource_topic_field'),
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Specific Topic',
                      hintText: 'e.g. PPE Selection or Right-of-Way Rules',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('resource_title_field'),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Resource Title',
                      hintText: 'e.g. PPE Selection & Inspection Checklist',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      hintText: 'Brief summary for learners browsing resources',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Citations Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Authoritative Citations',
                          style: theme.textTheme.titleSmall),
                      TextButton.icon(
                        key: const Key('add_citation_button'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Citation'),
                        onPressed: _addCitationDialog,
                      ),
                    ],
                  ),
                  if (_citations.isEmpty)
                    Text(
                      'No citations attached yet. Attaching regulatory standards boosts resource credibility.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _citations.map((c) {
                        return Chip(
                          label: Text('${c.authorityCode} (${c.jurisdiction})'),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() => _citations.remove(c));
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Dynamic Content Form
                  if (_contentType == CommunityResourceContentType.lesson ||
                      _contentType == CommunityResourceContentType.cheatSheet) ...[
                    Text('Lesson Content (Markdown)',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('lesson_content_field'),
                      controller: _lessonMarkdownController,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        hintText: 'Write your micro-lesson content here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else if (_contentType ==
                      CommunityResourceContentType.flashcardSet) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Flashcard Cards',
                            style: theme.textTheme.titleSmall),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Card'),
                          onPressed: () {
                            setState(() {
                              _flashcardInputs
                                  .add({'front': '', 'back': '', 'tip': ''});
                            });
                          },
                        ),
                      ],
                    ),
                    ..._flashcardInputs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final card = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Card #${i + 1}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  if (_flashcardInputs.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _flashcardInputs.removeAt(i);
                                        });
                                      },
                                    ),
                                ],
                              ),
                              TextField(
                                decoration: const InputDecoration(
                                    labelText: 'Front (Question / Prompt)'),
                                controller:
                                    TextEditingController(text: card['front']),
                                onChanged: (val) => card['front'] = val,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                decoration: const InputDecoration(
                                    labelText: 'Back (Answer / Explanation)'),
                                controller:
                                    TextEditingController(text: card['back']),
                                onChanged: (val) => card['back'] = val,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Guide Sections',
                            style: theme.textTheme.titleSmall),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Section'),
                          onPressed: () {
                            setState(() {
                              _guideSectionInputs.add(
                                  {'heading': '', 'body': '', 'takeaway': ''});
                            });
                          },
                        ),
                      ],
                    ),
                    ..._guideSectionInputs.asMap().entries.map((entry) {
                      final i = entry.key;
                      final section = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Section #${i + 1}',
                                  style: theme.textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.bold)),
                              TextField(
                                decoration: const InputDecoration(
                                    labelText: 'Heading'),
                                controller: TextEditingController(
                                    text: section['heading']),
                                onChanged: (val) => section['heading'] = val,
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Body Markdown'),
                                controller:
                                    TextEditingController(text: section['body']),
                                onChanged: (val) => section['body'] = val,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('save_draft_button'),
                          onPressed: _isSaving
                              ? null
                              : () => _handleSave(submitForReview: false),
                          child: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('submit_review_button'),
                          onPressed: _isSaving
                              ? null
                              : () => _handleSave(submitForReview: true),
                          child: const Text('Submit for Review'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

