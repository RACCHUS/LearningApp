/// Which outside videos may be played inside the companion (companion plan
/// v1.0 §5.1 layer L3, EX-7). One provider: YouTube, through its own
/// embedded player on the privacy-enhanced domain. Everything else opens
/// outside LearningApp.
class VideoEmbed {
  const VideoEmbed._();

  static const youTubeTermsUrl = 'https://www.youtube.com/t/terms';
  static const googlePrivacyUrl = 'https://www.google.com/policies/privacy';
  static const embedHost = 'www.youtube-nocookie.com';

  /// LearningApp's own published privacy and terms for outside study and
  /// this player (`web/outside-study-privacy.html`), which YouTube's API
  /// Services policies require before the player is offered.
  static const appPrivacyPath = '/outside-study-privacy.html';

  /// [appPrivacyPath] on the site the app was loaded from.
  static Uri appPrivacyUri([Uri? base]) =>
      (base ?? Uri.base).resolve(appPrivacyPath);

  static final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static const _watchHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'www.youtube-nocookie.com',
  };

  /// The video id in a YouTube link, or null when [url] is not a link to a
  /// single YouTube video (a playlist, a channel, another site).
  static String? youTubeId(String? url) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    String? id;
    if (host == 'youtu.be') {
      id = uri.pathSegments.firstOrNull;
    } else if (_watchHosts.contains(host)) {
      final s = uri.pathSegments;
      if (s.length == 1 && s[0] == 'watch') {
        id = uri.queryParameters['v'];
      } else if (s.length == 2 &&
          const {'embed', 'shorts', 'live'}.contains(s[0])) {
        id = s[1];
      }
    }
    return id != null && _id.hasMatch(id) ? id : null;
  }

  /// The provider's own player page for [id]. Only parameters YouTube
  /// documents are used; the player itself is never changed or covered.
  static Uri youTubeEmbedUri(String id, {int? startSeconds}) =>
      Uri.https(embedHost, '/embed/$id', {
        'playsinline': '1',
        if (startSeconds != null && startSeconds > 0) 'start': '$startSeconds',
      });

  /// "2:15" or "1:02:33".
  static String clock(int seconds) {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}
