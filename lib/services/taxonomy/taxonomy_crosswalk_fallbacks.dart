import '../../models/taxonomy/taxonomy.dart';

/// Built-in taxonomy samples used by [TaxonomyCrosswalkService] when no
/// Supabase client is available (tests, offline grace).
///
/// Moved unchanged from `taxonomy_crosswalk_service.dart`
/// (code-efficiency plan §14, Phase 3). Never official data: the live
/// service always prefers the database.
abstract final class TaxonomyCrosswalkFallbacks {
  // --------------------------------------------------------------------------
  // In-Memory Fallbacks for Testing & Offline Grace
  // --------------------------------------------------------------------------

  static List<CatalogCluster> catalogClusters() {
    return const [
      CatalogCluster(id: 'c1', slug: 'computing-tech', title: 'Computing & Information Technology', emoji: '💻', accentColor: '#2563EB', sortOrder: 1),
      CatalogCluster(id: 'c2', slug: 'health-medicine', title: 'Health Professions & Medicine', emoji: '🏥', accentColor: '#DC2626', sortOrder: 2),
      CatalogCluster(id: 'c3', slug: 'engineering-tech', title: 'Engineering & Applied Technology', emoji: '⚙️', accentColor: '#D97706', sortOrder: 3),
      CatalogCluster(id: 'c4', slug: 'business-finance', title: 'Business, Finance & Management', emoji: '📈', accentColor: '#059669', sortOrder: 4),
      CatalogCluster(id: 'c5', slug: 'physical-bio-sciences', title: 'Physical & Biological Sciences', emoji: '🔬', accentColor: '#7C3AED', sortOrder: 5),
      CatalogCluster(id: 'c6', slug: 'math-stats-data', title: 'Mathematics, Statistics & Data', emoji: '📐', accentColor: '#0891B2', sortOrder: 6),
      CatalogCluster(id: 'c7', slug: 'law-policy-security', title: 'Law, Public Policy & Security', emoji: '⚖️', accentColor: '#4B5563', sortOrder: 7),
      CatalogCluster(id: 'c8', slug: 'arts-design', title: 'Visual Arts, Performing Arts & Design', emoji: '🎨', accentColor: '#DB2777', sortOrder: 8),
      CatalogCluster(id: 'c9', slug: 'social-sciences-education', title: 'Social Sciences, Psychology & Education', emoji: '🌍', accentColor: '#4F46E5', sortOrder: 9),
      CatalogCluster(id: 'c10', slug: 'humanities-languages', title: 'Humanities, Languages & Literature', emoji: '📚', accentColor: '#B45309', sortOrder: 10),
      CatalogCluster(id: 'c11', slug: 'skilled-trades', title: 'Skilled Construction & Mechanical Trades', emoji: '🔨', accentColor: '#EA580C', sortOrder: 11),
      CatalogCluster(id: 'c12', slug: 'agriculture-environment', title: 'Agriculture, Natural Resources & Environment', emoji: '🌾', accentColor: '#16A34A', sortOrder: 12),
      CatalogCluster(id: 'c13', slug: 'cluster_life_milestones', title: 'Life Milestones & Survival Literacy', description: 'Oral-first preparation for US Citizenship, Driver\'s License, GED® ABE, and life safety.', emoji: '🏛️', accentColor: '#4338CA', sortOrder: 13),
    ];
  }

  static List<CanonicalField> fields({String? clusterSlug}) {
    const fields = [
      CanonicalField(id: 'f-cs', name: 'Computer and Information Sciences and Support Services', slug: 'computer-sciences', fieldKind: 'broad_field', sortOrder: 11),
      CanonicalField(id: 'f-math', name: 'Mathematics and Statistics', slug: 'mathematics-statistics-series', fieldKind: 'broad_field', sortOrder: 27),
      CanonicalField(id: 'f-eng', name: 'Engineering', slug: 'engineering-disciplines', fieldKind: 'broad_field', sortOrder: 14),
      CanonicalField(id: 'f-health', name: 'Health Professions and Related Programs', slug: 'health-professions-series', fieldKind: 'broad_field', sortOrder: 51),
      CanonicalField(id: 'native-foundational-literacy', name: 'Foundational Literacy', slug: 'foundational-literacy', description: 'Beginning reading, oral language, and adult basic-education reading practice.', fieldKind: 'native_field', sortOrder: 1),
      CanonicalField(id: 'native-civic-community-literacy', name: 'Civic and Community Literacy', slug: 'civic-and-community-literacy', description: 'Civic knowledge and practical community navigation.', fieldKind: 'native_field', sortOrder: 2),
      CanonicalField(id: 'native-practical-life-skills', name: 'Practical Life Skills', slug: 'practical-life-skills', description: 'Practical life-skills practice represented in LearningApp.', fieldKind: 'native_field', sortOrder: 3),
    ];

    if (clusterSlug == 'cluster_life_milestones') {
      return fields.where((field) => field.fieldKind == 'native_field').toList();
    }
    return fields;
  }

