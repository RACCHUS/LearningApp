import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_target.dart';
import '../../models/taxonomy/taxonomy.dart';
import '../../providers/taxonomy_provider.dart';
import '../../providers/learning_target_provider.dart';
import '../../theme/design_tokens.dart';

/// Custom learning goals remain private drafts. Catalog examples are reference
/// suggestions; choosing one never makes a user's copy "official".
class CreateTargetDialog extends ConsumerStatefulWidget {
  final TargetType? initialType;

  const CreateTargetDialog({super.key, this.initialType});

  static Future<LearningTarget?> show(BuildContext context, {TargetType? initialType}) {
    return showDialog<LearningTarget>(
      context: context,
      builder: (context) => CreateTargetDialog(initialType: initialType),
    );
  }

  @override
  ConsumerState<CreateTargetDialog> createState() => _CreateTargetDialogState();
}

class _CreateTargetDialogState extends ConsumerState<CreateTargetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _providerController;
  late TargetType _selectedType;
  LearningTarget? _selectedExample;
  Timer? _taxonomyDebounce;
  String _taxonomyQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? TargetType.career;
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _providerController = TextEditingController();
  }

  @override
  void dispose() {
    _taxonomyDebounce?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  void _applyExample(LearningTarget example) {
    setState(() {
      _selectedExample = example;
      _titleController.text = example.title;
      _providerController.text = example.providerName ??
          example.institutionName ?? '';
      _descController.text = example.description ?? '';
    });
  }

  void _queueTaxonomySearch(String value) {
    _taxonomyDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3 ||
        (_selectedType != TargetType.career &&
            _selectedType != TargetType.academicProgram)) {
      if (_taxonomyQuery.isNotEmpty) {
        setState(() => _taxonomyQuery = '');
      }
      return;
    }
    _taxonomyDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _taxonomyQuery = query);
    });
  }

  void _applyTaxonomyExample(TaxonomySearchMatch match) {
    _taxonomyDebounce?.cancel();
    setState(() {
      _selectedExample = null; // A classification is not a published course.
      _taxonomyQuery = '';
      _titleController.text = match.title;
      if (match.description != null && match.description!.trim().isNotEmpty) {
        _descController.text = match.description!;
      }
    });
  }

  Future<void> _openExisting() async {
    final example = _selectedExample;
    if (example == null) return;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/target/${example.id}');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = ref.read(learningTargetServiceProvider);
    final target = await service.createTarget(
      title: _titleController.text.trim(),
      targetType: _selectedType,
      description: _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null,
      providerName: _selectedType != TargetType.academicProgram &&
              _providerController.text.trim().isNotEmpty
          ? _providerController.text.trim()
          : null,
      institutionName: _selectedType == TargetType.academicProgram &&
              _providerController.text.trim().isNotEmpty
          ? _providerController.text.trim()
          : null,
    );

    if (!mounted) return;
    if (target != null) {
      final router = GoRouter.of(context);
      ref.invalidate(targetsListProvider);
      Navigator.of(context).pop(target);
      router.push('/target/${target.id}');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not save a private goal. Please sign in and check your connection.';
      });
    }
  }

  List<LearningTarget> _titleMatches(List<LearningTarget> targets) {
    final query = _titleController.text.trim().toLowerCase();
    final filtered = targets.where((target) =>
        query.isEmpty || target.title.toLowerCase().contains(query)).toList();
    return filtered.take(4).toList();
  }

  List<String> _textSuggestions(
    List<LearningTarget> targets,
    String Function(LearningTarget) extract,
    String current,
  ) {
    final filter = current.trim().toLowerCase();
    final seen = <String>{};
    final result = <String>[];
    for (final target in targets) {
      final value = extract(target).trim();
      if (value.isEmpty ||
          !seen.add(value.toLowerCase()) ||
          (filter.isNotEmpty && !value.toLowerCase().contains(filter))) {
        continue;
      }
      result.add(value);
      if (result.length == 4) break;
    }
    return result;
  }

  Widget _suggestionChips({
    required String heading,
    required List<String> values,
    required ValueChanged<String> onSelected,
    required String keyPrefix,
    int maxLabelLength = 60,
  }) {
    if (values.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: DesignTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: DesignTokens.space1),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (var i = 0; i < values.length; i++)
                ActionChip(
                  key: Key('$keyPrefix-$i'),
                  label: Text(
                    values[i].length > maxLabelLength
                        ? '${values[i].substring(0, maxLabelLength)}…'
                        : values[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  tooltip: values[i],
                  onPressed: () => onSelected(values[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestionsAsync = ref.watch(targetSuggestionsProvider(_selectedType));
    final catalog = suggestionsAsync.valueOrNull ?? const <LearningTarget>[];
    final taxonomyAsync = _taxonomyQuery.length >= 3
        ? ref.watch(taxonomySearchProvider(_taxonomyQuery))
        : null;
    final taxonomyMatches = (taxonomyAsync?.valueOrNull ??
            const <TaxonomySearchMatch>[])
        .where((match) {
      if (_selectedType == TargetType.career) {
        return match.kind == TaxonomyItemKind.occupation &&
            (match.level == 'detailed_occupation' ||
                match.level == 'onet_extension');
      }
      if (_selectedType == TargetType.academicProgram) {
        return match.kind == TaxonomyItemKind.cipProgram &&
            match.level == 'program';
      }
      return false;
    }).take(4).toList();

    final providerSuggestions = _textSuggestions(
      catalog,
      (target) => target.providerName ?? target.institutionName ?? '',
      _providerController.text,
    );
    final descriptionSuggestions = _textSuggestions(
      catalog,
      (target) => target.description ?? '',
      _descController.text,
    );

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: DesignTokens.space3),
          const Flexible(child: Text('Create Learning Goal')),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Text(_errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: DesignTokens.space3),
                ],
                DropdownButtonFormField<TargetType>(
                  key: const Key('goal-type'),
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Goal Type',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                  // These are the six valid database target types. Catalog
                  // examples below update whenever the type changes.
                  items: [
                    for (final type in TargetType.values)
                      DropdownMenuItem(value: type, child: Text(type.displayName)),
                  ],
                  onChanged: (type) {
                    if (type != null) {
                      setState(() {
                        _selectedType = type;
                        _selectedExample = null;
                        _taxonomyQuery = '';
                        _taxonomyDebounce?.cancel();
                      });
                    }
                  },
                ),
                const SizedBox(height: DesignTokens.space3),
                TextFormField(
                  key: const Key('goal-title'),
                  controller: _titleController,
                  onChanged: (value) {
                    setState(() => _selectedExample = null);
                    _queueTaxonomySearch(value);
                  },
                  decoration: InputDecoration(
                    labelText: 'Title or Target Role',
                    hintText: _selectedType == TargetType.career
                        ? 'e.g., Senior Full-Stack Engineer'
                        : _selectedType == TargetType.certification
                            ? 'e.g., CompTIA Security+'
                            : _selectedType == TargetType.standardizedExam
                                ? 'e.g., USMLE Step 1'
                                : 'What would you like to learn?',
                    prefixIcon: const Icon(Icons.edit_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Please enter a title'
                          : null,
                ),
                if (catalog.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.space2),
                  Text('Suggestions from the learning catalog',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  for (final example in _titleMatches(catalog))
                    ListTile(
                      key: Key('goal-title-suggestion-${example.id}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        example.isOfficial ? Icons.verified_outlined
                            : Icons.people_outline,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(example.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(example.sourceLabel),
                      trailing: const Icon(Icons.add, size: 18),
                      onTap: () => _applyExample(example),
                    ),
                ] else if (suggestionsAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(DesignTokens.space2),
                    child: LinearProgressIndicator(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: DesignTokens.space2),
                    child: Text(
                      'No reviewed examples for this type yet. Enter your own.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (taxonomyMatches.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.space2),
                  Text('Matches from official occupation / program classifications',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  for (final item in taxonomyMatches)
                    ListTile(
                      key: Key('goal-taxonomy-suggestion-${item.code}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(item.title, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(_selectedType == TargetType.career
                          ? 'BLS / O*NET SOC reference · ${item.code}'
                          : 'NCES CIP program reference · ${item.code}'),
                      onTap: () => _applyTaxonomyExample(item),
                    ),
                ],
                if (_selectedExample != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('goal-open-existing'),
                      onPressed: _openExisting,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open this existing catalog goal instead'),
                    ),
                  ),
                const SizedBox(height: DesignTokens.space3),
                TextFormField(
                  key: const Key('goal-provider'),
                  controller: _providerController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _selectedType == TargetType.certification
                        ? 'Certification Provider / Body (Optional)'
                        : _selectedType == TargetType.academicProgram
                            ? 'University / Institution (Optional)'
                            : 'Authority / Organization (Optional)',
                    prefixIcon: const Icon(Icons.business_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                ),
                _suggestionChips(
                  heading: 'Organization suggestions',
                  values: providerSuggestions,
                  keyPrefix: 'goal-provider-suggestion',
                  onSelected: (value) => setState(() =>
                      _providerController.text = value),
                ),
                const SizedBox(height: DesignTokens.space3),
                TextFormField(
                  key: const Key('goal-description'),
                  controller: _descController,
                  onChanged: (_) => setState(() {}),
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description / Purpose (Optional)',
                    hintText: 'Describe what you want to learn or achieve',
                    prefixIcon: const Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                    ),
                  ),
                ),
                _suggestionChips(
                  heading: 'Purpose ideas from the catalog',
                  values: descriptionSuggestions,
                  keyPrefix: 'goal-description-suggestion',
                  maxLabelLength: 72,
                  onSelected: (value) => setState(() =>
                      _descController.text = value),
                ),
                const SizedBox(height: DesignTokens.space3),
                Text(
                  'Your new goal is a private, editable draft. Selecting an official '
                  'example does not mark your copy as official.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: const Text('Create Goal'),
        ),
      ],
    );
  }
}
