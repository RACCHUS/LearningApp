/// Content types of standalone educational resources authored by community creators.
enum CommunityResourceContentType {
  lesson,
  flashcardSet,
  studyGuide,
  cheatSheet;

  String toDbString() {
    switch (this) {
      case CommunityResourceContentType.lesson:
        return 'lesson';
      case CommunityResourceContentType.flashcardSet:
        return 'flashcard_set';
      case CommunityResourceContentType.studyGuide:
        return 'study_guide';
      case CommunityResourceContentType.cheatSheet:
        return 'cheat_sheet';
    }
  }

  static CommunityResourceContentType fromDbString(String? val) {
    switch (val) {
      case 'flashcard_set':
      case 'flashcards':
        return CommunityResourceContentType.flashcardSet;
      case 'study_guide':
        return CommunityResourceContentType.studyGuide;
      case 'cheat_sheet':
        return CommunityResourceContentType.cheatSheet;
      case 'lesson':
      default:
        return CommunityResourceContentType.lesson;
    }
  }

  String get label {
    switch (this) {
      case CommunityResourceContentType.lesson:
        return 'Micro-Lesson';
      case CommunityResourceContentType.flashcardSet:
        return 'Flashcard Deck';
      case CommunityResourceContentType.studyGuide:
        return 'Study Guide';
      case CommunityResourceContentType.cheatSheet:
        return 'Quick Reference';
    }
  }
}

/// Publication and editorial review status for community resources.
enum CommunityResourceStatus {
  draft,
  submittedForReview,
  underReview,
  approved,
  published,
  archived;

  String toDbString() {
    switch (this) {
      case CommunityResourceStatus.draft:
        return 'draft';
      case CommunityResourceStatus.submittedForReview:
        return 'submitted_for_review';
      case CommunityResourceStatus.underReview:
        return 'under_review';
      case CommunityResourceStatus.approved:
        return 'approved';
      case CommunityResourceStatus.published:
        return 'published';
      case CommunityResourceStatus.archived:
        return 'archived';
    }
  }

  static CommunityResourceStatus fromDbString(String? val) {
    switch (val) {
      case 'submitted_for_review':
        return CommunityResourceStatus.submittedForReview;
      case 'under_review':
        return CommunityResourceStatus.underReview;
      case 'approved':
        return CommunityResourceStatus.approved;
      case 'published':
        return CommunityResourceStatus.published;
      case 'archived':
        return CommunityResourceStatus.archived;
      case 'draft':
      default:
        return CommunityResourceStatus.draft;
    }
  }

  String get label {
    switch (this) {
      case CommunityResourceStatus.draft:
        return 'Draft';
      case CommunityResourceStatus.submittedForReview:
        return 'Submitted for Review';
      case CommunityResourceStatus.underReview:
        return 'Under Review';
      case CommunityResourceStatus.approved:
        return 'Approved';
      case CommunityResourceStatus.published:
        return 'Published';
      case CommunityResourceStatus.archived:
        return 'Archived';
    }
  }
}

/// Authoritative regulatory or curricular citation supporting a community resource.
class ResourceCitation {
  final String id;
  final String title;
  final String authorityCode;
  final String jurisdiction;
  final String? sourceUrl;
  final bool verified;
  final String? notes;

  const ResourceCitation({
    required this.id,
    required this.title,
    required this.authorityCode,
    this.jurisdiction = 'US-Federal',
    this.sourceUrl,
    this.verified = false,
    this.notes,
  });

  factory ResourceCitation.fromJson(Map<String, dynamic> json) {
    return ResourceCitation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      authorityCode: json['authority_code'] as String? ?? '',
      jurisdiction: json['jurisdiction'] as String? ?? 'US-Federal',
      sourceUrl: json['source_url'] as String?,
      verified: json['verified'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'authority_code': authorityCode,
        'jurisdiction': jurisdiction,
        if (sourceUrl != null) 'source_url': sourceUrl,
        'verified': verified,
        if (notes != null) 'notes': notes,
      };

  ResourceCitation copyWith({
    String? id,
    String? title,
    String? authorityCode,
    String? jurisdiction,
    String? sourceUrl,
    bool? verified,
    String? notes,
  }) {
    return ResourceCitation(
      id: id ?? this.id,
      title: title ?? this.title,
      authorityCode: authorityCode ?? this.authorityCode,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      verified: verified ?? this.verified,
      notes: notes ?? this.notes,
    );
  }
}

/// An individual card within a community flashcard deck.
class FlashcardCard {
  final String id;
  final String front;
  final String back;
  final String? audioPrompt;
  final String? tip;

  const FlashcardCard({
    required this.id,
    required this.front,
    required this.back,
    this.audioPrompt,
    this.tip,
  });

