import 'package:learning_core/learning_core.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEmbedResolver', () {
    test('resolves standard YouTube watch URL to youtube-nocookie embed', () {
      final info = VideoEmbedResolver.resolve('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

      expect(info.sourceType, equals(VideoSourceType.youtube));
      expect(info.videoId, equals('dQw4w9WgXcQ'));
      expect(info.isPrivacyEnhanced, isTrue);
      expect(
        info.embedUrl,
        equals('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1&rel=0'),
      );
      expect(info.initialTimestampSeconds, isNull);
    });

    test('resolves short youtu.be URL with timestamp parameter', () {
      final info = VideoEmbedResolver.resolve('https://youtu.be/dQw4w9WgXcQ?t=1m30s');

      expect(info.sourceType, equals(VideoSourceType.youtube));
      expect(info.videoId, equals('dQw4w9WgXcQ'));
      expect(info.initialTimestampSeconds, equals(90));
      expect(
        info.embedUrl,
        equals('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1&rel=0&start=90'),
      );
    });

    test('resolves Vimeo video URL with DNT privacy header and timestamp', () {
      final info = VideoEmbedResolver.resolve('https://vimeo.com/76979871#t=45s');

      expect(info.sourceType, equals(VideoSourceType.vimeo));
      expect(info.videoId, equals('76979871'));
      expect(info.isPrivacyEnhanced, isTrue);
      expect(info.initialTimestampSeconds, equals(45));
      expect(info.embedUrl, equals('https://player.vimeo.com/video/76979871?dnt=1#t=45s'));
    });

    test('resolves PeerTube instance URL to embed path', () {
      final info = VideoEmbedResolver.resolve(
        'https://peertube.example.org/videos/watch/01234567-89ab-cdef-0123-456789abcdef?start=120s',
      );

      expect(info.sourceType, equals(VideoSourceType.peertube));
      expect(info.videoId, equals('01234567-89ab-cdef-0123-456789abcdef'));
      expect(info.initialTimestampSeconds, equals(120));
      expect(
        info.embedUrl,
        equals('https://peertube.example.org/videos/embed/01234567-89ab-cdef-0123-456789abcdef?start=120s'),
      );
    });

    test('falls back cleanly to direct MP4 for arbitrary file links', () {
      final info = VideoEmbedResolver.resolve('https://cdn.example.com/lessons/intro.mp4?t=15');

      expect(info.sourceType, equals(VideoSourceType.directMp4));
      expect(info.videoId, equals('intro.mp4'));
      expect(info.initialTimestampSeconds, equals(15));
      expect(info.embedUrl, equals('https://cdn.example.com/lessons/intro.mp4?t=15'));
    });

    test('parseTimestamp parses diverse clock and duration strings', () {
      expect(VideoEmbedResolver.parseTimestamp('90'), equals(90));
      expect(VideoEmbedResolver.parseTimestamp('90s'), equals(90));
      expect(VideoEmbedResolver.parseTimestamp('1m30s'), equals(90));
      expect(VideoEmbedResolver.parseTimestamp('1h2m3s'), equals(3723));
      expect(VideoEmbedResolver.parseTimestamp('01:30'), equals(90));
      expect(VideoEmbedResolver.parseTimestamp('01:02:03'), equals(3723));
      expect(VideoEmbedResolver.parseTimestamp(''), isNull);
      expect(VideoEmbedResolver.parseTimestamp('invalid'), isNull);
    });

    test('formatTimestamp generates standard clock representation', () {
      expect(VideoEmbedResolver.formatTimestamp(0), equals('00:00'));
      expect(VideoEmbedResolver.formatTimestamp(45), equals('00:45'));
      expect(VideoEmbedResolver.formatTimestamp(90), equals('01:30'));
      expect(VideoEmbedResolver.formatTimestamp(3665), equals('1:01:05'));
    });
  });
}
