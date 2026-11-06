import 'assessment_item.dart';

/// Supported video streaming platforms for embed-first interactive modules.
enum VideoSourceType {
  youtube,
  vimeo,
  peertube,
  directMp4;

  static VideoSourceType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'youtube':
        return VideoSourceType.youtube;
      case 'vimeo':
        return VideoSourceType.vimeo;
      case 'peertube':
        return VideoSourceType.peertube;
      case 'direct_mp4':
      case 'directmp4':
      case 'mp4':
        return VideoSourceType.directMp4;
      default:
        return VideoSourceType.youtube;
    }
  }

  String toDbString() {
    switch (this) {
      case VideoSourceType.youtube:
        return 'youtube';
      case VideoSourceType.vimeo:
        return 'vimeo';
      case VideoSourceType.peertube:
        return 'peertube';
      case VideoSourceType.directMp4:
        return 'direct_mp4';
    }
  }
}

/// Type of interactive checkpoint placed within the video timeline.
enum VideoCheckpointType {
  /// Priming prequestion asked before target video section (ER-10: g = .54).
  prequestion,

  /// In-video retrieval practice checkpoint pausing the stream.
  retrievalPractice,

  /// Reflection prompt without hard scoring.
  reflection;

  static VideoCheckpointType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'prequestion':
        return VideoCheckpointType.prequestion;
      case 'retrieval_practice':
      case 'retrievalpractice':
        return VideoCheckpointType.retrievalPractice;
      case 'reflection':
        return VideoCheckpointType.reflection;
      default:
        return VideoCheckpointType.retrievalPractice;
    }
  }

  String toDbString() {
    switch (this) {
      case VideoCheckpointType.prequestion:
        return 'prequestion';
      case VideoCheckpointType.retrievalPractice:
        return 'retrieval_practice';
      case VideoCheckpointType.reflection:
        return 'reflection';
    }
  }
}

/// A chapter boundary in the video mapped to a learning concept.
class VideoChapter {
  final int startSeconds;
  final int endSeconds;
  final String title;
  final String? conceptSlug;

