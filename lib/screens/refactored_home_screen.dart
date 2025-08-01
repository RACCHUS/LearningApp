import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/combined_lessons_provider.dart';
import '../models/base_lesson.dart';
import '../components/home/home_app_bar.dart';
import '../components/home/search_bar.dart';
import '../components/home/category_chip.dart';
import '../components/home/home_nav_bar.dart';

class RefactoredHomeScreen extends ConsumerStatefulWidget {
  const RefactoredHomeScreen({super.key});

  @override
  ConsumerState<RefactoredHomeScreen> createState() => _RefactoredHomeScreenState();
}

class _RefactoredHomeScreenState extends ConsumerState<RefactoredHomeScreen> 
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _animationController;
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _refreshLessons() async {
    // TODO: Implement lesson refresh logic
    await Future.delayed(const Duration(seconds: 1));
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _onTagSelected(String? tag) {
    setState(() {
      _selectedTag = tag;
    });
  }

  List<BaseLesson> _filterLessons(List<BaseLesson> lessons) {
    return lessons.where((lesson) {
      final searchQuery = _searchQuery.toLowerCase();
      final title = lesson.title.toLowerCase();
      final description = lesson.description?.toLowerCase() ?? '';
      
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(searchQuery) ||
          description.contains(searchQuery);
      
      final matchesTag = _selectedTag == null || lesson.tags.contains(_selectedTag);
      
      return matchesSearch && matchesTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    // Get user ID safely, defaulting to empty string if not available
    final userId = authState is AuthSuccess ? authState.user.id : '';
    final lessonsAsync = ref.watch(combinedLessonsProvider(userId));
    
    final currentRoute = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      appBar: const HomeAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshLessons,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hero Section with Search
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.1),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start Learning',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Discover new lessons and expand your knowledge',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    HomeSearchBar(
                      controller: _searchController,
                      searchQuery: _searchQuery,
                      onChanged: _onSearchChanged,
                      onClear: _onClearSearch,
                    ),
                  ],
                ),
              ),
            ),
            
            // Category Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    CategoryChip(
                      label: 'All',
                      icon: Icons.all_inclusive,
                      isSelected: _selectedTag == null,
                      onTap: () => _onTagSelected(null),
                    ),
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: 'Favorites',
                      icon: Icons.favorite,
                      isSelected: _selectedTag == 'favorites',
                      onTap: () => _onTagSelected('favorites'),
                    ),
                    const SizedBox(width: 8),
                    CategoryChip(
                      label: 'Recent',
                      icon: Icons.history,
                      isSelected: _selectedTag == 'recent',
                      onTap: () => _onTagSelected('recent'),
                    ),
                  ],
                ),
              ),
            ),
            
            // Lessons List
            lessonsAsync.when(
              data: (lessons) {
                final filteredLessons = _filterLessons(lessons);
                
                if (filteredLessons.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text('No lessons found'),
                    ),
                  );
                }
                
                return SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lesson = filteredLessons[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            title: Text(lesson.title),
                            subtitle: Text(lesson.description),
                            onTap: () {
                              // TODO: Navigate to lesson details
                            },
                          ),
                        );
                      },
                      childCount: filteredLessons.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => SliverFillRemaining(
                child: Center(
                  child: Text('Error loading lessons: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HomeNavBar(currentRoute: currentRoute),
      floatingActionButton: authState is AuthSuccess
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/create-lesson'),
              icon: const Icon(Icons.add),
              label: const Text('Create Lesson'),
            )
          : FloatingActionButton.extended(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Create Lesson'),
              tooltip: 'Please sign in to create a lesson',
            ),
    );
  }
}
