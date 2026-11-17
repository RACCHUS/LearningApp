import 'package:learning_pwa/models/learning_target.dart';

/// Which goals the Library lists (its "Source" menu). Trusted catalog is
/// the default: private or unreviewed personal goals appear only under
/// [CatalogSource.mine], and only to their creator.
///
/// Moved from `LibraryScreen` (code-efficiency plan §14, Pilot C). The
/// server's RLS is the real boundary; this is the client half, which must
/// never widen what the server returns.
enum CatalogSource {
  trusted('Trusted catalog'),
  official('Official'),
  reviewed('Reviewed community'),
  mine('My goals');

  final String label;
  const CatalogSource(this.label);

  /// Whether [target] is listed under this source for [userId] (null when
  /// signed out).
  bool shows(LearningTarget target, {required String? userId}) {
    switch (this) {
      case CatalogSource.trusted:
        return target.isTrustedPublic;
      case CatalogSource.official:
        return target.isTrustedPublic && target.isOfficial;
      case CatalogSource.reviewed:
        return target.isTrustedPublic &&
            !target.isOfficial && target.createdBy != null;
      case CatalogSource.mine:
        return userId != null && target.createdBy == userId;
    }
  }
}
