import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_pwa/providers/career_path_provider.dart';

/// Form for creating a new career path.
///
/// Routed at `/careers/create`. On success, navigates to the newly-created
/// career path detail screen.
class CareerPathCreateScreen extends ConsumerStatefulWidget {
  const CareerPathCreateScreen({super.key});

  @override
  ConsumerState<CareerPathCreateScreen> createState() =>
      _CareerPathCreateScreenState();
}

class _CareerPathCreateScreenState
    extends ConsumerState<CareerPathCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  int _estimatedMonths = 6;
  bool _isPublic = false;
  bool _isSubmitting = false;
  // Tracks whether the user has manually edited the slug, so we stop
  // auto-syncing it from the title once they take control.
  bool _slugEditedManually = false;

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  /// Derive a URL-safe slug from a title. Called when the title field
  /// loses focus and the slug field is still empty.
  String _slugify(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final service = ref.read(careerPathServiceProvider);
      final path = await service.createCareerPath(
        title: _titleController.text.trim(),
        slug: _slugController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        estimatedMonths: _estimatedMonths,
        isPublic: _isPublic,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Career path "${path.title}" created!')),
      );
      context.go('/careers/${path.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create career path: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Career Path'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Full-Stack Web Developer',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              onChanged: (v) {
                if (!_slugEditedManually) {
                  _slugController.text = _slugify(v);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _slugController,
              decoration: const InputDecoration(
                labelText: 'Slug *',
                hintText: 'url-friendly-id',
                border: OutlineInputBorder(),
                helperText: 'Lowercase letters, numbers, and hyphens only',
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => _slugEditedManually = true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Slug is required';
                if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                  return 'Use only lowercase letters, numbers, and hyphens';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What will learners achieve?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Estimated duration:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _estimatedMonths.toDouble(),
                    min: 1,
                    max: 24,
                    divisions: 23,
                    label: '$_estimatedMonths months',
                    onChanged: (v) =>
                        setState(() => _estimatedMonths = v.round()),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text('$_estimatedMonths mo',
                      textAlign: TextAlign.end),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Make public'),
              subtitle: const Text(
                  'Other users can discover and follow this career path'),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Creating...' : 'Create Career Path'),
            ),
          ],
        ),
      ),
    );
  }
}