  factory FlashcardCard.fromJson(Map<String, dynamic> json) {
    return FlashcardCard(
      id: json['id'] as String? ?? '',
      front: json['front'] as String? ?? '',
      back: json['back'] as String? ?? '',
      audioPrompt: json['audio_prompt'] as String?,
      tip: json['tip'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'front': front,
        'back': back,
        if (audioPrompt != null) 'audio_prompt': audioPrompt,
        if (tip != null) 'tip': tip,
      };
}

/// A structured section within a community study guide.
class StudyGuideSection {
  final String id;
  final String heading;
  final String bodyMarkdown;
  final List<String> citationIds;
  final String? keyTakeaway;

  const StudyGuideSection({
    required this.id,
    required this.heading,
    required this.bodyMarkdown,
    this.citationIds = const [],
    this.keyTakeaway,
  });

  factory StudyGuideSection.fromJson(Map<String, dynamic> json) {
    return StudyGuideSection(
      id: json['id'] as String? ?? '',
      heading: json['heading'] as String? ?? '',
      bodyMarkdown: json['body_markdown'] as String? ?? '',
      citationIds: (json['citation_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      keyTakeaway: json['key_takeaway'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'heading': heading,
        'body_markdown': bodyMarkdown,
        'citation_ids': citationIds,
        if (keyTakeaway != null) 'key_takeaway': keyTakeaway,
      };
}

/// Standalone community-authored resource (ECO-06, Phase 3).
class CommunityResource {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorHeadline;
  final String subjectId;
  final String topic;
  final String title;
  final String description;
  final CommunityResourceContentType contentType;
  final CommunityResourceStatus status;
  final String license;
  final bool isAiAssisted;
  final List<ResourceCitation> citations;
  final String? lessonMarkdown;
  final List<FlashcardCard> flashcards;
  final List<StudyGuideSection> guideSections;
  final int feedbackCount;
  final double averageRating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final String? rejectionReason;

  const CommunityResource({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorHeadline,
    required this.subjectId,
    required this.topic,
    required this.title,
    this.description = '',
    required this.contentType,
    this.status = CommunityResourceStatus.draft,
    this.license = 'CC-BY-4.0',
    this.isAiAssisted = false,
    this.citations = const [],
    this.lessonMarkdown,
    this.flashcards = const [],
    this.guideSections = const [],
    this.feedbackCount = 0,
    this.averageRating = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.rejectionReason,
  });

  factory CommunityResource.fromJson(Map<String, dynamic> json) {
    return CommunityResource(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Educator',
      authorHeadline: json['author_headline'] as String?,
      subjectId: json['subject_id'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contentType: CommunityResourceContentType.fromDbString(
          json['content_type'] as String?),
      status:
          CommunityResourceStatus.fromDbString(json['status'] as String?),
      license: json['license'] as String? ?? 'CC-BY-4.0',
      isAiAssisted: json['is_ai_assisted'] as bool? ?? false,
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => ResourceCitation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      lessonMarkdown: json['lesson_markdown'] as String?,
      flashcards: (json['flashcards'] as List<dynamic>?)
              ?.map((e) => FlashcardCard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      guideSections: (json['guide_sections'] as List<dynamic>?)
              ?.map((e) =>
                  StudyGuideSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      feedbackCount: json['feedback_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author_id': authorId,
        'author_name': authorName,
        if (authorHeadline != null) 'author_headline': authorHeadline,
        'subject_id': subjectId,
        'topic': topic,
        'title': title,
        'description': description,
        'content_type': contentType.toDbString(),
        'status': status.toDbString(),
        'license': license,
        'is_ai_assisted': isAiAssisted,
        'citations': citations.map((c) => c.toJson()).toList(),
        if (lessonMarkdown != null) 'lesson_markdown': lessonMarkdown,
        'flashcards': flashcards.map((f) => f.toJson()).toList(),
        'guide_sections': guideSections.map((s) => s.toJson()).toList(),
        'feedback_count': feedbackCount,
        'average_rating': averageRating,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      };

  CommunityResource copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorHeadline,
    String? subjectId,
    String? topic,
    String? title,
    String? description,
    CommunityResourceContentType? contentType,
    CommunityResourceStatus? status,
    String? license,
    bool? isAiAssisted,
    List<ResourceCitation>? citations,
    String? lessonMarkdown,
    List<FlashcardCard>? flashcards,
    List<StudyGuideSection>? guideSections,
    int? feedbackCount,
    double? averageRating,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    String? rejectionReason,
  }) {
    return CommunityResource(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorHeadline: authorHeadline ?? this.authorHeadline,
      subjectId: subjectId ?? this.subjectId,
      topic: topic ?? this.topic,
      title: title ?? this.title,
      description: description ?? this.description,
      contentType: contentType ?? this.contentType,
      status: status ?? this.status,
      license: license ?? this.license,
      isAiAssisted: isAiAssisted ?? this.isAiAssisted,
      citations: citations ?? this.citations,
      lessonMarkdown: lessonMarkdown ?? this.lessonMarkdown,
      flashcards: flashcards ?? this.flashcards,
      guideSections: guideSections ?? this.guideSections,
      feedbackCount: feedbackCount ?? this.feedbackCount,
      averageRating: averageRating ?? this.averageRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

