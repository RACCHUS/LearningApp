import 'package:learning_pwa/models/companion/learner_resource.dart';

export 'floating_companion_stub.dart'
    if (dart.library.js_interop) 'floating_companion_web.dart';

/// What the small floating window shows (companion plan v1.0 §5.1 layer L4,
/// EX-8): the part the learner is on, what to look for in it, and how long
/// they have been at it. Plain text only.
class FloatingContent {
  const FloatingContent({
    required this.resourceTitle,
    this.partTitle,
    this.minutes,
    this.lookFor = const [],
    this.partsLeft = 0,
  });

  final String resourceTitle;

  /// The first part not yet marked studied; null when every part is marked.
  final String? partTitle;
  final int? minutes;

  /// The goal's objectives matched to that part, in LearningApp's words.
  final List<String> lookFor;
  final int partsLeft;

  bool get allDone => partTitle == null;

  /// Built from the learner's resource and the goal's objective labels.
  factory FloatingContent.of(
    LearnerResource resource,
    Map<String, String> labelByKey,
  ) {
    final next = resource.nextSectionIndex;
    if (next == null) return FloatingContent(resourceTitle: resource.title);
    final part = resource.sections[next];
    return FloatingContent(
      resourceTitle: resource.title,
      partTitle: part.title,
      minutes: part.minutes,
      lookFor: [
        for (final key in labelByKey.keys)
          if (part.objectiveKeys.contains(key)) labelByKey[key]!,
      ],
      partsLeft: resource.sections.length - resource.studiedSectionCount,
    );
  }
}

/// A small always-on-top window beside whatever the learner is studying, on
/// desktop browsers that support Document Picture-in-Picture. It is opened
/// only by the learner's click, holds no player and watches nothing: the
/// timer is the learner's own and is never stored.
abstract class FloatingWindow {
  /// False on phones, tablets and browsers without the feature; the button
  /// that opens the window is then not shown at all.
  bool get supported;

  bool get isOpen;

  /// Opens the window. Returns false if the browser refused.
  /// [onDone]: the learner pressed "Done studying this part".
  /// [onClosed]: the window went away.
  Future<bool> open(
    FloatingContent content, {
    required void Function() onDone,
    required void Function() onClosed,
  });

  /// Replaces what the window shows. Does nothing when it is closed.
  void update(FloatingContent content);

  void close();
}
