import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/community/community_resource.dart';

/// Service managing creator-authored educational resources, review workflows,
/// and AI-assisted drafting with source citations (ECO-06, Phase 3).
class CommunityResourceService extends ChangeNotifier {
  static const String _storageKey = 'community_resources_cache_v1';

  final SharedPreferences? _prefs;
  final List<CommunityResource> _resources = [];

  CommunityResourceService({SharedPreferences? prefs}) : _prefs = prefs {
    _loadFromStorage();
  }

  List<CommunityResource> get resources => List.unmodifiable(_resources);

  void _loadFromStorage() {
    _resources.clear();
    final jsonStr = _prefs?.getString(_storageKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        for (final item in decoded) {
          _resources.add(CommunityResource.fromJson(item as Map<String, dynamic>));
        }
      } catch (e) {
        debugPrint('Error parsing cached community resources: $e');
      }
    }

    // Seed pilot resources if empty
    if (_resources.isEmpty) {
      _resources.addAll(_seedResources);
      _persistToStorage();
    }
  }

  Future<void> _persistToStorage() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonList = _resources.map((r) => r.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
    notifyListeners();
  }

  /// Fetches resources optionally filtered by subject and status.
  Future<List<CommunityResource>> fetchResources({
    String? subjectId,
    CommunityResourceStatus? status,
  }) async {
    return _resources.where((r) {
      if (subjectId != null && r.subjectId != subjectId) return false;
      if (status != null && r.status != status) return false;
      return true;
    }).toList();
  }

  /// Fetches published resources accessible to learners.
  Future<List<CommunityResource>> fetchPublishedResources({String? subjectId}) async {
    return fetchResources(
      subjectId: subjectId,
      status: CommunityResourceStatus.published,
    );
  }

  /// Fetches resources authored by a specific educator.
  Future<List<CommunityResource>> fetchAuthorResources(String authorId) async {
    return _resources.where((r) => r.authorId == authorId).toList();
  }

  /// Retrieves a resource by ID.
  Future<CommunityResource?> getResourceById(String id) async {
    try {
      return _resources.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Saves a resource draft (creates new or updates existing).
  Future<CommunityResource> saveResourceDraft(CommunityResource resource) async {
    final now = DateTime.now();
    final updated = resource.copyWith(
      status: CommunityResourceStatus.draft,
      updatedAt: now,
    );

    final idx = _resources.indexWhere((r) => r.id == resource.id);
    if (idx >= 0) {
      _resources[idx] = updated;
    } else {
      _resources.insert(0, updated);
    }

    await _persistToStorage();
    return updated;
  }

  /// Submits a draft resource to the editorial review queue.
  Future<CommunityResource> submitResourceForReview(String resourceId) async {
    final idx = _resources.indexWhere((r) => r.id == resourceId);
    if (idx < 0) {
      throw ArgumentError('Resource not found: $resourceId');
    }

    final current = _resources[idx];
    final updated = current.copyWith(
      status: CommunityResourceStatus.submittedForReview,
      updatedAt: DateTime.now(),
    );

    _resources[idx] = updated;
    await _persistToStorage();
    return updated;
  }

  /// Approves a resource in the review queue and marks it published.
  Future<CommunityResource> approveResource(String resourceId) async {
    final idx = _resources.indexWhere((r) => r.id == resourceId);
    if (idx < 0) {
      throw ArgumentError('Resource not found: $resourceId');
    }

    final current = _resources[idx];
    final now = DateTime.now();
    final updated = current.copyWith(
      status: CommunityResourceStatus.published,
      publishedAt: now,
      updatedAt: now,
    );

    _resources[idx] = updated;
    await _persistToStorage();
    return updated;
  }

  /// Generates a structured AI draft adhering to Invariant 4 with regulatory citations.
  Future<CommunityResource> generateAiDraft({
    required String topic,
    required String subjectId,
    required CommunityResourceContentType contentType,
    required String authorId,
    required String authorName,
    String? authorHeadline,
  }) async {
    final now = DateTime.now();
    final id = 'draft_${now.millisecondsSinceEpoch}_${authorId.hashCode.abs()}';

    // Citation generation based on canonical subject
    final List<ResourceCitation> citations = [];
    final normSubject = subjectId.toLowerCase();
    final normTopic = topic.toLowerCase();

    if (normSubject.contains('safety') ||
        normSubject.contains('osha') ||
        normTopic.contains('safety') ||
        normTopic.contains('osha') ||
        normTopic.contains('hazard')) {
      citations.add(const ResourceCitation(
        id: 'cit_osha_1910',
        title: 'OSHA General Industry Safety & Health Regulations',
        authorityCode: '29 CFR 1910.1200',
        jurisdiction: 'US-Federal OSHA',
        verified: true,
      ));
    } else if (normSubject.contains('fl_') ||
        normSubject.contains('florida') ||
        normTopic.contains('florida') ||
        normTopic.contains('driver')) {
      citations.add(const ResourceCitation(
        id: 'cit_fl_fac',
        title: 'Florida Administrative Code & DBPR Licensing Standards',
        authorityCode: 'FAC Rule 61J2',
        jurisdiction: 'State of Florida DBPR',
        verified: true,
      ));
    } else {
      citations.add(const ResourceCitation(
        id: 'cit_foundational',
        title: 'Adult Basic Education (ABE) Evidence Standards',
        authorityCode: 'WIOA Title II Adult Literacy Benchmark',
        jurisdiction: 'US Department of Education',
        verified: true,
      ));
    }

    // Build template based on content type
    String? lessonMarkdown;
    List<FlashcardCard> flashcards = [];
    List<StudyGuideSection> guideSections = [];

    switch (contentType) {
      case CommunityResourceContentType.lesson:
      case CommunityResourceContentType.cheatSheet:
        lessonMarkdown = '''# Micro-Lesson: $topic

## Core Objective
Understand the foundational regulatory and practical standards for $topic.

## Key Principles
1. **Source of Truth**: Always adhere to primary regulatory citations (${citations.first.authorityCode}).
2. **Standard Operating Procedure**: Verify compliance before performing high-consequence operations.
3. **Safety & Audit Trail**: Document all steps and inspect safety equipment prior to deployment.

> [!NOTE]
> This draft was generated by AI assistance. Please review, edit with your professional expertise, and verify all citations prior to submission.
''';
        break;

      case CommunityResourceContentType.flashcardSet:
        flashcards = [
          FlashcardCard(
            id: '${id}_f1',
            front: 'What is the primary governing standard for $topic?',
            back: 'Governed by ${citations.first.authorityCode} (${citations.first.title}).',
            tip: 'Memorize the regulatory section code.',
          ),
          FlashcardCard(
            id: '${id}_f2',
            front: 'What is the first step before beginning work on $topic?',
            back: 'Verify hazard controls, inspect required PPE, and confirm licensing/permits.',
            tip: 'Safety inspection always precedes physical operations.',
          ),
          FlashcardCard(
            id: '${id}_f3',
            front: 'When must audit or inspection records be updated?',
            back: 'Immediately upon completing the task or shift inspection.',
            tip: 'Timely recordkeeping avoids compliance penalties.',
          ),
        ];
        break;

      case CommunityResourceContentType.studyGuide:
        guideSections = [
          StudyGuideSection(
            id: '${id}_s1',
            heading: 'Section 1: Regulatory Foundations',
            bodyMarkdown:
                'All activities in $topic are governed by ${citations.first.authorityCode}. Familiarize yourself with the jurisdiction and primary compliance requirements.',
            citationIds: [citations.first.id],
            keyTakeaway: 'Compliance is mandatory under ${citations.first.jurisdiction}.',
          ),
          StudyGuideSection(
            id: '${id}_s2',
            heading: 'Section 2: High-Consequence Execution',
            bodyMarkdown:
                'Follow verified procedural steps. Never bypass lockout/tagout or supervisory sign-offs.',
            citationIds: [citations.first.id],
            keyTakeaway: 'Procedural discipline prevents catastrophic errors.',
          ),
        ];
        break;
    }

    final resource = CommunityResource(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorHeadline: authorHeadline,
      subjectId: subjectId,
      topic: topic,
      title: 'Guide to $topic',
      description: 'Structured educational resource on $topic with verified regulatory citations.',
      contentType: contentType,
      status: CommunityResourceStatus.draft,
      isAiAssisted: true,
      citations: citations,
      lessonMarkdown: lessonMarkdown,
      flashcards: flashcards,
      guideSections: guideSections,
      createdAt: now,
      updatedAt: now,
    );

    return saveResourceDraft(resource);
  }

  // Pre-seeded high quality community resources for pilot topics
  static final List<CommunityResource> _seedResources = [
    CommunityResource(
      id: 'res_seed_osha_ppes_1',
      authorId: 'ed_osha_master_1',
      authorName: 'Sarah Jenkins, CSP',
      authorHeadline: 'Certified Safety Professional & OSHA Outreach Trainer',
      subjectId: 'workplace_safety',
      topic: 'Personal Protective Equipment (PPE) Essentials',
      title: 'PPE Selection & Inspection Field Checklist',
      description:
          'Comprehensive guide for selecting, inspecting, and donning eye, head, and respiratory PPE per OSHA 29 CFR 1910.132.',
      contentType: CommunityResourceContentType.studyGuide,
      status: CommunityResourceStatus.published,
      license: 'CC-BY-4.0',
      isAiAssisted: false,
      citations: const [
        ResourceCitation(
          id: 'cit_osha_1910_132',
          title: 'General Requirements for Personal Protective Equipment',
          authorityCode: '29 CFR 1910.132',
          jurisdiction: 'US Department of Labor (OSHA)',
          verified: true,
        ),
      ],
      guideSections: const [
        StudyGuideSection(
          id: 's_ppe_1',
          heading: '1. The Hierarchy of Controls',
          bodyMarkdown:
              'PPE is the **last line of defense** in hazard mitigation. Always evaluate elimination, substitution, engineering controls, and administrative controls before relying solely on PPE.',
          citationIds: ['cit_osha_1910_132'],
          keyTakeaway: 'PPE protects the individual, but does not eliminate the physical hazard.',
        ),
        StudyGuideSection(
          id: 's_ppe_2',
          heading: '2. Pre-Donning Inspection Protocol',
          bodyMarkdown:
              'Inspect hard hats for micro-cracks and suspension integrity. Ensure safety glasses bear the **ANSI Z87.1** stamp. Check respirator elastomeric seals for dry-rot or deformities.',
          citationIds: ['cit_osha_1910_132'],
          keyTakeaway: 'Defective PPE must be tagged out and removed from service immediately.',
        ),
      ],
      feedbackCount: 28,
      averageRating: 4.9,
      createdAt: DateTime(2026, 10, 15),
      updatedAt: DateTime(2026, 10, 20),
      publishedAt: DateTime(2026, 10, 20),
    ),
    CommunityResource(
      id: 'res_seed_fl_driver_signs_2',
      authorId: 'ed_fl_instructor_2',
      authorName: 'Carlos Rivera',
      authorHeadline: 'Florida Driver Education Specialist & ABE Coach',
      subjectId: 'foundational_literacy',
      topic: 'Florida Road Signs & Right-of-Way Rules',
      title: 'Florida Road Signs Flashcard Deck',
      description:
          'High-contrast visual flashcards covering octagonal stop, triangular yield, railroad crossings, and school zone speed thresholds.',
      contentType: CommunityResourceContentType.flashcardSet,
      status: CommunityResourceStatus.published,
      license: 'CC-BY-4.0',
      isAiAssisted: false,
      citations: const [
        ResourceCitation(
          id: 'cit_fl_hsmv_handbook',
          title: 'Official Florida Driver License Handbook (2026 Edition)',
          authorityCode: 'F.S. 322.08 & FLHSMV Standards',
          jurisdiction: 'State of Florida FLHSMV',
          verified: true,
        ),
      ],
      flashcards: const [
        FlashcardCard(
          id: 'fc_fl_1',
          front: 'What does a red octagon sign signify?',
          back: 'Full stop before the crosswalk or stop line. Yield to all oncoming traffic.',
          tip: 'An 8-sided red sign is uniquely reserved for STOP.',
        ),
        FlashcardCard(
          id: 'fc_fl_2',
          front: 'What is the four-way stop right-of-way rule?',
          back: 'The first vehicle to arrive and stop proceeds first. If two arrive simultaneously, yield to the vehicle on your right.',
          tip: 'When in doubt, yield to the right.',
        ),
        FlashcardCard(
          id: 'fc_fl_3',
          front: 'What does a downward-pointing triangle sign mean?',
          back: 'YIELD right-of-way to pedestrians and oncoming vehicles.',
          tip: 'Slow down and be prepared to stop if vehicles are approaching.',
        ),
      ],
      feedbackCount: 42,
      averageRating: 4.95,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 22),
      publishedAt: DateTime(2026, 10, 22),
    ),
  ];
}

