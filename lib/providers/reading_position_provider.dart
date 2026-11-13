import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The block currently at the top of the reader for a lesson (by lesson ID).
/// In memory only; used to record an exact return position when learning
/// help opens (master plan v2.6 §10.5).
final readingBlockProvider = StateProvider.family<String?, String>(
  (ref, lessonId) => null,
);

/// A block the reader should scroll back to once, e.g. after a refresh in
/// the middle of learning help. Cleared after the reader handles it.
final pendingReturnBlockProvider = StateProvider.family<String?, String>(
  (ref, lessonId) => null,
);
