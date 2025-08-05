import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';

import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/home/lesson_list.dart';
import 'package:learning_pwa/screens/home/search_bar.dart';
import 'package:learning_pwa/screens/home/category_filters.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? selectedTag;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final allLessons = ref.watch(allLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Text('Learning App', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28, color: Theme.of(context).colorScheme.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Settings',
          ),
          if (authState is GuestMode) ...[
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.blue),
              label: const Text('Sign In', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
              onPressed: () {
                context.push('/login');
              },
              style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
            ),
          ] else if (authState is AuthSuccess) ...[
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.blue),
              tooltip: 'Profile',
              onPressed: () {
                context.push('/profile');
              },
            ),
          ]
        ],
      ),
      body: Container(
        color: Theme.of(context).colorScheme.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                HomeSearchBar(
                  controller: _searchController,
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 8),
                CategoryFilters(
                  selectedTag: selectedTag,
                  onTagSelected: (tag) {
                    setState(() {
                      selectedTag = tag;
                    });
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Create Study Set'),
                    onPressed: () {
                      context.push('/lesson-selection');
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LessonList(
                    lessonsStream: allLessons,
                    searchQuery: _searchQuery,
                    selectedTag: selectedTag,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create-lesson');
          ref.invalidate(allLessonsProvider);
        },
        label: const Text('New Lesson'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
