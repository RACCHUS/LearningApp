import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_pwa/providers/available_lessons_provider.dart';
import 'package:learning_pwa/providers/learning_context_provider.dart';
import 'package:learning_pwa/providers/user_curriculum_resource_provider.dart';
import 'package:learning_pwa/services/user_curriculum_resource_service.dart';

const String kPersonalAttachmentSuccessMessage =
    'Lesson created and added to this topic';
const String kPersonalAttachmentFailureMessage =
    "Lesson created, but we couldn't attach it to this topic";

enum AttachmentStatus {
  idle,
  attaching,
  success,
  failed,
}

class PersonalAttachmentController extends ChangeNotifier {
  final UserCurriculumResourceService resourceService;
  final String curriculumNodeId;
  final String lessonId;
  final String lessonTitle;
  final String? nodeTitle;

  AttachmentStatus status = AttachmentStatus.idle;
  String? errorMessage;
  int attachAttempts = 0;

  PersonalAttachmentController({
    required this.resourceService,
    required this.curriculumNodeId,
    required this.lessonId,
    required this.lessonTitle,
    this.nodeTitle,
  });

  Future<bool> attach() async {
    attachAttempts++;
    status = AttachmentStatus.attaching;
    errorMessage = null;
    notifyListeners();

    try {
      await resourceService.attachPersonalLesson(
        curriculumNodeId: curriculumNodeId,
        lessonId: lessonId,
      );
      status = AttachmentStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      status = AttachmentStatus.failed;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

/// Attempts to attach a created lesson to a curriculum topic.
///
/// On success: shows success feedback and returns true.
/// On failure: opens a dialog displaying the failure copy and offering
/// a "Retry attachment" action. Returns true if retry succeeds, or false
/// if the user dismisses. The lesson remains preserved in Library regardless.
Future<bool> handlePersonalStudyAttachment({
  required BuildContext context,
  required WidgetRef ref,
  required String lessonId,
  required String lessonTitle,
  required String curriculumNodeId,
  String? nodeTitle,
}) async {
  final resourceService = ref.read(userCurriculumResourceServiceProvider);
  final controller = PersonalAttachmentController(
    resourceService: resourceService,
    curriculumNodeId: curriculumNodeId,
    lessonId: lessonId,
    lessonTitle: lessonTitle,
    nodeTitle: nodeTitle,
  );

  final success = await controller.attach();
  if (success) {
    _invalidateTargetAndCatalog(ref, curriculumNodeId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kPersonalAttachmentSuccessMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  }

  // Failed initial attachment: keep creation result open with Retry attachment
  if (!context.mounted) return false;

  final attachedOnRetry = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PersonalAttachmentResultDialog(
      controller: controller,
      onAttached: () => _invalidateTargetAndCatalog(ref, curriculumNodeId),
    ),
  );

  return attachedOnRetry ?? false;
}

void _invalidateTargetAndCatalog(WidgetRef ref, String curriculumNodeId) {
  ref.invalidate(userCurriculumResourcesForNodeProvider(curriculumNodeId));
  ref.invalidate(availableLessonsCatalogProvider);
  ref.invalidate(remoteCatalogLessonsProvider);
  ref.invalidate(learningContextsProvider);
}

class PersonalAttachmentResultDialog extends StatefulWidget {
  final PersonalAttachmentController controller;
  final VoidCallback? onAttached;

  const PersonalAttachmentResultDialog({
    super.key,
    required this.controller,
    this.onAttached,
  });

  @override
  State<PersonalAttachmentResultDialog> createState() =>
      _PersonalAttachmentResultDialogState();
}

class _PersonalAttachmentResultDialogState
    extends State<PersonalAttachmentResultDialog> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Topic Attachment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            kPersonalAttachmentFailureMessage,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your lesson was saved to your Library, but we could not link it to this topic right now.',
          ),
          if (_isRetrying) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('keep_in_library_button'),
          onPressed: _isRetrying
              ? null
              : () {
                  Navigator.of(context).pop(false);
                },
          child: const Text('Keep in Library'),
        ),
        FilledButton(
          key: const Key('retry_attachment_button'),
          onPressed: _isRetrying
              ? null
              : () async {
                  setState(() => _isRetrying = true);
                  final ok = await widget.controller.attach();
                  setState(() => _isRetrying = false);
                  if (ok && mounted) {
                    widget.onAttached?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(kPersonalAttachmentSuccessMessage),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.of(context).pop(true);
                  }
                },
          child: const Text('Retry attachment'),
        ),
      ],
    );
  }
}