  /// Offline sample of the CIP 2020-backed hierarchy under CIP 11.
  static List<CanonicalField> childFields() {
    return const [
      CanonicalField(id: 'f-cs-11-01', parentId: 'f-cs', name: 'Computer and Information Sciences, General', slug: 'computer-and-information-sciences-general-cip-11-01', fieldKind: 'subfield', sortOrder: 1),
      CanonicalField(id: 'f-cs-11-07', parentId: 'f-cs', name: 'Computer Science', slug: 'computer-science-cip-11-07', fieldKind: 'subfield', sortOrder: 7),
      CanonicalField(id: 'f-cs-11-0101', parentId: 'f-cs-11-01', name: 'Computer and Information Sciences, General', slug: 'computer-and-information-sciences-general-cip-11-0101', fieldKind: 'program_classification', sortOrder: 101),
      CanonicalField(id: 'f-cs-11-0701', parentId: 'f-cs-11-07', name: 'Computer Science', slug: 'computer-science-cip-11-0701', fieldKind: 'program_classification', sortOrder: 701),
      CanonicalField(id: 'native-phonics', parentId: 'native-foundational-literacy', name: 'Phonics and Word Decoding', slug: 'phonics-and-word-decoding', fieldKind: 'native_field', sortOrder: 1),
      CanonicalField(id: 'native-supported-reading', parentId: 'native-foundational-literacy', name: 'Supported Reading and Comprehension', slug: 'supported-reading-and-comprehension', fieldKind: 'native_field', sortOrder: 2),
      CanonicalField(id: 'native-oral-language', parentId: 'native-foundational-literacy', name: 'Oral Language and Listening', slug: 'oral-language-and-listening', fieldKind: 'native_field', sortOrder: 3),
      CanonicalField(id: 'native-adult-reading', parentId: 'native-foundational-literacy', name: 'Adult Basic-Education Reading', slug: 'adult-basic-education-reading', fieldKind: 'native_field', sortOrder: 4),
      CanonicalField(id: 'native-civics', parentId: 'native-civic-community-literacy', name: 'Civics and Naturalization Preparation', slug: 'civics-and-naturalization-preparation', fieldKind: 'native_field', sortOrder: 1),
      CanonicalField(id: 'native-driver-safety', parentId: 'native-civic-community-literacy', name: 'Driver Safety and License Preparation', slug: 'driver-safety-and-license-preparation', fieldKind: 'native_field', sortOrder: 2),
      CanonicalField(id: 'native-cash-atm', parentId: 'native-practical-life-skills', name: 'Cash and ATM Practice', slug: 'cash-and-atm-practice', fieldKind: 'native_field', sortOrder: 1),
      CanonicalField(id: 'native-health-first-aid', parentId: 'native-practical-life-skills', name: 'Health Literacy and First Aid', slug: 'health-literacy-and-first-aid', fieldKind: 'native_field', sortOrder: 2),
      CanonicalField(id: 'native-food-safety', parentId: 'native-practical-life-skills', name: 'Food Safety', slug: 'food-safety', fieldKind: 'native_field', sortOrder: 3),
      CanonicalField(id: 'native-workplace-safety', parentId: 'native-practical-life-skills', name: 'Workplace Safety', slug: 'workplace-safety', fieldKind: 'native_field', sortOrder: 4),
    ];
  }

