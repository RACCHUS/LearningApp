import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_pwa/core/logging/app_logger.dart';
import 'package:learning_pwa/models/community/community_question.dart';
import 'package:learning_pwa/models/community/community_answer.dart';

/// Service managing concept-scoped Community Q&A workflows (ECO-01 & ECO-02).
///
/// Enforces Phase 1 private engineering boundaries:
/// - Fetches curated seed FAQs for in-context learning screens.
/// - Manages private/draft question submissions for learners.
/// - Provides moderator review workflows for queued questions and answers.
/// - Enforces single accepted answer mechanics.
/// - Atomic upvoting via the database RPC.
class CommunityQaService {
  final _logger = AppLogger('CommunityQaService');

  final SupabaseClient? _injectedClient;
  SupabaseClient get _supabase => _injectedClient ?? Supabase.instance.client;

  CommunityQaService({SupabaseClient? supabase})
      : _injectedClient = supabase;

  /// Fetches curated, published seed FAQs, optionally filtered by topic scope.
  Future<List<CommunityQuestion>> fetchSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) async {
    try {
      var query = _supabase
          .from('community_questions')
          .select()
          .eq('status', 'published')
          .eq('is_seeded', true);

      if (conceptId != null && conceptId.isNotEmpty) {
        query = query.eq('concept_id', conceptId);
      } else if (targetId != null && targetId.isNotEmpty) {
        query = query.eq('target_id', targetId);
      } else if (lessonId != null && lessonId.isNotEmpty) {
        query = query.eq('lesson_id', lessonId);
      }

      final response = await query.order('upvote_count', ascending: false);
      final List<dynamic> rows = response as List<dynamic>;
      final result = rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();

      if (result.isEmpty) {
        return _getOfflineSeedFaqs(conceptId: conceptId, targetId: targetId, lessonId: lessonId);
      }
      return result;
    } catch (e, st) {
      _logger.warn('Failed to fetch seed FAQs, falling back to offline defaults: $e', error: e, stackTrace: st);
      return _getOfflineSeedFaqs(conceptId: conceptId, targetId: targetId, lessonId: lessonId);
    }
  }

  /// Fetches all published questions associated with a concept.
  Future<List<CommunityQuestion>> fetchConceptQuestions(String conceptId) async {
    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('concept_id', conceptId)
          .eq('status', 'published')
          .order('upvote_count', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch concept questions: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches questions awaiting educator or moderator review.
  ///
  /// Accessible only to users possessing moderator or admin privileges.
  Future<List<CommunityQuestion>> fetchUnderReviewQuestions({int limit = 50}) async {
    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('status', 'under_review')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch under-review questions: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches the authenticated user's private draft or under-review questions.
  Future<List<CommunityQuestion>> fetchMyDrafts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('community_questions')
          .select()
          .eq('author_id', user.id)
          .inFilter('status', ['draft', 'under_review'])
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      return rows
          .map((row) => CommunityQuestion.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      _logger.warn('Failed to fetch user drafts: $e', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetches answers for a specific community question.
  Future<List<CommunityAnswer>> fetchAnswersForQuestion(String questionId) async {
    try {
      final response = await _supabase
          .from('community_answers')
          .select()
          .eq('question_id', questionId)
          .eq('status', 'published')
          .order('is_accepted', ascending: false)
          .order('upvote_count', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      final result = rows
          .map((row) => CommunityAnswer.fromJson(row as Map<String, dynamic>))
          .toList();

      if (result.isEmpty && questionId.startsWith('seed-faq-')) {
        return _getOfflineAnswersForQuestion(questionId);
      }
      return result;
    } catch (e, st) {
      _logger.warn('Failed to fetch answers for question $questionId: $e', error: e, stackTrace: st);
      return _getOfflineAnswersForQuestion(questionId);
    }
  }

  /// Creates a private draft question (or marks it under review).
  ///
  /// Non-admin users cannot publish directly to the public feed during Phase 1.
  Future<CommunityQuestion?> createDraftQuestion({
    required String title,
    required String bodyMarkdown,
    String? conceptId,
    String? targetId,
    String? lessonId,
    String? cipCode,
    bool submitForReview = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _logger.warn('Cannot create question: user is not authenticated');
      return null;
    }

    final status = submitForReview ? 'under_review' : 'draft';

    try {
      final data = {
        'author_id': user.id,
        'title': title.trim(),
        'body_markdown': bodyMarkdown.trim(),
        'status': status,
        if (conceptId != null) 'concept_id': conceptId,
        if (targetId != null) 'target_id': targetId,
        if (lessonId != null) 'lesson_id': lessonId,
        if (cipCode != null) 'cip_code': cipCode,
      };

      final response = await _supabase
          .from('community_questions')
          .insert(data)
          .select()
          .single();

      return CommunityQuestion.fromJson(response);
    } catch (e, st) {
      _logger.error('Failed to create draft question: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Reviews a community question via the atomic database RPC.
  ///
  /// Permitted actions: 'publish', 'reject', 'archive'.
  /// Requires caller to possess moderator or admin privileges.
  Future<Map<String, dynamic>> reviewQuestion({
    required String questionId,
    required String action,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'review_community_question',
        params: {
          'p_question_id': questionId,
          'p_action': action,
          if (notes != null) 'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to review community question $questionId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Reviews a community answer via the atomic database RPC.
  ///
  /// Permitted actions: 'publish', 'reject', 'archive', 'flag'.
  /// Requires caller to possess moderator or admin privileges.
  Future<Map<String, dynamic>> reviewAnswer({
    required String answerId,
    required String action,
    String? notes,
  }) async {
    try {
      final response = await _supabase.rpc(
        'review_community_answer',
        params: {
          'p_answer_id': answerId,
          'p_action': action,
          if (notes != null) 'p_notes': notes,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to review community answer $answerId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Accepts an answer for a question via the atomic database RPC.
  ///
  /// Restricted to the question author or a moderator.
  /// Automatically unaccepts any previously accepted answer on that question.
  Future<Map<String, dynamic>> acceptAnswer({
    required String answerId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'accept_community_answer',
        params: {
          'p_answer_id': answerId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to accept community answer $answerId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Toggles an upvote on a question or answer via the atomic database RPC.
  Future<Map<String, dynamic>> toggleVote({
    required String targetType,
    required String targetId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'cast_community_vote',
        params: {
          'p_target_type': targetType,
          'p_target_id': targetId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e, st) {
      _logger.error('Failed to cast community vote on $targetType $targetId: $e', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Offline fallback demonstration FAQs to ensure guidance remains accessible offline
  /// without presenting fabricated engagement metrics or unverified claims.
  List<CommunityQuestion> _getOfflineSeedFaqs({
    String? conceptId,
    String? targetId,
    String? lessonId,
  }) {
    final now = DateTime.now();
    final allSeeds = [
      // Literacy Domain
      CommunityQuestion(
        id: 'seed-faq-001',
        authorId: 'offline-demo',
        title: 'What is the CVC pattern in phonics and how is it taught?',
        bodyMarkdown: 'What does the CVC acronym stand for, and why is it considered the foundational pattern in early phonics instruction?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.cvc.basics',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-002',
        authorId: 'offline-demo',
        title: 'How do sight words differ from decodable words?',
        bodyMarkdown: 'Why are high-frequency words often called sight words, and should learners sound them out or memorize them?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.sight_words',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-003',
        authorId: 'offline-demo',
        title: 'What is the difference between continuous blending and segmented blending?',
        bodyMarkdown: 'When teaching a struggling reader to blend letter sounds into words, what is continuous blending and why is it recommended?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.phonics.blending',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-004',
        authorId: 'offline-demo',
        title: 'What is a consonant digraph versus a consonant blend?',
        bodyMarkdown: 'What distinguishes consonant digraphs like "sh" and "th" from consonant blends like "bl" and "st"?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.digraphs',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-005',
        authorId: 'offline-demo',
        title: 'How does onset-rime awareness support phonological development?',
        bodyMarkdown: 'Why is dividing words into onset and rime beneficial for pre-readers and developing spellers?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.rhyming',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-006',
        authorId: 'offline-demo',
        title: 'How does the split vowel digraph or silent-e rule function?',
        bodyMarkdown: 'What is the phonetic mechanic behind the final silent-e in words like "cake", "ride", and "rope"?',
        status: 'published',
        isSeeded: true,
        conceptId: 'literacy.silent_e',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),

      // Workplace Safety Domain
      CommunityQuestion(
        id: 'seed-faq-007',
        authorId: 'offline-demo',
        title: 'What are the standard OSHA requirements for Personal Protective Equipment (PPE)?',
        bodyMarkdown: 'Under OSHA general industry guidelines, when must an employer provide PPE and what gear is mandated?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.ppe',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-008',
        authorId: 'offline-demo',
        title: 'What information must be included in a Safety Data Sheet (SDS) under GHS?',
        bodyMarkdown: 'How is an OSHA Hazard Communication Safety Data Sheet structured, and which sections are critical for immediate chemical spills?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.hazcom',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-009',
        authorId: 'offline-demo',
        title: 'What does the PASS acronym stand for when operating a fire extinguisher?',
        bodyMarkdown: 'What is the proper procedural technique for safely deploying a portable workplace fire extinguisher?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.fire',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-010',
        authorId: 'offline-demo',
        title: 'What is Lockout/Tagout (LOTO) and why is it mandatory during machinery maintenance?',
        bodyMarkdown: 'Under OSHA standard 29 CFR 1910.147, what is the primary purpose of hazardous energy control procedures?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.lockout_tagout',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-011',
        authorId: 'offline-demo',
        title: 'What are the primary OSHA walking-working surface requirements for housekeeping?',
        bodyMarkdown: 'How should walkways, aisles, and floors be maintained in commercial and industrial workspaces to prevent fall injuries?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.slips_trips_falls',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-012',
        authorId: 'offline-demo',
        title: 'What core components are required in an OSHA Emergency Action Plan (EAP)?',
        bodyMarkdown: 'When an employer is required to have an Emergency Action Plan under 29 CFR 1910.38, what procedures must be documented?',
        status: 'published',
        isSeeded: true,
        conceptId: 'workplace.safety.emergency_action',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),

      // Florida Licensure Domain
      CommunityQuestion(
        id: 'seed-faq-013',
        authorId: 'offline-demo',
        title: 'What are the continuing education (CE) requirements for Florida Cosmetology license renewal?',
        bodyMarkdown: 'How many continuing education hours are required by the Florida Board of Cosmetology for biennial license renewal?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.cosmetology.ce',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-014',
        authorId: 'offline-demo',
        title: 'What are the work and in-service training requirements to renew a Florida CNA certificate?',
        bodyMarkdown: 'How does a Certified Nursing Assistant maintain an active license with the Florida Board of Nursing?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.cna.renewal',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-015',
        authorId: 'offline-demo',
        title: 'What is the first-renewal post-licensing requirement for Florida Real Estate Sales Associates?',
        bodyMarkdown: 'What coursework must a newly licensed Florida real estate sales associate complete before their initial license expiration date?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.real_estate.post_licensing',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-016',
        authorId: 'offline-demo',
        title: 'How does license reciprocity work for Florida Certified Electrical Contractors?',
        bodyMarkdown: 'Does the Florida Electrical Contractors\' Licensing Board (ECLB) grant reciprocal recognition to electrical licenses from other states?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.electrical.reciprocity',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-017',
        authorId: 'offline-demo',
        title: 'What training hours are required for the Florida Class D Security Officer License?',
        bodyMarkdown: 'Under Florida Chapter 493, what curriculum and hours must an applicant complete to earn a Class D Security Officer License?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.security_guard.class_d',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CommunityQuestion(
        id: 'seed-faq-018',
        authorId: 'offline-demo',
        title: 'What experience qualifications are required for the Florida Certified General Contractor (CGC) exam?',
        bodyMarkdown: 'What combination of education and four years of commercial construction experience is required by the Florida CILB?',
        status: 'published',
        isSeeded: true,
        conceptId: 'licensure.construction.general_contractor',
        viewCount: 0,
        upvoteCount: 0,
        answerCount: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    if (conceptId != null && conceptId.isNotEmpty) {
      final filtered = allSeeds.where((q) => q.conceptId == conceptId).toList();
      return filtered.isNotEmpty ? filtered : allSeeds;
    }
    return allSeeds;
  }

  /// Provides offline answers corresponding to offline demo FAQs.
  List<CommunityAnswer> _getOfflineAnswersForQuestion(String questionId) {
    final now = DateTime.now();
    final answersMap = <String, String>{
      'seed-faq-001': 'CVC stands for Consonant-Vowel-Consonant (e.g., "cat", "pin", "sun", "bed", "fog"). In CVC words, the single vowel in the middle always makes its short vowel sound. Blending these three distinct phonemes (onset, vowel nucleus, and coda) is the core initial milestone in phonemic decoding before learners progress to consonant blends, vowel teams, or silent-e patterns.',
      'seed-faq-002': 'Decodable words follow transparent phonetic rules that learners can sound out letter by letter using taught grapheme-phoneme correspondences. High-frequency "sight words" (such as "the", "was", "said", "of") often contain irregular or advanced spelling patterns. Modern evidence-based reading instruction recommends "orthographic mapping"—pointing out the regular sound parts while explicitly highlighting the irregular "heart" sounds, enabling instantaneous word retrieval without pure rote memorization.',
      'seed-faq-003': 'Segmented blending pauses between each individual sound (e.g., /s/ ... /a/ ... /t/), which places heavy demands on working memory. Continuous blending (also called additive or connected phonation) stretches continuous sounds smoothly into one another without pausing (e.g., "ssssaaaat"). Research indicates continuous blending significantly reduces memory drop-off and error rates for early and struggling readers.',
      'seed-faq-004': 'A consonant digraph consists of two letters that team together to represent a single, unique phoneme (e.g., "sh" in "ship", "th" in "thin", "ch" in "chin", "ck" in "duck"). In contrast, a consonant blend consists of two or three consonants where each letter retains its own distinct individual sound that can still be heard when spoken together (e.g., /b/ and /l/ in "black", /s/ and /t/ in "stop").',
      'seed-faq-005': 'In phonological awareness, the "onset" is the initial consonant sound before the vowel (e.g., /c/ in "cat"), and the "rime" is the vowel and any subsequent consonants (e.g., "-at"). Recognizing common rimes (word families like "-at", "-in", "-op") accelerates reading fluency because learners can rapidly map and read dozens of new words by simply swapping the onset consonant.',
      'seed-faq-006': 'The final "e" in CVCe words (Consonant-Vowel-Consonant-e) is historically a marker indicating that the preceding vowel sound is "long" (it pronounces its alphabet name). Linguistically, this is a split vowel digraph (e.g., a_e, i_e, o_e, u_e). Teaching this rule helps readers transition from short vowel decoding ("cap" to "cape", "pin" to "pine").',
      'seed-faq-007': 'Under OSHA 29 CFR 1910 Subpart I, employers must assess the workplace to identify hazards that necessitate PPE. When engineering or administrative controls are insufficient, employers must provide appropriate PPE at no cost to workers. Standard general industry PPE includes ANSI Z87.1 approved eye protection, hard hats conforming to ANSI Z89.1, puncture- and impact-resistant safety footwear (ASTM F2413), and hearing protection in zones exceeding 85 dBA TWA.',
      'seed-faq-008': 'OSHA\'s Hazard Communication Standard (29 CFR 1910.1200) aligns with the Globally Harmonized System (GHS) and mandates a standardized 16-section Safety Data Sheet (SDS). For immediate emergencies, Section 1 (Identification), Section 2 (Hazard Identification with pictograms and signal words), Section 4 (First-Aid Measures), Section 5 (Fire-Fighting Measures), and Section 6 (Accidental Release Measures) provide the essential rapid-response instructions.',
      'seed-faq-009': 'The PASS technique describes the 4-step sequence for operating a portable fire extinguisher: 1) Pull the pin to break the tamper seal. 2) Aim low, pointing the nozzle or hose at the base of the fire, not the flames. 3) Squeeze the handle or lever slowly to discharge the extinguishing agent. 4) Sweep the nozzle from side to side across the base of the fuel until the flames are fully extinguished.',
      'seed-faq-010': 'Lockout/Tagout (LOTO) establishes minimum performance requirements to prevent unexpected energization, startup, or release of stored energy during servicing or maintenance of machines and equipment. A designated lockout device physically holds the energy-isolating mechanism in a safe position, while a standardized tagout warning tag indicates the equipment must not be energized until the authorized technician removes the lock.',
      'seed-faq-011': 'Under OSHA 29 CFR 1910.22, all places of employment, passageways, storerooms, and service rooms must be kept clean, orderly, and in a sanitary condition. Floors must be kept dry and clear of debris, electrical cords, and protrusions. Where wet processes are used, employers must provide adequate drainage, non-slip mats, or false floors to maintain traction.',
      'seed-faq-012': 'An OSHA Emergency Action Plan must document: 1) Procedures for reporting fires and other emergencies; 2) Emergency evacuation procedures, including designated exit route assignments; 3) Procedures for employees who remain to operate critical operations before evacuation; 4) Procedures to account for all employees after evacuation; 5) Rescue and medical duties for assigned workers; and 6) Preferred names or job titles of individuals to contact for further information.',
      'seed-faq-013': 'Under Florida Administrative Code Rule 61G5-20, licensed cosmetologists must complete 10 hours of board-approved continuing education prior to their biennial license expiration (October 31st of even-numbered years). The 10 hours must include: 1 hour of HIV/AIDS education, 3 hours of sanitation and sterilization, 1 hour of OSHA/chemical hazards, 1 hour of workers\' compensation, 2 hours of Florida cosmetology laws and rules, and 2 hours of general cosmetology topics.',
      'seed-faq-014': 'Under Florida Statutes Chapter 464 and Rule 64B9-15, a Certified Nursing Assistant (CNA) license renews biennially. To qualify for active renewal, the CNA must perform nursing-related services for monetary compensation within the 24-month renewal cycle and complete a minimum of 24 hours of in-service training (12 hours per calendar year) covering mandatory topics such as medical error prevention, infection control, CPR, patient rights, and HIPAA compliance.',
      'seed-faq-015': 'Florida Real Estate Commission (FREC) Rule 61J2-3 requires all newly licensed sales associates to satisfactorily complete a commission-approved 45-hour post-licensing education course prior to their first biennial license expiration date. There is no grace period in Florida: failure to complete the 45-hour post-licensing course before the expiration date renders the license null and void by operation of law.',
      'seed-faq-016': 'The Florida Electrical Contractors\' Licensing Board (ECLB) offers licensure by endorsement to applicants who hold a valid, current electrical contractor license from jurisdictions with substantially similar examination and experience standards. Florida currently maintains formal endorsement agreements with select states (including Georgia, North Carolina, and California). Endorsement applicants must still satisfy Florida financial responsibility requirements, criminal background checks, and submit proof of active workers\' compensation coverage.',
      'seed-faq-017': 'Under Florida Statutes Chapter 493, applicants for the Class "D" Security Officer License must successfully complete a 40-hour training curriculum at a licensed security officer school. The training covers Florida law, security officer conduct, observation techniques, report writing, emergency procedures, terrorism awareness, and first aid. Once completed, the license is issued by the Florida Department of Agriculture and Consumer Services (FDACS) and is valid for two years.',
      'seed-faq-018': 'The Florida Construction Industry Licensing Board (CILB) requires applicants for the Certified General Contractor (CGC) license to demonstrate four years of proven commercial construction experience. Acceptable combinations include: 1) A 4-year accredited degree in construction or engineering plus 1 year of hands-on supervisory experience; 2) 3 years of accredited college credits plus 1 year of experience; or 3) 4 years of active field experience, with at least 1 year acting as a foreman or supervisor on commercial structures exceeding four stories.',
    };

    final answerText = answersMap[questionId];
    if (answerText == null) return [];

    return [
      CommunityAnswer(
        id: '$questionId-ans-01',
        questionId: questionId,
        authorId: 'offline-demo',
        bodyMarkdown: answerText,
        isAiGenerated: false,
        isAccepted: true,
        status: 'published',
        upvoteCount: 0,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
