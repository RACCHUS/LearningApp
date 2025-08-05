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
        title: Text('Learning App', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings screen using GoRouter
              context.push('/settings');
            },
          ),
          if (authState is GuestMode) ...[
            TextButton.icon(
              icon: const Icon(Icons.login, color: Colors.blue),
              label: const Text('Sign In', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                context.push('/login');
              },
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
      body: Column(
        children: [
          HomeSearchBar(
            controller: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
          CategoryFilters(
            selectedTag: selectedTag,
            onTagSelected: (tag) {
              setState(() {
                selectedTag = tag;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Create Study Set'),
              onPressed: () {
                // Navigate to lesson selection screen
                context.push('/lesson-selection');
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
            ),
          ),
          Expanded(
            child: LessonList(
              lessonsStream: allLessons,
              searchQuery: _searchQuery,
              selectedTag: selectedTag,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create-lesson');
          // Refresh lessons after potential creation
          ref.invalidate(allLessonsProvider);
        },
        label: const Text('New Lesson'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