  static List<OccupationNode> occupationNodes() {
    return const [
      OccupationNode(
        id: 'occ-15-0000',
        code: '15-0000',
        title: 'Computer and Mathematical Occupations',
        level: 'major_group',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
      ),
      OccupationNode(
        id: 'occ-15-1252',
        parentId: 'occ-15-0000',
        code: '15-1252',
        title: 'Software Developers',
        level: 'detailed_occupation',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
        jobZone: 4,
      ),
      OccupationNode(
        id: 'occ-15-1252-00',
        parentId: 'occ-15-1252',
        code: '15-1252.00',
        title: 'Software Developers (O*NET)',
        level: 'onet_extension',
        taxonomySystem: 'onet_soc',
        taxonomyVersion: '2019',
        dataReleaseVersion: 'onet_31_0',
        jobZone: 4,
      ),
      OccupationNode(
        id: 'occ-15-1211',
        parentId: 'occ-15-0000',
        code: '15-1211',
        title: 'Information Security Analysts',
        level: 'detailed_occupation',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
        jobZone: 4,
      ),
    ];
  }

  static List<TargetCrosswalkOccupation> targetOccupations(String targetId) {
    return const [
      TargetCrosswalkOccupation(
        occupationId: 'occ-15-1252',
        occupationCode: '15-1252',
        occupationTitle: 'Software Developers',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer and Information Sciences',
        fieldRole: 'primary',
        classificationCode: '11.0701',
        classificationTitle: 'Computer Science',
      ),
      TargetCrosswalkOccupation(
        occupationId: 'occ-15-1211',
        occupationCode: '15-1211',
        occupationTitle: 'Information Security Analysts',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer and Information Sciences',
        fieldRole: 'primary',
        classificationCode: '11.1003',
        classificationTitle: 'Computer and Information Systems Security/Auditing/Information Assurance',
      ),
    ];
  }

  static List<ExternalClassificationNode> externalClassificationNodes({
    String system = 'cip',
    String version = '2020',
    String? parentId,
  }) {
    final all = <ExternalClassificationNode>[
      const ExternalClassificationNode(
        id: 'cip-11',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '11',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Computer and Information Sciences and Support Services',
        definition:
            'Instructional programs that focus on the computer and information sciences and preparing individuals for various occupations in technology.',
      ),
      const ExternalClassificationNode(
        id: 'cip-11-07',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11',
        system: 'cip',
        version: '2020',
        code: '11.07',
        sourceParentCode: '11',
        levelCode: 'group',
        levelDepth: 2,
        title: 'Computer Science',
        definition:
            'Instructional programs that focus on computer science and related scientific disciplines.',
      ),
      const ExternalClassificationNode(
        id: 'cip-11-0701',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11-07',
        system: 'cip',
        version: '2020',
        code: '11.0701',
        sourceParentCode: '11.07',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Computer Science',
        definition:
            'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
        illustrativeExamples: [
          'Computer Science',
          'Theoretical Computer Science',
          'Computational Theory'
        ],
      ),
      const ExternalClassificationNode(
        id: 'cip-11-1003',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-11',
        system: 'cip',
        version: '2020',
        code: '11.1003',
        sourceParentCode: '11',
        levelCode: 'program',
        levelDepth: 3,
        title:
            'Computer and Information Systems Security/Auditing/Information Assurance',
        definition:
            'A program that prepares individuals to assess the security needs of computer and network systems and manage secure infrastructure.',
        illustrativeExamples: [
          'Cybersecurity',
          'Information Assurance',
          'Network Security'
        ],
      ),
      const ExternalClassificationNode(
        id: 'cip-14',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '14',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Engineering',
        definition:
            'Instructional programs that focus on the mathematical and scientific principles applied to the design, construction, and operation of systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-14-0901',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-14',
        system: 'cip',
        version: '2020',
        code: '14.0901',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Computer Engineering, General',
        definition:
            'A program that prepares individuals to apply mathematical and scientific principles to the design and development of computer hardware and integrated hardware-software systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-27',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '27',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Mathematics and Statistics',
        definition:
            'Instructional programs that focus on the systematic study of logical and mathematical quantities, structures, and systems.',
      ),
      const ExternalClassificationNode(
        id: 'cip-27-0101',
        sourceReleaseId: 'rel-cip-2020',
        parentId: 'cip-27',
        system: 'cip',
        version: '2020',
        code: '27.0101',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Mathematics, General',
        definition:
            'A general program that focuses on the core principles of mathematics, calculus, and abstract algebra.',
      ),
      const ExternalClassificationNode(
        id: 'cip-51',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '51',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Health Professions and Related Programs',
        definition:
            'Instructional programs that prepare individuals for careers in medicine, nursing, health informatics, and allied health.',
      ),
      const ExternalClassificationNode(
        id: 'cip-52',
        sourceReleaseId: 'rel-cip-2020',
        system: 'cip',
        version: '2020',
        code: '52',
        levelCode: 'series',
        levelDepth: 1,
        title: 'Business, Management, Marketing, and Related Support Services',
        definition:
            'Instructional programs that focus on business management, accounting, financial planning, and operational leadership.',
      ),
    ];

    if (parentId != null) {
      return all.where((n) => n.parentId == parentId).toList();
    }
    return all;
  }

