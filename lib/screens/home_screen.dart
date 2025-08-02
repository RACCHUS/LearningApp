import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/combined_lessons_provider.dart';
import 'package:learning_pwa/screens/home/lesson_list.dart';
import 'package:learning_pwa/screens/home/search_bar.dart';
import 'package:learning_pwa/screens/home/category_filters.dart';
import 'package:learning_pwa/screens/lessons/create_lesson_screen.dart';

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

  String? _getUserId(AuthState state) {
    if (state is AuthSuccess) {
      return state.user.id;
    }
    if (state is GuestMode) {
      return '00000000-0000-0000-0000-000000000000';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userId = _getUserId(authState) ?? '00000000-0000-0000-0000-000000000000';
    final userLessons = ref.watch(combinedLessonsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Learning App', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings screen when available
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
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
          Expanded(
            child: LessonList(
              lessonsStream: userLessons,
              searchQuery: _searchQuery,
              selectedTag: selectedTag,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateLessonScreen(),
            ),
          );
          
          if (result != null) {
            // Refresh lessons after creation
            ref.invalidate(combinedLessonsProvider);
          }
        },
        label: const Text('New Lesson'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
