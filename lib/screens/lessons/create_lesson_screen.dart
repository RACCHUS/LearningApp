import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:learning_pwa/services/lesson_service.dart';
import 'package:learning_pwa/widgets/lesson_json_import_widget.dart';
import 'package:learning_pwa/widgets/lesson_builder_widget.dart';

class CreateLessonScreen extends ConsumerStatefulWidget {
  const CreateLessonScreen({super.key});

  @override
  ConsumerState<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends ConsumerState<CreateLessonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _createLessonFromJson(String jsonData) async {
    setState(() => _isLoading = true);
    
    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthSuccess ? authState.user.id : 'guest';
      
      final lessonService = LessonService();
      final lesson = await lessonService.importLessonFromJson(jsonData, userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lesson "${lesson.title}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(lesson);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating lesson: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLessonFromBuilder({
    required String title,
    required String description,
    required List<String> tags,
    required List<Map<String, dynamic>> content,
  }) async {
    setState(() => _isLoading = true);
    
    try {
      final authState = ref.read(authProvider);
      final userId = authState is AuthSuccess ? authState.user.id : 'guest';
      
      final lessonService = LessonService();
      
      // Create lesson JSON structure
      final lessonJson = {
        'lesson': {
          'title': title,
          'description': description,
          'tags': tags,
          'createdBy': userId,
        },
        'content': content,
      };
      
      final lesson = await lessonService.importLessonFromJson(
        jsonEncode(lessonJson), 
        userId,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lesson "${lesson.title}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(lesson);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating lesson: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Lesson'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.code),
              text: 'JSON Import',
            ),
            Tab(
              icon: Icon(Icons.build),
              text: 'Lesson Builder',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating lesson...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                LessonJsonImportWidget(
                  onImport: _createLessonFromJson,
                ),
                LessonBuilderWidget(
                  onCreateLesson: _createLessonFromBuilder,
                ),
              ],
            ),
    );
  }
}
