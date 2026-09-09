import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:learning_pwa/screens/home/home_study_sets_list.dart';

/// Full-page view of all saved study sets.
///
/// Routed at `/study-sets`. Wraps the reusable [HomeStudySetsList] sliver
/// with a Scaffold, AppBar, and a FAB to create new study sets via the
/// lesson selection flow.
class SavedStudySetsScreen extends StatelessWidget {
  const SavedStudySetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Sets'),
      ),
      body: const CustomScrollView(
        slivers: [
          HomeStudySetsList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lesson-selection'),
        icon: const Icon(Icons.add),
        label: const Text('New Study Set'),
      ),
    );
  }
}
