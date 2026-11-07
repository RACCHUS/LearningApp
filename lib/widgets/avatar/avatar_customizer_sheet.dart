import 'package:flutter/material.dart';
import '../../models/avatar/device_local_avatar.dart';
import '../../services/avatar/avatar_persistence_service.dart';
import 'device_local_avatar_widget.dart';

/// Modal bottom sheet for customizing the learner's device-local avatar (P8-1).
class AvatarCustomizerSheet extends StatefulWidget {
  final AvatarPersistenceService service;

  const AvatarCustomizerSheet({
    super.key,
    required this.service,
  });

  static Future<void> show(
    BuildContext context, {
    required AvatarPersistenceService service,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AvatarCustomizerSheet(service: service),
    );
  }

  @override
  State<AvatarCustomizerSheet> createState() => _AvatarCustomizerSheetState();
}

class _AvatarCustomizerSheetState extends State<AvatarCustomizerSheet> {
  late AvatarExpression _expression;
  late AvatarAccessory _accessory;
  late AvatarColorTheme _theme;
  late TextEditingController _nicknameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.service.avatar;
    _expression = a.expression;
    _accessory = a.accessory;
    _theme = a.theme;
    _nicknameController = TextEditingController(text: a.customNickname ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  DeviceLocalAvatar get _previewAvatar => DeviceLocalAvatar(
        expression: _expression,
        accessory: _accessory,
        theme: _theme,
        customNickname: _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : null,
        updatedAt: DateTime.now(),
      );

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await widget.service.saveAvatar(_previewAvatar);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar saved to your device!'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Customize Your Persona',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Stored device-locally • 100% private',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),

              // Live Preview
              Center(
                child: DeviceLocalAvatarWidget(
                  avatar: _previewAvatar,
                  radius: 52,
                ),
              ),
              const SizedBox(height: 24),

              // Expression Picker
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Expression & Mood',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AvatarExpression.values.map((exp) {
                  final isSelected = _expression == exp;
                  return ChoiceChip(
                    label: Text('${exp.emoji} ${exp.label}'),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _expression = exp),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Accessory Picker
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Vocational & Study Accessories',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AvatarAccessory.values.map((acc) {
                  final isSelected = _accessory == acc;
                  return ChoiceChip(
                    avatar: acc.icon != null ? Icon(acc.icon, size: 16) : null,
                    label: Text(acc.label),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _accessory = acc),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Theme Color Picker
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Theme Color',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: AvatarColorTheme.values.map((colorTheme) {
                  final isSelected = _theme == colorTheme;
                  return GestureDetector(
                    onTap: () => setState(() => _theme = colorTheme),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: colorTheme.primaryColor.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Nickname Input
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(
                  labelText: 'Learner Nickname (Optional)',
                  hintText: 'e.g. CodeLearner or SafetyPro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('save_avatar_button'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Save Avatar'),
                  onPressed: _isSaving ? null : _handleSave,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

