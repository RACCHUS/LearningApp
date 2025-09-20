import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_models.dart';
import '../services/course_service.dart';

/// Course management screen for creating and organizing courses
class CourseManagementScreen extends ConsumerStatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  ConsumerState<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends ConsumerState<CourseManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Course> _courses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCourses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await CourseService.getCourses();
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'Courses'),
            Tab(icon: Icon(Icons.add), text: 'Create'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoursesTab(),
          _buildCreateCourseTab(),
          _buildAnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildCoursesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No courses found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Create your first course to get started',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final course = _courses[index];
          return CourseCard(
            course: course,
            onTap: () => _openCourseDetails(course),
            onEdit: () => _editCourse(course),
            onDelete: () => _deleteCourse(course),
          );
        },
      ),
    );
  }

  Widget _buildCreateCourseTab() {
    return const CreateCourseForm();
  }

  Widget _buildAnalyticsTab() {
    return const CourseAnalyticsView();
  }

  void _openCourseDetails(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CourseDetailsScreen(course: course),
      ),
    );
  }

  void _editCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditCourseScreen(course: course),
      ),
    );
  }

  Future<void> _deleteCourse(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Are you sure you want to delete "${course.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await CourseService.deleteCourse(course.id);
        await _loadCourses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting course: $e')),
          );
        }
      }
    }
  }
}

