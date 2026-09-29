import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/learning_target.dart';
import '../../providers/learning_target_provider.dart';
import '../../theme/design_tokens.dart';

/// Interactive dialog allowing the user to create a new Learning Target
/// (Career, Certification, Standardized Exam, Academic Program, or Curriculum Standard).
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
    _titleController.dispose();
    _descController.dispose();
    _providerController.dispose();
    super.dispose();
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
      providerName: _providerController.text.trim().isNotEmpty
          ? _providerController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (target != null) {
      ref.invalidate(targetsListProvider);
      Navigator.of(context).pop(target);
      context.push('/target/${target.id}');
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create learning goal. Please check connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(DesignTokens.space2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag_outlined,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: DesignTokens.space3),
          const Text('Create Learning Goal'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(DesignTokens.space3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
                const SizedBox(height: DesignTokens.space3),
              ],
              DropdownButtonFormField<TargetType>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Goal Type',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: TargetType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: DesignTokens.space3),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title or Target Role',
                  hintText: _selectedType == TargetType.career
                      ? 'e.g., Senior Full-Stack Engineer'
                      : (_selectedType == TargetType.certification
                          ? 'e.g., CompTIA Security+'
                          : (_selectedType == TargetType.standardizedExam
                              ? 'e.g., USMLE Step 1'
                              : 'e.g., Data Structures & Algorithms')),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  prefixIcon: const Icon(Icons.edit_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DesignTokens.space3),
              TextFormField(
                controller: _providerController,
                decoration: InputDecoration(
                  labelText: _selectedType == TargetType.certification
                      ? 'Certification Provider / Body'
                      : (_selectedType == TargetType.academicProgram
                          ? 'University / Institution'
                          : 'Authority / Organization (Optional)'),
                  hintText: 'e.g., CompTIA, AWS, College Board',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  prefixIcon: const Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: DesignTokens.space3),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description / Purpose (Optional)',
                  hintText: 'What key milestones or outcomes do you aim to master?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
                  ),
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ],
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: const Text('Create Goal'),
        ),
      ],
    );
  }
}