  static List<CipProgramCrosswalk> cipCrosswalks(String occupationCode) {
    if (occupationCode.startsWith('15-1252')) {
      return const [
        CipProgramCrosswalk(
          code: '11.0701',
          title: 'Computer Science',
          definition:
              'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
          mappingKind: 'official_qualitative',
        ),
        CipProgramCrosswalk(
          code: '11.1003',
          title: 'Computer and Information Systems Security',
          definition:
              'A program that prepares individuals to assess security needs of computer and network systems.',
          mappingKind: 'official_qualitative',
        ),
      ];
    }
    if (occupationCode.startsWith('15-1211')) {
      return const [
        CipProgramCrosswalk(
          code: '11.1003',
          title: 'Computer and Information Systems Security',
          definition:
              'A program that prepares individuals to assess security needs of computer and network systems.',
          mappingKind: 'official_qualitative',
        ),
      ];
    }
    return const [
      CipProgramCrosswalk(
        code: '11.0701',
        title: 'Computer Science',
        definition:
            'A program that focuses on computer theory, computing problems and solutions, algorithms, and software design.',
        mappingKind: 'official_qualitative',
      ),
    ];
  }

  static List<TargetCrosswalkOccupation> occupationsForCip(String cipCode) {
    if (cipCode.startsWith('11.1003')) {
      return const [
        TargetCrosswalkOccupation(
          occupationId: 'occ-15-1211',
          occupationCode: '15-1211',
          occupationTitle: 'Information Security Analysts',
          occupationLevel: 'detailed_occupation',
          jobZone: 4,
          fieldId: 'f-cs',
          fieldName: 'Computer and Information Sciences',
          fieldRole: 'primary',
          classificationCode: '11.1003',
          classificationTitle: 'Computer and Information Systems Security',
        ),
      ];
    }
    return const [
      TargetCrosswalkOccupation(
        occupationId: 'occ-15-1252',
        occupationCode: '15-1252',
        occupationTitle: 'Software Developers',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer and Information Sciences',
        fieldRole: 'primary',
        classificationCode: '11.0701',
        classificationTitle: 'Computer Science',
      ),
    ];
  }

  static List<OccupationTargetLink> targetsForOccupation(
      String occupationCode) {
    if (occupationCode.startsWith('15-1211')) {
      return const [
        OccupationTargetLink(
          targetId: 'target-sec-plus',
          targetTitle: 'CompTIA Security+ (SY0-701)',
          targetSlug: 'security-plus-sy0-701',
          targetType: 'certification',
          fieldRole: 'primary',
          emoji: '🛡️',
        ),
      ];
    }
    return const [
      OccupationTargetLink(
        targetId: 'target-bs-cs',
        targetTitle: 'B.S. in Computer Science',
        targetSlug: 'bs-computer-science',
        targetType: 'academic_program',
        fieldRole: 'primary',
        emoji: '🎓',
      ),
      OccupationTargetLink(
        targetId: 'target-swe-career',
        targetTitle: 'Software Engineer Career Path',
        targetSlug: 'software-engineer-career',
        targetType: 'career',
        fieldRole: 'primary',
        emoji: '💻',
      ),
    ];
  }
}
