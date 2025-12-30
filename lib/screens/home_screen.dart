import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/screens/home/home_search_bar.dart';
import 'package:learning_pwa/screens/home/home_category_filters.dart';
import 'package:learning_pwa/screens/home/home_lessons_list.dart';
import 'package:learning_pwa/screens/home/home_courses_list.dart';
import 'package:learning_pwa/screens/home/home_study_sets_list.dart';
import 'package:learning_pwa/widgets/continue_learning_hero.dart';
import 'package:learning_pwa/widgets/daily_goal_ring.dart';
import 'package:learning_pwa/widgets/desktop_sidebar.dart';
import 'package:learning_pwa/widgets/global_voice_indicator.dart';
import 'package:learning_pwa/widgets/level_badge.dart';
import 'package:learning_pwa/widgets/recommendation_widgets.dart';
import 'package:learning_pwa/widgets/review_widgets.dart';
import 'package:learning_pwa/widgets/streak_badge.dart';
import 'package:learning_pwa/widgets/celebration_overlay.dart';
import 'package:learning_pwa/theme/design_tokens.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String? initialSearchQuery;
  final String? initialFilter;

  const HomeScreen({
    super.key,
    this.initialSearchQuery,
    this.initialFilter,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? selectedTag;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  LessonSortOption _sortOption = LessonSortOption.recent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize search query from widget parameters
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.isNotEmpty) {
      _searchQuery = widget.initialSearchQuery!;
      _searchController.text = _searchQuery;
    }

    // Handle initial filter if provided
    if (widget.initialFilter != null) {
      // Filter logic could be implemented here
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      selectedTag = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Learning App',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 28,
            letterSpacing: -0.5,
            color: colorScheme.primary,
          ),
        ),
        actions: [
          const LevelBadge(),
          const SizedBox(width: DesignTokens.space2),
          const DailyGoalRing(),
          const SizedBox(width: DesignTokens.space2),
          const ReviewBadge(),
          const StreakBadge(),
          const SizedBox(width: DesignTokens.space2),
          const GlobalVoiceIndicator(compact: true),
          const SizedBox(width: DesignTokens.space2),
          IconButton(
            icon: const Icon(Icons.insights),
            onPressed: () {
              context.push('/progress');
            },
            tooltip: 'My Progress',
          ),
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: () {
              context.push('/test/hands-free');
            },
            tooltip: 'Test Hands-Free',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/settings');
            },
            tooltip: 'Settings',
          ),
          if (authState is GuestMode) ...[
            TextButton.icon(
              icon: Icon(Icons.login, color: colorScheme.primary),
              label: Text(
                'Sign In',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                context.push('/login');
              },
            ),
          ] else if (authState is AuthSuccess) ...[
            IconButton(
              icon: Icon(Icons.account_circle, color: colorScheme.primary),
              tooltip: 'Profile',
              onPressed: () {
                context.push('/profile');
              },
            ),
          ],
          const SizedBox(width: DesignTokens.space2),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Lessons'),
            Tab(icon: Icon(Icons.school), text: 'Courses'),
            Tab(icon: Icon(Icons.collections_bookmark), text: 'Study Sets'),
          ],
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
        ),
      ),
      body: CelebrationOverlay(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 1024;
            
            final mainContent = Container(
              color: colorScheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: DesignTokens.maxContentWidth),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Lessons Tab
                      _buildLessonsTab(),
                      // Courses Tab
                      _buildCoursesTab(),
                      // Study Sets Tab
                      _buildStudySetsTab(),
                    ],
                  ),
                ),
              ),
            );

            if (showSidebar) {
              return Row(
                children: [
                  Expanded(child: mainContent),
                  const DesktopSidebar(),
                ],
              );
            }
            
            return mainContent;
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(context, ref),
    );
  }

  Widget _buildLessonsTab() {
    final allLessons = ref.watch(allLessonsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: HomeSearchBar(
            controller: _searchController,
            searchQuery: _searchQuery,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ),

        // Continue Learning Hero (only when not searching)
        if (_searchQuery.isEmpty && selectedTag == null)
          const SliverToBoxAdapter(
            child: ContinueLearningHero(),
          ),

        // Review Due Card (only when not searching)
        if (_searchQuery.isEmpty && selectedTag == null)
          const SliverToBoxAdapter(
            child: ReviewDueCard(),
          ),

        // Recommendations (only when not searching)
        if (_searchQuery.isEmpty && selectedTag == null)
          const SliverToBoxAdapter(
            child: RecommendationSection(),
          ),

        // Category Filters
        HomeCategoryFilters(
          selectedTag: selectedTag,
          onTagSelected: (tag) {
            setState(() {
              selectedTag = tag;
            });
          },
        ),

        // Sort dropdown row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: DesignTokens.space3,
              horizontal: DesignTokens.space4,
            ),
            child: Row(
              children: [
                _buildSortDropdown(context, colorScheme),
                const Spacer(),
              ],
            ),
          ),
        ),

        // Lessons List
        HomeLessonsList(
          lessonsStream: allLessons,
          searchQuery: _searchQuery,
          selectedTag: selectedTag,
          sortOption: _sortOption,
          onClearSearch: _clearFilters,
        ),
      ],
    );
  }

  Widget _buildCoursesTab() {
    return CustomScrollView(
      slivers: [
        // Header with create button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                const Text(
                  'My Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/course-management');
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Manage'),
                ),
              ],
            ),
          ),
        ),
        // Courses grid
        const HomeCoursesList(),
      ],
    );
  }

  Widget _buildStudySetsTab() {
    return CustomScrollView(
      slivers: [
        // Header with create button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.space4),
            child: Row(
              children: [
                const Text(
                  'My Study Sets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    context.push('/lesson-selection');
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
        ),
        // Study sets list
        const HomeStudySetsList(),
      ],
    );
  }

  Widget _buildSortDropdown(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space3,
        vertical: DesignTokens.space1,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        border: Border.all(color: colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LessonSortOption>(
          value: _sortOption,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
          style: Theme.of(context).textTheme.labelLarge,
          dropdownColor: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          items: const [
            DropdownMenuItem(
              value: LessonSortOption.recent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 16),
                  SizedBox(width: 8),
                  Text('Recent'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: LessonSortOption.alphabetical,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_by_alpha, size: 16),
                  SizedBox(width: 8),
                  Text('A-Z'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: LessonSortOption.alphabeticalDesc,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_by_alpha, size: 16),
                  SizedBox(width: 8),
                  Text('Z-A'),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _sortOption = value;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    // Dynamic FAB based on selected tab
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, child) {
        final tabIndex = _tabController.index;

        switch (tabIndex) {
          case 0: // Lessons
            return FloatingActionButton.extended(
              heroTag: "homeCreateLessonFAB",
              onPressed: () async {
                await context.push('/lesson-editor');
                ref.invalidate(allLessonsProvider);
              },
              label: const Text('New Lesson'),
              icon: const Icon(Icons.add),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          case 1: // Courses
            return FloatingActionButton.extended(
              heroTag: "homeCreateCourseFAB",
              onPressed: () {
                context.push('/course-builder');
              },
              label: const Text('New Course'),
              icon: const Icon(Icons.add),
              backgroundColor: colorScheme.secondary,
              foregroundColor: colorScheme.onSecondary,
            );
          case 2: // Study Sets
            return FloatingActionButton.extended(
              heroTag: "homeCreateStudySetFAB",
              onPressed: () {
                context.push('/lesson-selection');
              },
              label: const Text('New Study Set'),
              icon: const Icon(Icons.playlist_add),
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}
