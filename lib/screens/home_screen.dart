import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/providers/combined_lessons_provider.dart';
import 'package:learning_pwa/models/base_lesson.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  // State variables
  String? selectedTag;
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Initialize any necessary state here
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // Helper method to filter lessons based on search query and selected tag
  List<dynamic> _filterLessons(List<dynamic> lessons) {
    return lessons.where((lesson) {
      final matchesSearch = _searchQuery.isEmpty ||
          (lesson['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (lesson['description']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesTag = selectedTag == null ||
          ((lesson['tags'] as List<dynamic>?)?.contains(selectedTag) ?? false);
      return matchesSearch && matchesTag;
    }).toList();
  }

  Future<void> _refreshLessons() async {
    // Implement refresh logic here
    final authState = ref.read(authProvider);
    final userId = authState is AuthSuccess ? authState.user.id : '';
    if (userId.isNotEmpty) {
      ref.refresh(combinedLessonsProvider(userId));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }
  
  void _onTagSelected(String tag) {
    setState(() {
      selectedTag = tag;
    });
  }

  // Helper method to build category chips
  // Custom bottom navigation bar item widget
  Widget _buildNavBarItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isActive 
        ? theme.colorScheme.primary 
        : isDark 
            ? Colors.white70 
            : Colors.black54;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: kBottomNavigationBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, IconData icon, {VoidCallback? onTap, bool isSelected = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  }

  // Helper method to build lesson cards
  Widget _buildLessonCard(BuildContext context, BaseLesson lesson) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLocalLesson = lesson.isLocal;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isLocalLesson 
            ? BorderSide(color: Colors.orange.withOpacity(0.5), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          // Navigate to lesson detail
          final route = isLocalLesson 
              ? '/local-lesson/${lesson.id}'
              : '/lesson/${lesson.id}';
          context.go(route);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isLocalLesson) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Local',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (lesson.tags.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lesson.tags.first,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (lesson.description != null && lesson.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  lesson.description!,
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${lesson.tags.length} ${lesson.tags.length == 1 ? 'tag' : 'tags'}' +
                    (isLocalLesson ? ' • Local Only' : ''),
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Created ${_formatDate(lesson.createdAt)}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    } else if (difference.inDays >= 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
  }

  // Function to refresh lessons
  Future<void> _refreshLessons() async {
    final authState = ref.read(authProvider);
    final userId = authState is AuthSuccess ? authState.user.id : '';
    ref.invalidate(combinedLessonsProvider(userId));
  }

  // Helper method to build category chips
  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final authState = ref.watch(authProvider);
        final userId = authState is AuthSuccess ? authState.user.id : '';
        final lessonsAsync = ref.watch(combinedLessonsProvider(userId));
        
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/create-lesson'),
            icon: const Icon(Icons.add),
            label: const Text('Create Lesson'),
            elevation: 2.0,
          ),
          body: RefreshIndicator(
            onRefresh: _refreshLessons,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // App Bar with user greeting and actions
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Welcome Back!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.primaryColor,
                      theme.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            actions: [
              if (authState is AuthSuccess) ...[
                IconButton(
                  icon: const Icon(Icons.account_circle, color: Colors.white),
                  onPressed: () => context.go('/profile'),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                ),
              ] else if (authState is GuestMode) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text('Sign In'),
                  ),
                ),
              ],
            ],
          ),
          
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
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search lessons...',
                      hintStyle: TextStyle(color: Theme.of(context).hintColor),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                    onSubmitted: (value) {
                      // Handle search submission
                      if (value.trim().isNotEmpty) {
                        // TODO: Implement search functionality
                        // For now, just show a snackbar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Searching for: $value'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    textInputAction: TextInputAction.search,
                  ),
                ],
              ),
            ),
          ),
          // Categories Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip('All', Icons.all_inclusive, 
                          isSelected: selectedTag == null, 
                          onTap: () => setState(() => selectedTag = null)),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Flutter', Icons.mobile_friendly, 
                          onTap: () => setState(() => selectedTag = 'flutter')),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Dart', Icons.code, 
                          onTap: () => setState(() => selectedTag = 'dart')),
                        const SizedBox(width: 8),
                        _buildCategoryChip('Web', Icons.language, 
                          onTap: () => setState(() => selectedTag = 'web')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Featured Lessons Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Featured Lessons',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to all lessons
                      context.go('/lessons');
                    },
                    child: Text(
                      'See All',
                      style: TextStyle(color: theme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Combined Lessons List
          lessonsAsync.when(
            data: (lessons) {
              // Filter lessons based on tag and search query
              Iterable<BaseLesson> filteredLessons = lessons;
              
              // Apply tag filter
              if (selectedTag != null) {
                filteredLessons = filteredLessons.where((l) => l.tags.contains(selectedTag));
              }
              
              // Apply search query filter
              if (_searchQuery.isNotEmpty) {
                final query = _searchQuery.toLowerCase();
                filteredLessons = filteredLessons.where((lesson) =>
                    lesson.title.toLowerCase().contains(query) ||
                    lesson.tags.any((tag) => tag.toLowerCase().contains(query)));
              } else if (selectedTag == null) {
                // If no search query and no tag selected, show only 5 featured lessons
                filteredLessons = filteredLessons.take(5);
              }
                  
              final filteredLessonsList = filteredLessons.toList();
              
              if (filteredLessonsList.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No lessons found',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final lesson = filteredLessonsList[index];
                      return _buildLessonCard(context, lesson);
                    },
                    childCount: filteredLessonsList.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load lessons',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Refresh the lesson list
                        ref.invalidate(combinedLessonsProvider(userId));
                      },
                      child: Container(
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        child: BottomAppBar(
          color: isDarkMode ? theme.colorScheme.surface : Colors.white,
          elevation: 8,
          padding: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          child: SizedBox(
            height: kBottomNavigationBarHeight,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                _buildNavBarItem(
                  context: context,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  isActive: true,
                  onTap: () {
                    if (ModalRoute.of(context)?.settings.name != '/home') {
                      context.go('/home');
                    }
                  },
                ),
                _buildNavBarItem(
                  context: context,
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Explore',
                  isActive: false,
                  onTap: () {
                    context.go('/explore');
                  },
                ),
                _buildNavBarItem(
                  context: context,
                  icon: Icons.bookmark_border,
                  activeIcon: Icons.bookmark,
                  label: 'Saved',
                  isActive: false,
                  onTap: () {
                    context.go('/saved');
                  },
                ),
                _buildNavBarItem(
                  context: context,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: false,
                  onTap: () {
                    context.go('/profile');
                  },
                ),
              ],
            ),
          height: kBottomNavigationBarHeight,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              _buildNavBarItem(
                context: context,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: true,
                onTap: () {
                  if (ModalRoute.of(context)?.settings.name != '/home') {
                    context.go('/home');
                  }
                },
              ),
              _buildNavBarItem(
                context: context,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Explore',
                isActive: false,
                onTap: () {
                  context.go('/explore');
                },
              ),
              _buildNavBarItem(
                context: context,
                icon: Icons.bookmark_border,
                activeIcon: Icons.bookmark,
                label: 'Saved',
                isActive: false,
                onTap: () {
                  context.go('/saved');
                },
              ),
              _buildNavBarItem(
                context: context,
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: false,
                onTap: () {
                  context.go('/profile');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