/// Individual course card widget
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildInfoChip(Icons.category, course.category),
                  _buildInfoChip(Icons.trending_up, course.difficulty),
                  _buildInfoChip(Icons.access_time, '${course.estimatedHours}h'),
                  _buildStatusChip(course.status),
                ],
              ),
              if (course.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: course.tags.take(3).map((tag) => Chip(
                    label: Text(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${course.enrollmentCount} enrolled'),
                  const SizedBox(width: 16),
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${course.rating.toStringAsFixed(1)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(CourseStatus status) {
    Color color;
    String label;
    switch (status) {
      case CourseStatus.draft:
        color = Colors.orange;
        label = 'Draft';
        break;
      case CourseStatus.published:
        color = Colors.green;
        label = 'Published';
        break;
      case CourseStatus.archived:
        color = Colors.grey;
        label = 'Archived';
        break;
      case CourseStatus.underReview:
        color = Colors.blue;
        label = 'Under Review';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Create course form widget
class CreateCourseForm extends StatefulWidget {
  const CreateCourseForm({super.key});

  @override
  State<CreateCourseForm> createState() => _CreateCourseFormState();
}

class _CreateCourseFormState extends State<CreateCourseForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _authorController = TextEditingController();
  final _tagsController = TextEditingController();
  final _skillsController = TextEditingController();
  
  String _difficulty = 'beginner';
  int _estimatedHours = 1;
  bool _isPublic = false;
  bool _isFeatured = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Course',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Course Title *',
                hintText: 'Enter a descriptive course title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a course title';
                }
                if (value.trim().length < 10) {
                  return 'Title must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Course Description *',
                hintText: 'Describe what students will learn',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a course description';
                }
                if (value.trim().length < 50) {
                  return 'Description must be at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      hintText: 'e.g., Programming, Design',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a category';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty *',
                      border: OutlineInputBorder(),
                    ),
                    items: ['beginner', 'intermediate', 'advanced']
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(level.capitalize()),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _difficulty = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author *',
                      hintText: 'Instructor name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter the author name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Estimated Hours',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: _estimatedHours.toString(),
                    onChanged: (value) {
                      final hours = int.tryParse(value);
                      if (hours != null && hours > 0) {
                        _estimatedHours = hours;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Comma-separated tags (e.g., javascript, web, react)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Skills Acquired',
                hintText: 'Comma-separated skills (e.g., HTML, CSS, JavaScript)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Public Course'),
                    subtitle: const Text('Make course visible to all users'),
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value!),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Featured Course'),
                    subtitle: const Text('Highlight on homepage'),
                    value: _isFeatured,
                    onChanged: (value) => setState(() => _isFeatured = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createCourse,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create Course'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final skills = _skillsController.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();

      await CourseService.createCourse(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        difficulty: _difficulty,
        author: _authorController.text.trim(),
        tags: tags,
        skillsAcquired: skills,
        estimatedHours: _estimatedHours,
        isPublic: _isPublic,
        isFeatured: _isFeatured,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully!')),
        );
        
        // Clear form
        _formKey.currentState!.reset();
        _titleController.clear();
        _descriptionController.clear();
        _categoryController.clear();
        _authorController.clear();
        _tagsController.clear();
        _skillsController.clear();
        setState(() {
          _difficulty = 'beginner';
          _estimatedHours = 1;
          _isPublic = false;
          _isFeatured = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating course: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _authorController.dispose();
    _tagsController.dispose();
    _skillsController.dispose();
    super.dispose();
  }
}

/// Course analytics view
class CourseAnalyticsView extends StatefulWidget {
  const CourseAnalyticsView({super.key});

  @override
  State<CourseAnalyticsView> createState() => _CourseAnalyticsViewState();
}

class _CourseAnalyticsViewState extends State<CourseAnalyticsView> {
  List<Course> _courses = [];
  String? _selectedCourseId;
  CourseAnalytics? _analytics;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final courses = await CourseService.getCourses();
    setState(() {
      _courses = courses;
      if (courses.isNotEmpty && _selectedCourseId == null) {
        _selectedCourseId = courses.first.id;
        _loadAnalytics();
      }
    });
  }

  Future<void> _loadAnalytics() async {
    if (_selectedCourseId == null) return;

    setState(() => _isLoading = true);
    try {
      final analytics = await CourseService.getCourseAnalytics(_selectedCourseId!);
      setState(() {
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Course Analytics',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          
          if (_courses.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedCourseId,
              decoration: const InputDecoration(
                labelText: 'Select Course',
                border: OutlineInputBorder(),
              ),
              items: _courses.map((course) => DropdownMenuItem(
                value: course.id,
                child: Text(course.title),
              )).toList(),
              onChanged: (value) {
                setState(() => _selectedCourseId = value);
                _loadAnalytics();
              },
            ),
          
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_analytics != null)
            Expanded(child: _buildAnalyticsContent())
          else
            const Center(child: Text('No analytics data available')),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final analytics = _analytics!;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics
          Row(
            children: [
              Expanded(child: _buildMetricCard(
                'Total Enrollments',
                analytics.totalEnrollments.toString(),
                Icons.people,
                Colors.blue,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(
                'Completion Rate',
                '${(analytics.completionRate * 100).toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green,
              )),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(child: _buildMetricCard(
                'Average Rating',
                analytics.averageRating.toStringAsFixed(1),
                Icons.star,
                Colors.amber,
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard(
                'Avg. Completion Time',
                '${analytics.averageCompletionTime}h',
                Icons.schedule,
                Colors.purple,
              )),
            ],
          ),
          const SizedBox(height: 24),
          
          // Engagement metrics
          Text(
            'Engagement Metrics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildEngagementRow('Avg. Session Duration', 
                      '${analytics.engagementMetrics.averageSessionDuration.toStringAsFixed(1)} min'),
                  _buildEngagementRow('Avg. Lessons per Session', 
                      analytics.engagementMetrics.averageLessonsPerSession.toStringAsFixed(1)),
                  _buildEngagementRow('Weekly Active Users', 
                      analytics.engagementMetrics.weeklyActiveUsers.toString()),
                  _buildEngagementRow('Monthly Active Users', 
                      analytics.engagementMetrics.monthlyActiveUsers.toString()),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Popular lessons
          if (analytics.popularLessons.isNotEmpty) ...[
            Text(
              'Popular Lessons',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            ...analytics.popularLessons.map((lesson) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.2),
                  child: const Icon(Icons.school, color: Colors.green),
                ),
                title: Text('Lesson ${lesson.lessonId}'),
                subtitle: Text('Completion: ${(lesson.completionRate * 100).toStringAsFixed(1)}%'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber),
                    Text(' ${lesson.averageRating.toStringAsFixed(1)}'),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Course details screen
class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({super.key, required this.course});

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  CourseWithContent? _courseContent;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCourseContent();
  }

  Future<void> _loadCourseContent() async {
    setState(() => _isLoading = true);
    try {
      final content = await CourseService.getCourseWithContent(widget.course.id);
      setState(() {
        _courseContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditCourseScreen(course: widget.course),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courseContent != null
              ? _buildCourseContent()
              : const Center(child: Text('Error loading course content')),
    );
  }

  Widget _buildCourseContent() {
    final content = _courseContent!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course info
          Text(
            content.course.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          
          // Course series
          if (content.series.isNotEmpty) ...[
            Text(
              'Course Series',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            
            ...content.series.map((series) => Card(
              child: ExpansionTile(
                title: Text(series.title),
                subtitle: Text(series.description),
                children: series.lessonIds.map((lessonId) {
                  final lesson = content.lessons.firstWhere(
                    (l) => l.id == lessonId,
                    orElse: () => content.lessons.first,
                  );
                  return ListTile(
                    title: Text(lesson.title),
                    subtitle: Text(lesson.description ?? ''),
                    leading: const Icon(Icons.play_lesson),
                  );
                }).toList(),
              ),
            )),
          ],
          
          const SizedBox(height: 16),
          
          // All lessons
          Text(
            'All Lessons (${content.lessons.length})',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          
          ...content.lessons.map((lesson) => Card(
            child: ListTile(
              title: Text(lesson.title),
              subtitle: Text(lesson.description ?? ''),
              leading: const Icon(Icons.school),
              trailing: Text('${lesson.terms.length} terms'),
            ),
          )),
        ],
      ),
    );
  }
}

/// Edit course screen placeholder
class EditCourseScreen extends StatelessWidget {
  final Course course;

  const EditCourseScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${course.title}'),
      ),
      body: const Center(
        child: Text('Edit course functionality coming soon...'),
      ),
    );
  }
}

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
