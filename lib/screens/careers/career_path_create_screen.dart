import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_pwa/models/course_models.dart';
import 'package:learning_pwa/providers/career_path_provider.dart';
import 'package:learning_pwa/services/course_service.dart';

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
  bool _isLoadingCourses = false;
  List<Course> _availableCourses = const [];
  final Set<String> _selectedCourseIds = <String>{};
  // Tracks whether the user has manually edited the slug, so we stop
  // auto-syncing it from the title once they take control.
  bool _slugEditedManually = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

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

  Future<void> _loadCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      final courses = await CourseService().getUserCourses();
      if (!mounted) return;
      setState(() {
        _availableCourses = courses;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load courses. You can still create a path.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingCourses = false);
      }
    }
  }

  Future<void> _openCoursePicker() async {
    final tempSelected = Set<String>.from(_selectedCourseIds);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Courses for This Path',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCourseIds
                                  ..clear()
                                  ..addAll(tempSelected);
                              });
                              Navigator.of(context).pop();
                            },
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: _availableCourses.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No courses found. Create a course first, then attach it here.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _availableCourses.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final course = _availableCourses[index];
                                final isSelected =
                                    tempSelected.contains(course.id);
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(course.title),
                                  subtitle: course.description.isNotEmpty
                                      ? Text(
                                          course.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  onChanged: (value) {
                                    modalSetState(() {
                                      if (value == true) {
                                        tempSelected.add(course.id);
                                      } else {
                                        tempSelected.remove(course.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

      var attachedCount = 0;
      for (var i = 0; i < _availableCourses.length; i++) {
        final course = _availableCourses[i];
        if (_selectedCourseIds.contains(course.id)) {
          await service.addCourseToPath(
            pathId: path.id,
            courseId: course.id,
            orderIndex: attachedCount,
            isRequired: true,
          );
          attachedCount += 1;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            attachedCount > 0
                ? 'Career path "${path.title}" created with $attachedCount course(s).'
                : 'Career path "${path.title}" created!',
          ),
        ),
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
                  child: Text('$_estimatedMonths mo', textAlign: TextAlign.end),
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
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Courses in This Path',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_isLoadingCourses)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          TextButton.icon(
                            onPressed: _openCoursePicker,
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Select'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedCourseIds.isEmpty)
                      const Text(
                        'No courses selected yet. You can create the path now and add courses later, or attach courses here first.',
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableCourses
                            .where((c) => _selectedCourseIds.contains(c.id))
                            .map(
                              (course) => InputChip(
                                label: Text(course.title),
                                onDeleted: () {
                                  setState(() {
                                    _selectedCourseIds.remove(course.id);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
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
