import '../models/video_interactive_module.dart';

/// Metadata resulting from resolving a raw video URL into an embeddable format.
class VideoPlatformInfo {
  final VideoSourceType sourceType;
  final String videoId;
  final String embedUrl;
  final int? initialTimestampSeconds;
  final bool isPrivacyEnhanced;

  const VideoPlatformInfo({
    required this.sourceType,
    required this.videoId,
    required this.embedUrl,
    this.initialTimestampSeconds,
    this.isPrivacyEnhanced = true,
  });

  Map<String, dynamic> toJson() => {
        'source_type': sourceType.toDbString(),
        'video_id': videoId,
        'embed_url': embedUrl,
        if (initialTimestampSeconds != null)
          'initial_timestamp_seconds': initialTimestampSeconds,
        'is_privacy_enhanced': isPrivacyEnhanced,
      };
}

/// Resolves standard public video streaming URLs (YouTube, Vimeo, PeerTube, MP4)
/// into privacy-preserving, embeddable URLs with interactive control hooks.
class VideoEmbedResolver {
  const VideoEmbedResolver._();

  static final RegExp _youtubeIdPattern = RegExp(
    r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([a-zA-Z0-9_-]{11})',
  );

  static final RegExp _vimeoIdPattern = RegExp(
    r'vimeo\.com\/(?:channels\/(?:\w+\/)?|groups\/(?:[^\/]*)\/videos\/|video\/|)(\d+)',
  );

  static final RegExp _peertubePattern = RegExp(
    r'^(https?:\/\/[^\/]+)\/(?:videos\/watch|videos\/embed|w)\/([a-zA-Z0-9_-]+)',
  );

  /// Resolves [rawUrl] into an embed-safe [VideoPlatformInfo].
  static VideoPlatformInfo resolve(
    String rawUrl, {
    bool autoPlay = false,
    bool controls = true,
    int? startSeconds,
  }) {
    final uri = Uri.tryParse(rawUrl.trim());
    final trimmedUrl = rawUrl.trim();

    // 1. YouTube
    final ytMatch = _youtubeIdPattern.firstMatch(trimmedUrl);
    if (ytMatch != null) {
      final videoId = ytMatch.group(1)!;
      final parsedStart = startSeconds ?? _extractYoutubeTimestamp(uri);

      final queryParams = <String, String>{
        'enablejsapi': '1',
        'rel': '0',
      };
      if (autoPlay) queryParams['autoplay'] = '1';
      if (!controls) queryParams['controls'] = '0';
      if (parsedStart != null && parsedStart > 0) {
        queryParams['start'] = parsedStart.toString();
      }

      final queryStr = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      return VideoPlatformInfo(
        sourceType: VideoSourceType.youtube,
        videoId: videoId,
        embedUrl: 'https://www.youtube-nocookie.com/embed/$videoId?$queryStr',
        initialTimestampSeconds: parsedStart,
        isPrivacyEnhanced: true,
      );
    }

    // 2. Vimeo
    final vimeoMatch = _vimeoIdPattern.firstMatch(trimmedUrl);
    if (vimeoMatch != null) {
      final videoId = vimeoMatch.group(1)!;
      final parsedStart = startSeconds ?? _extractVimeoTimestamp(uri);

      final queryParams = <String, String>{
        'dnt': '1', // Do Not Track header
      };
      if (autoPlay) queryParams['autoplay'] = '1';

      var embed = 'https://player.vimeo.com/video/$videoId?dnt=1';
      if (autoPlay) embed += '&autoplay=1';
      if (parsedStart != null && parsedStart > 0) {
        embed += '#t=${parsedStart}s';
      }

      return VideoPlatformInfo(
        sourceType: VideoSourceType.vimeo,
        videoId: videoId,
        embedUrl: embed,
        initialTimestampSeconds: parsedStart,
        isPrivacyEnhanced: true,
      );
    }

    // 3. PeerTube
    final peerMatch = _peertubePattern.firstMatch(trimmedUrl);
    if (peerMatch != null) {
      final host = peerMatch.group(1)!;
      final videoUuid = peerMatch.group(2)!;
      final parsedStart = startSeconds ?? _extractTimestampFromQuery(uri, ['start', 't']);

      var embed = '$host/videos/embed/$videoUuid';
      if (autoPlay || (parsedStart != null && parsedStart > 0)) {
        final params = <String>[];
        if (autoPlay) params.add('autoplay=1');
        if (parsedStart != null && parsedStart > 0) {
          params.add('start=${parsedStart}s');
        }
        embed += '?${params.join('&')}';
      }

      return VideoPlatformInfo(
        sourceType: VideoSourceType.peertube,
        videoId: videoUuid,
        embedUrl: embed,
        initialTimestampSeconds: parsedStart,
        isPrivacyEnhanced: true,
      );
    }

    // 4. Direct MP4 fallback
    final parsedStart = startSeconds ?? _extractTimestampFromQuery(uri, ['t', 'start']);
    return VideoPlatformInfo(
      sourceType: VideoSourceType.directMp4,
      videoId: uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : 'direct',
      embedUrl: trimmedUrl,
      initialTimestampSeconds: parsedStart,
      isPrivacyEnhanced: false,
    );
  }

  /// Parses diverse timestamp formats into total seconds:
  /// Examples: `90`, `90s`, `1m30s`, `1h20m10s`, `01:30`, `01:15:20`.
  static int? parseTimestamp(String? raw) {
    if (raw == null) return null;
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    // Direct integer
    final direct = int.tryParse(text);
    if (direct != null) return direct;

    // Suffix format: e.g. 90s
    if (RegExp(r'^\d+s$').hasMatch(text)) {
      return int.tryParse(text.replaceAll('s', ''));
    }

    // Combined h/m/s format: e.g. 1h2m3s, 2m30s, 45s
    final hmsPattern = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$');
    final match = hmsPattern.firstMatch(text);
    if (match != null && (match.group(1) != null || match.group(2) != null || match.group(3) != null)) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
      return hours * 3600 + minutes * 60 + seconds;
    }

    // Clock format: mm:ss or hh:mm:ss
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;
        return hours * 3600 + minutes * 60 + seconds;
      }
    }

    return null;
  }

  /// Formats seconds into standard clock notation (`mm:ss` or `hh:mm:ss`).
  static String formatTimestamp(int seconds) {
    if (seconds < 0) return '00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');

    if (h > 0) {
      return '$h:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  static int? _extractYoutubeTimestamp(Uri? uri) {
    if (uri == null) return null;
    final t = uri.queryParameters['t'] ?? uri.queryParameters['start'];
    return parseTimestamp(t);
  }

  static int? _extractVimeoTimestamp(Uri? uri) {
    if (uri == null) return null;
    final hash = uri.fragment;
    if (hash.startsWith('t=')) {
      return parseTimestamp(hash.replaceFirst('t=', ''));
    }
    return _extractTimestampFromQuery(uri, ['t', 'start']);
  }

  static int? _extractTimestampFromQuery(Uri? uri, List<String> keys) {
    if (uri == null) return null;
    for (final key in keys) {
      if (uri.queryParameters.containsKey(key)) {
        return parseTimestamp(uri.queryParameters[key]);
      }
    }
    return null;
  }
}
