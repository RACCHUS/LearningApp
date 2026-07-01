import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/career_path.dart';
import '../../providers/career_path_provider.dart';

/// Screen showing all available career paths
class CareerPathsScreen extends ConsumerWidget {
  const CareerPathsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final careerPathsAsync = ref.watch(careerPathsProvider);
    final userPathsAsync = ref.watch(userCareerPathsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Paths'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Careers',
            onPressed: () => context.push('/my-careers'),
          ),
        ],
      ),
      body: careerPathsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (paths) {
          if (paths.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No career paths available yet'),
                ],
              ),
            );
          }

          // Separate featured and regular paths
          final featured = paths.where((p) => p.isFeatured).toList();
          final regular = paths.where((p) => !p.isFeatured).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (featured.isNotEmpty) ...[
                const Text(
                  'Featured Paths',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...featured.map((path) => _CareerPathCard(
                      path: path,
                      isEnrolled: userPathsAsync.maybeWhen(
                        data: (enrolled) =>
                            enrolled.any((e) => e.careerPathId == path.id),
                        orElse: () => false,
                      ),
                    )),
                const SizedBox(height: 24),
              ],
              if (regular.isNotEmpty) ...[
                const Text(
                  'All Paths',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...regular.map((path) => _CareerPathCard(
                      path: path,
                      isEnrolled: userPathsAsync.maybeWhen(
                        data: (enrolled) =>
                            enrolled.any((e) => e.careerPathId == path.id),
                        orElse: () => false,
                      ),
                    )),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/careers/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Path'),
      ),
    );
  }
}

class _CareerPathCard extends ConsumerWidget {
  final CareerPath path;
  final bool isEnrolled;

  const _CareerPathCard({
    required this.path,
    required this.isEnrolled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/careers/${path.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (path.isOfficial) ...[
                              Icon(Icons.verified,
                                  size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                path.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (path.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            path.description!,
                            style: TextStyle(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isEnrolled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Enrolled',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.schedule,
                    label: '${path.estimatedMonths} months',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.school,
                    label: '${path.courses?.length ?? 0} courses',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.psychology,
                    label: '${path.skills?.length ?? 0} skills',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
