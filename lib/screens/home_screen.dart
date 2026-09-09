import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/lesson_provider.dart';
import 'package:learning_pwa/providers/connectivity_provider.dart';
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
import 'package:learning_pwa/widgets/progress/sync_status_indicator.dart';
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
  bool _showRecommendations = false;

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

  Future<void> _openCreateMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: const Text('New Lesson (Manual Editor)'),
                  subtitle: const Text('Build terms, questions, concepts, and more'),
                  onTap: () {
                    Navigator.of(context).pop();
                    this.context.push('/lesson-editor');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('New Lesson (AI / Import)'),
                  subtitle: const Text('Generate or import a complete lesson JSON'),
                  onTap: () {
                    Navigator.of(context).pop();
                    this.context.push('/create-lesson');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.quiz),
                  title: const Text('Create Questions (MCQ)'),
                  subtitle: const Text('Create in a new lesson or attach to an existing lesson'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openContentTargetMenu(contentType: 'mcq', label: 'Questions (MCQ)');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.style),
                  title: const Text('Create Flashcards (Terms)'),
                  subtitle: const Text('Create in a new lesson or attach to an existing lesson'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openContentTargetMenu(contentType: 'term', label: 'Flashcards (Terms)');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Create Concepts'),
                  subtitle: const Text('Create in a new lesson or attach to an existing lesson'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openContentTargetMenu(contentType: 'concept', label: 'Concepts');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Update Existing Lesson'),
                  subtitle: const Text('Pick an existing lesson and add/edit content'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openExistingLessonPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('New Course'),
                  subtitle: const Text('Create a course and organize lessons'),
                  onTap: () {
                    Navigator.of(context).pop();
                    this.context.push('/course-builder');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.route),
                  title: const Text('New Career Path'),
                  subtitle: const Text('Create a career path and map courses'),
                  onTap: () {
                    Navigator.of(context).pop();
                    this.context.push('/careers/create');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openContentTargetMenu({
    required String contentType,
    required String label,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text('Create New Lesson with $label'),
                subtitle: const Text('Starts a new lesson and opens the right builder tab'),
                onTap: () {
                  Navigator.of(context).pop();
                  this.context.push('/create-lesson?tab=manual&content=$contentType');
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text('Attach $label to Existing Lesson'),
                subtitle: const Text('Pick an existing lesson and jump to the matching editor tab'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openExistingLessonPicker(preferredContentType: contentType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openExistingLessonPicker({String? preferredContentType}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final lessonsAsync = ref.watch(allLessonsProvider);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: lessonsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load lessons: $e'),
                ),
              ),
              data: (lessons) {
                if (lessons.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No lessons yet. Create one first.'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: lessons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final lesson = lessons[index];
                    return ListTile(
                      leading: const Icon(Icons.menu_book),
                      title: Text(lesson.title),
                      subtitle: Text(lesson.description ?? ''),
                      onTap: () {
                        Navigator.of(context).pop();
                        final route = Uri(
                          path: '/lesson-editor/${lesson.id}',
                          queryParameters: preferredContentType == null
                              ? null
                              : <String, String>{'tab': preferredContentType},
                        ).toString();
                        this.context.push(route);
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
            color: colorScheme.onSurface,
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More options',
            onSelected: (value) {
              context.push(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: '/my-careers',
                child: ListTile(
                  leading: Icon(Icons.route),
                  title: Text('My Career Paths'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: '/progress',
                child: ListTile(
                  leading: Icon(Icons.insights),
                  title: Text('My Progress'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: '/test/hands-free',
                child: ListTile(
                  leading: Icon(Icons.psychology),
                  title: Text('Test Hands-Free'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: '/settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          if (authState is GuestMode ||
              (authState is AuthSuccess && authState.user.isAnonymous)) ...[
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
              icon: Icon(Icons.account_circle, color: colorScheme.onSurfaceVariant),
              tooltip: 'Profile',
              onPressed: () {
                context.push('/profile');
              },
            ),
          ],
          const SizedBox(width: DesignTokens.space2),
        ],
        bottom: PreferredSize(
          // Provide room for the TabBar (48) + a slim sync status banner.
          // The indicator collapses to SizedBox.shrink() when idle, so the
          // extra 4px is only realised visually when sync is active.
          preferredSize: const Size.fromHeight(52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
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
              const SyncStatusIndicator(),
            ],
          ),
        ),
      ),
      body: ConnectivityAware(
        child: CelebrationOverlay(
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
      ),
      floatingActionButton: _buildFloatingActionButton(context, ref),
      floatingActionButtonLocation: kIsWeb
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLessonsTab() {
    final allLessons = ref.watch(allLessonsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final showGuidedSections = _searchQuery.isEmpty && selectedTag == null;

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
        if (showGuidedSections)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space4,
                DesignTokens.space2,
                DesignTokens.space4,
                0,
              ),
              child: Text(
                'Continue Your Path',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),

        if (showGuidedSections)
          const SliverToBoxAdapter(
            child: ContinueLearningHero(),
          ),

        // Review Due Card (only when not searching)
        if (showGuidedSections)
          const SliverToBoxAdapter(
            child: ReviewDueCard(),
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

        // Recommendations are useful, but secondary to the user's active path.
        if (showGuidedSections)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DesignTokens.space4,
                DesignTokens.space3,
                DesignTokens.space4,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _showRecommendations = !_showRecommendations;
                    });
                  },
                  icon: Icon(
                    _showRecommendations
                        ? Icons.expand_less
                        : Icons.explore_outlined,
                  ),
                  label: Text(
                    _showRecommendations
                        ? 'Hide Discovery'
                        : 'Discover More Lessons',
                  ),
                ),
              ),
            ),
          ),

        if (showGuidedSections && _showRecommendations)
          const SliverToBoxAdapter(
            child: RecommendationSection(),
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
              onPressed: _openCreateMenu,
              label: const Text('Create'),
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