  const VideoChapter({
    required this.startSeconds,
    required this.endSeconds,
    required this.title,
    this.conceptSlug,
  });

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    return VideoChapter(
      startSeconds: json['start_seconds'] as int? ?? 0,
      endSeconds: json['end_seconds'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      conceptSlug: json['concept_slug'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'start_seconds': startSeconds,
        'end_seconds': endSeconds,
        'title': title,
        if (conceptSlug != null) 'concept_slug': conceptSlug,
      };
}

/// An interactive assessment checkpoint triggered at [timestampSeconds].
class VideoCheckpoint {
  final String id;
  final int timestampSeconds;
  final VideoCheckpointType type;
  final AssessmentItemCore item;
  final String? targetConceptSlug;
  final bool resumeOnComplete;

  const VideoCheckpoint({
    required this.id,
    required this.timestampSeconds,
    required this.type,
    required this.item,
    this.targetConceptSlug,
    this.resumeOnComplete = true,
  });

  factory VideoCheckpoint.fromJson(Map<String, dynamic> json) {
    return VideoCheckpoint(
      id: json['id'] as String? ?? '',
      timestampSeconds: json['timestamp_seconds'] as int? ?? 0,
      type: VideoCheckpointType.fromString(
          json['type'] as String? ?? 'retrieval_practice'),
      item: AssessmentItemCore.fromJson(
          (json['item'] as Map?)?.cast<String, dynamic>() ?? {}),
      targetConceptSlug: json['target_concept_slug'] as String?,
      resumeOnComplete: json['resume_on_complete'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp_seconds': timestampSeconds,
        'type': type.toDbString(),
        'item': item.toJson(),
        if (targetConceptSlug != null)
          'target_concept_slug': targetConceptSlug,
        'resume_on_complete': resumeOnComplete,
      };
}

/// Profile metadata for an educational content creator or channel.
class CreatorProfileCore {
  final String id;
  final String channelName;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  const CreatorProfileCore({
    required this.id,
    required this.channelName,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory CreatorProfileCore.fromJson(Map<String, dynamic> json) {
    return CreatorProfileCore(
      id: json['id'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel_name': channelName,
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (bio != null) 'bio': bio,
      };
}

/// Complete interactive video learning module (OPP-2, ER-10).
class VideoInteractiveModule {
  final String id;
  final String title;
  final String description;
  final VideoSourceType sourceType;
  final String rawVideoUrl;
  final int durationSeconds;
  final CreatorProfileCore? creator;
  final List<VideoChapter> chapters;
  final List<VideoCheckpoint> checkpoints;
  final double? measuredLearningGain;

  const VideoInteractiveModule({
    required this.id,
    required this.title,
    this.description = '',
    required this.sourceType,
    required this.rawVideoUrl,
    required this.durationSeconds,
    this.creator,
    this.chapters = const [],
    this.checkpoints = const [],
    this.measuredLearningGain,
  });

  factory VideoInteractiveModule.fromJson(Map<String, dynamic> json) {
    final rawChapters = (json['chapters'] as List?) ?? [];
    final rawCheckpoints = (json['checkpoints'] as List?) ?? [];

    final chaptersList = rawChapters
        .map((c) => VideoChapter.fromJson((c as Map).cast<String, dynamic>()))
        .toList();

    final checkpointsList = rawCheckpoints
        .map((cp) =>
            VideoCheckpoint.fromJson((cp as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.timestampSeconds.compareTo(b.timestampSeconds));

    return VideoInteractiveModule(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sourceType: VideoSourceType.fromString(
          json['source_type'] as String? ?? 'youtube'),
      rawVideoUrl: json['raw_video_url'] as String? ?? '',
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      creator: json['creator'] != null
          ? CreatorProfileCore.fromJson(
              (json['creator'] as Map).cast<String, dynamic>())
          : null,
      chapters: chaptersList,
      checkpoints: checkpointsList,
      measuredLearningGain: (json['measured_learning_gain'] as num?)?.toDouble(),
    );
  }

  /// Checkpoints configured as priming prequestions (ER-10).
  List<VideoCheckpoint> get prequestions =>
      checkpoints.where((cp) => cp.type == VideoCheckpointType.prequestion).toList();

  /// Checkpoints configured as active retrieval practice pauses.
  List<VideoCheckpoint> get retrievalCheckpoints =>
      checkpoints.where((cp) => cp.type == VideoCheckpointType.retrievalPractice).toList();

  /// Checkpoints configured as reflection prompts.
  List<VideoCheckpoint> get reflectionCheckpoints =>
      checkpoints.where((cp) => cp.type == VideoCheckpointType.reflection).toList();

  /// Returns the video chapter corresponding to [seconds] elapsed.
  VideoChapter? chapterForTimestamp(int seconds) {
    for (final chapter in chapters) {
      if (seconds >= chapter.startSeconds && seconds <= chapter.endSeconds) {
        return chapter;
      }
    }
    return null;
  }

  /// Finds any checkpoint triggered within [toleranceSeconds] of [seconds].
  VideoCheckpoint? checkpointAt(int seconds, {int toleranceSeconds = 1}) {
    for (final cp in checkpoints) {
      if ((cp.timestampSeconds - seconds).abs() <= toleranceSeconds) {
        return cp;
      }
    }
    return null;
  }

  /// Returns the next upcoming checkpoint strictly after [currentSeconds].
  VideoCheckpoint? nextCheckpoint(int currentSeconds) {
    for (final cp in checkpoints) {
      if (cp.timestampSeconds > currentSeconds) {
        return cp;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'source_type': sourceType.toDbString(),
        'raw_video_url': rawVideoUrl,
        'duration_seconds': durationSeconds,
        if (creator != null) 'creator': creator!.toJson(),
        'chapters': chapters.map((c) => c.toJson()).toList(),
        'checkpoints': checkpoints.map((cp) => cp.toJson()).toList(),
        if (measuredLearningGain != null)
          'measured_learning_gain': measuredLearningGain,
      };
}
