import 'package:flutter/material.dart';
import 'package:learning_pwa/models/community/educator_profile.dart';
import 'package:learning_pwa/models/community/educator_subject.dart';
import 'package:learning_pwa/services/community/educator_service.dart';

/// Modal dialog allowing educators to edit their contributor profile, subjects, and submit credential claims (ECO-04).
///
/// Implements Phase 2 Invariants:
/// - "Teacher does not own the subject or course."
/// - Separation of self-declared experience claims from platform-vetted and licensed regulatory credentials.
class EducatorProfileEditDialog extends StatefulWidget {
  final EducatorProfile? initialProfile;
  final List<EducatorSubject> initialSubjects;
  final EducatorService service;
  final VoidCallback? onSaved;

  const EducatorProfileEditDialog({
    super.key,
    this.initialProfile,
    this.initialSubjects = const [],
    required this.service,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    EducatorProfile? initialProfile,
    List<EducatorSubject> initialSubjects = const [],
    required EducatorService service,
    VoidCallback? onSaved,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => EducatorProfileEditDialog(
        initialProfile: initialProfile,
        initialSubjects: initialSubjects,
        service: service,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<EducatorProfileEditDialog> createState() => _EducatorProfileEditDialogState();
}

class _EducatorProfileEditDialogState extends State<EducatorProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayNameController;
  late TextEditingController _headlineController;
  late TextEditingController _bioController;
  late bool _isAcceptingQuestions;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Credential claim form fields
  bool _showCredentialSection = false;
  String _credentialType = 'licensed_credential';
  final _issuerController = TextEditingController();
  final _jurisdictionController = TextEditingController();
  final _referenceController = TextEditingController();

  // Subject association selection
  final List<String> _selectedSubjectIds = [];
  static const List<Map<String, String>> _availableSubjects = [
    {'id': 'abe_literacy', 'name': 'Adult Basic Education (ABE) Literacy'},
    {'id': 'workplace_safety', 'name': 'Workplace Safety & OSHA Compliance'},
    {'id': 'fl_licensure', 'name': 'Florida State Licensure & DBPR'},
    {'id': 'math_foundations', 'name': 'Practical Math & Measurement'},
    {'id': 'healthcare_cna', 'name': 'Healthcare & Nurse Assisting'},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _displayNameController = TextEditingController(text: p?.displayName ?? '');
    _headlineController = TextEditingController(text: p?.headline ?? '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _isAcceptingQuestions = p?.isAcceptingQuestions ?? true;

    for (final s in widget.initialSubjects) {
      _selectedSubjectIds.add(s.subjectId);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _headlineController.dispose();
    _bioController.dispose();
    _issuerController.dispose();
    _jurisdictionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // 1. Upsert profile
      await widget.service.upsertMyProfile(
        displayName: _displayNameController.text.trim(),
        headline: _headlineController.text.trim().isEmpty ? null : _headlineController.text.trim(),
        bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        isAcceptingQuestions: _isAcceptingQuestions,
        status: 'active',
      );

      // 2. Add any newly selected subjects
      final existingSubjectIds = widget.initialSubjects.map((s) => s.subjectId).toSet();
      for (final subId in _selectedSubjectIds) {
        if (!existingSubjectIds.contains(subId)) {
          final def = _availableSubjects.firstWhere((m) => m['id'] == subId);
          await widget.service.addSubject(
            subjectId: subId,
            subjectName: def['name']!,
          );
        }
      }

      // 3. Submit credential claim if entered
      if (_showCredentialSection && _issuerController.text.trim().isNotEmpty) {
        await widget.service.submitVerificationClaim(
          verificationType: _credentialType,
          issuer: _issuerController.text.trim(),
          jurisdiction: _jurisdictionController.text.trim().isEmpty ? null : _jurisdictionController.text.trim(),
          credentialReference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        );
      }

      if (mounted) {
        widget.onSaved?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save profile: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit Contributor Profile'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                // Display Name
                TextFormField(
                  key: const Key('educator_display_name_field'),
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name *',
                    hintText: 'e.g., Dr. Sarah Jenkins, Instructor Mark',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Display name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Headline
                TextFormField(
                  key: const Key('educator_headline_field'),
                  controller: _headlineController,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    hintText: 'e.g., Adult Literacy Specialist & Florida DBPR Licensee',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Bio
                TextFormField(
                  key: const Key('educator_bio_field'),
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio & Experience Summary',
                    hintText: 'Share your background, teaching philosophy, or practical industry experience...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Accepting questions toggle
                SwitchListTile(
                  key: const Key('educator_accepting_questions_toggle'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Accept Learner Questions', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Allow learners to ask you topic questions', style: TextStyle(fontSize: 12)),
                  value: _isAcceptingQuestions,
                  onChanged: (val) => setState(() => _isAcceptingQuestions = val),
                ),
                const Divider(),

                // Subjects taught
                Text('Subjects You Teach', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Teachers contribute knowledge without owning courses.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _availableSubjects.map((sub) {
                    final isSelected = _selectedSubjectIds.contains(sub['id']);
                    return FilterChip(
                      label: Text(sub['name']!, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSubjectIds.add(sub['id']!);
                          } else {
                            _selectedSubjectIds.remove(sub['id']!);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const Divider(),

                // Credential Claim Section
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user, color: Colors.teal),
                  title: const Text('Add Credential Claim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: Icon(_showCredentialSection ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _showCredentialSection = !_showCredentialSection),
                  ),
                ),
                if (_showCredentialSection) ...[
                  DropdownButtonFormField<String>(
                    value: _credentialType,
                    decoration: const InputDecoration(labelText: 'Credential Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(
                        value: 'licensed_credential',
                        child: Text('Official State Regulatory License (FL DBPR, CNA, etc.)'),
                      ),
                      DropdownMenuItem(
                        value: 'platform_vetted',
                        child: Text('Platform-Vetted Subject Expertise'),
                      ),
                      DropdownMenuItem(
                        value: 'self_declared',
                        child: Text('Self-Declared Practical Experience'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _credentialType = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _issuerController,
                    decoration: const InputDecoration(
                      labelText: 'Issuing Authority / Subject',
                      hintText: 'e.g., Florida DBPR, OSHA, Red Cross',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _jurisdictionController,
                    decoration: const InputDecoration(
                      labelText: 'Jurisdiction (State / Country)',
                      hintText: 'e.g., Florida, US, California',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'License Reference / Verification Key (Optional)',
                      hintText: 'License number or portfolio link',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('save_educator_profile_button'),
          onPressed: _isSubmitting ? null : _handleSave,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Profile'),
        ),
      ],
    );
  }
}

