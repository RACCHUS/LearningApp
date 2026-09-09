import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/skill_stats_provider.dart';
import '../providers/career_path_provider.dart';
import '../screens/home/home_courses_list.dart';

/// Dialog to pick a skill for reset
class SkillPickerDialog extends ConsumerStatefulWidget {
  const SkillPickerDialog({super.key});

  @override
  ConsumerState<SkillPickerDialog> createState() => _SkillPickerDialogState();
}

class _SkillPickerDialogState extends ConsumerState<SkillPickerDialog> {
  String? _selectedSkillId;

  @override
  Widget build(BuildContext context) {
    final userStatsAsync = ref.watch(userSkillStatsProvider);

    return AlertDialog(
      title: const Text('Select Skill to Reset'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: userStatsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (stats) {
            if (stats.isEmpty) {
              return const Center(
                child: Text('No skills to reset'),
              );
            }

            return ListView.builder(
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final stat = stats[index];
                final isSelected = _selectedSkillId == stat.skillId;

                return RadioListTile<String>(
                  value: stat.skillId,
                  groupValue: _selectedSkillId,
                  onChanged: (value) => setState(() => _selectedSkillId = value),
                  title: Text(stat.skill?.name ?? 'Unknown Skill'),
                  subtitle: Text('Level ${stat.level} • ${stat.tier.displayName}'),
                  secondary: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    child: Text(
                      '${stat.level}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedSkillId == null
              ? null
              : () => Navigator.of(context).pop(_selectedSkillId),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

/// Dialog to pick a course for reset
class CoursePickerDialog extends ConsumerStatefulWidget {
  const CoursePickerDialog({super.key});

  @override
  ConsumerState<CoursePickerDialog> createState() => _CoursePickerDialogState();
}

class _CoursePickerDialogState extends ConsumerState<CoursePickerDialog> {
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(userCoursesProvider);

    return AlertDialog(
      title: const Text('Select Course to Reset'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: coursesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (courses) {
            if (courses.isEmpty) {
              return const Center(
                child: Text('No courses with progress to reset'),
              );
            }

            return ListView.builder(
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final course = courses[index];
                final isSelected = _selectedCourseId == course.id;

                return Consumer(
                  builder: (context, ref, _) {
                    final progressAsync = ref.watch(courseProgressProvider(course.id));
                    final progressPercent = progressAsync.whenOrNull(
                      data: (progress) => progress != null 
                          ? (progress.overallProgress * 100).round() 
                          : 0,
                    ) ?? 0;

                    return RadioListTile<String>(
                      value: course.id,
                      groupValue: _selectedCourseId,
                      onChanged: (value) => setState(() => _selectedCourseId = value),
                      title: Text(course.title),
                      subtitle: Text('$progressPercent% complete'),
                      secondary: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        child: Icon(
                          Icons.school,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedCourseId == null
              ? null
              : () => Navigator.of(context).pop(_selectedCourseId),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

/// Dialog to pick a career path for reset
class CareerPathPickerDialog extends ConsumerStatefulWidget {
  const CareerPathPickerDialog({super.key});

  @override
  ConsumerState<CareerPathPickerDialog> createState() =>
      _CareerPathPickerDialogState();
}

class _CareerPathPickerDialogState
    extends ConsumerState<CareerPathPickerDialog> {
  String? _selectedPathId;

  @override
  Widget build(BuildContext context) {
    final userPathsAsync = ref.watch(userCareerPathsProvider);

    return AlertDialog(
      title: const Text('Select Career Path to Reset'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: userPathsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return const Center(
                child: Text('No career paths to reset'),
              );
            }

            return ListView.builder(
              itemCount: enrollments.length,
              itemBuilder: (context, index) {
                final enrollment = enrollments[index];
                final isSelected = _selectedPathId == enrollment.careerPathId;

                return Consumer(
                  builder: (context, ref, _) {
                    final pathAsync =
                        ref.watch(careerPathProvider(enrollment.careerPathId));

                    return pathAsync.when(
                      data: (path) => RadioListTile<String>(
                        value: enrollment.careerPathId,
                        groupValue: _selectedPathId,
                        onChanged: (value) =>
                            setState(() => _selectedPathId = value),
                        title: Text(path.title),
                        subtitle: Text(
                          '${enrollment.status.name} • Started ${_formatDate(enrollment.startedAt)}',
                        ),
                        secondary: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.route,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                      loading: () => const ListTile(
                        title: Text('Loading...'),
                      ),
                      error: (_, __) => const ListTile(
                        title: Text('Error loading path'),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedPathId == null
              ? null
              : () => Navigator.of(context).pop(_selectedPathId),
          child: const Text('Select'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Helper function to show skill picker and return selected skill ID
Future<String?> showSkillPicker(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const SkillPickerDialog(),
  );
}

/// Helper function to show course picker and return selected course ID
Future<String?> showCoursePicker(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const CoursePickerDialog(),
  );
}

/// Helper function to show career path picker and return selected path ID
Future<String?> showCareerPathPicker(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const CareerPathPickerDialog(),
  );
}
