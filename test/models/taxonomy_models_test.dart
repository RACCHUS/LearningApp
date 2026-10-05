import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/taxonomy/taxonomy.dart';

void main() {
  group('Phase F: Taxonomy Models Unit Tests', () {
    test('ExternalClassificationNode serialization and properties', () {
      final node = ExternalClassificationNode(
        id: 'ext-11.0701',
        sourceReleaseId: 'rel-1',
        parentId: 'ext-11.07',
        system: 'cip',
        version: '2020',
        code: '11.0701',
        sourceParentCode: '11.07',
        levelCode: 'program',
        levelDepth: 3,
        title: 'Computer Science',
        definition: 'A program that focuses on computer theory and algorithms.',
        crossReferences: ['11.0101'],
        illustrativeExamples: ['Algorithm Designer', 'Theoretical CS'],
      );

      final json = node.toJson();
      expect(json['id'], 'ext-11.0701');
      expect(json['code'], '11.0701');
      expect(json['level_depth'], 3);

      final deserialized = ExternalClassificationNode.fromJson(json);
      expect(deserialized.title, 'Computer Science');
      expect(deserialized.parentId, 'ext-11.07');
      expect(deserialized.crossReferences, contains('11.0101'));
      expect(deserialized.illustrativeExamples, contains('Algorithm Designer'));
    });

    test('TaxonomyNodeLineage serialization and transition types', () {
      final lineage = TaxonomyNodeLineage(
        id: 'lin-1',
        sourceSystem: 'cip',
        fromVersion: '2010',
        fromCode: '11.0801',
        toVersion: '2020',
        toCode: '11.0801',
        transitionType: 'renamed',
        notes: 'Renamed in 2020 edition.',
      );

      final json = lineage.toJson();
      expect(json['transition_type'], 'renamed');

      final deserialized = TaxonomyNodeLineage.fromJson(json);
      expect(deserialized.fromCode, '11.0801');
      expect(deserialized.toCode, '11.0801');
      expect(deserialized.transitionType, 'renamed');
    });

    test('FieldRelation symmetry and properties', () {
      final symmetric = FieldRelation(
        fromFieldId: 'f-1',
        toFieldId: 'f-2',
        relationType: 'shares_foundations',
        notes: 'Math and CS foundations',
      );
      expect(symmetric.isSymmetric, isTrue);

      final directional = FieldRelation(
        fromFieldId: 'f-3',
        toFieldId: 'f-1',
        relationType: 'applied_domain_of',
      );
      expect(directional.isSymmetric, isFalse);

      final json = symmetric.toJson();
      final deserialized = FieldRelation.fromJson(json);
      expect(deserialized.relationType, 'shares_foundations');
    });

    test('OccupationNode 5-tier level getters and O*NET properties', () {
      final major = OccupationNode(
        id: 'occ-1',
        code: '15-0000',
        title: 'Computer and Mathematical Occupations',
        level: 'major_group',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
      );
      expect(major.isMajorGroup, isTrue);
      expect(major.isOnetExtension, isFalse);

      final detailed = OccupationNode(
        id: 'occ-2',
        parentId: 'occ-1',
        code: '15-1252',
        title: 'Software Developers',
        level: 'detailed_occupation',
        taxonomySystem: 'bls_soc',
        taxonomyVersion: 'soc_2018',
        jobZone: 4,
      );
      expect(detailed.isDetailedOccupation, isTrue);
      expect(detailed.jobZone, 4);

      final onet = OccupationNode(
        id: 'occ-3',
        parentId: 'occ-2',
        code: '15-1252.00',
        title: 'Software Developers (O*NET)',
        level: 'onet_extension',
        taxonomySystem: 'onet_soc',
        taxonomyVersion: '2019',
        dataReleaseVersion: 'onet_31_0',
        jobZone: 4,
      );
      expect(onet.isOnetExtension, isTrue);
      expect(onet.dataReleaseVersion, 'onet_31_0');

      final deserialized = OccupationNode.fromJson(onet.toJson());
      expect(deserialized.isOnetExtension, isTrue);
      expect(deserialized.taxonomySystem, 'onet_soc');
    });

    test('FieldOccupationMetric fail-closed privacy safeguards', () {
      // 1. Unverified learner metric with sample_size < 50
      final unsafeLearnerMetric = FieldOccupationMetric(
        id: 'm-1',
        fieldId: 'f-cs',
        occupationId: 'occ-15-1252',
        metricType: 'app_user_transition_share',
        metricValue: 0.65,
        dataYear: 2026,
        sampleSize: 30, // < 50
        isPublished: true,
        privacyThresholdMet: false,
      );
      expect(unsafeLearnerMetric.isUserDisplayable, isFalse,
          reason: 'Fails closed when sample size is below 50');

      // 2. Verified learner metric with sample_size >= 50 and privacyThresholdMet = true
      final safeLearnerMetric = FieldOccupationMetric(
        id: 'm-2',
        fieldId: 'f-cs',
        occupationId: 'occ-15-1252',
        metricType: 'app_user_transition_share',
        metricValue: 0.65,
        dataYear: 2026,
        sampleSize: 120, // >= 50
        isPublished: true,
        privacyThresholdMet: true,
      );
      expect(safeLearnerMetric.isUserDisplayable, isTrue);

      // 3. Official government metric published
      final officialMetric = FieldOccupationMetric(
        id: 'm-3',
        fieldId: 'f-cs',
        occupationId: 'occ-15-1252',
        metricType: 'observed_worker_field_share',
        metricValue: 0.48,
        dataYear: 2024,
        isPublished: true,
      );
      expect(officialMetric.isUserDisplayable, isTrue);

      // 4. Unpublished metric never displays
      final unpublished = FieldOccupationMetric(
        id: 'm-4',
        fieldId: 'f-cs',
        occupationId: 'occ-15-1252',
        metricType: 'observed_worker_field_share',
        metricValue: 0.48,
        dataYear: 2024,
        isPublished: false,
      );
      expect(unpublished.isUserDisplayable, isFalse);
    });

    test('TargetCrosswalkOccupation serialization and job zone labels', () {
      final crosswalk = TargetCrosswalkOccupation(
        occupationId: 'occ-15-1252',
        occupationCode: '15-1252',
        occupationTitle: 'Software Developers',
        occupationLevel: 'detailed_occupation',
        jobZone: 4,
        fieldId: 'f-cs',
        fieldName: 'Computer Science',
        fieldRole: 'primary',
        classificationCode: '11.0701',
        classificationTitle: 'Computer Science',
      );

      expect(crosswalk.isPrimaryField, isTrue);
      expect(crosswalk.jobZoneLabel, contains('Job Zone 4: Considerable Preparation'));

      final json = crosswalk.toJson();
      final deserialized = TargetCrosswalkOccupation.fromJson(json);
      expect(deserialized.occupationCode, '15-1252');
      expect(deserialized.classificationCode, '11.0701');
    });

    test('LearningTargetField and ConceptField membership models', () {
      final targetField = LearningTargetField(
        targetId: 't-1',
        fieldId: 'f-1',
        role: 'primary',
        displayOrder: 1,
      );
      expect(targetField.isPrimary, isTrue);
      expect(targetField.isSupporting, isFalse);

      final conceptField = ConceptField(
        conceptId: 'c-1',
        fieldId: 'f-1',
        relationship: 'core_concept',
      );
      expect(conceptField.isCore, isTrue);
      expect(conceptField.isPrerequisite, isFalse);
    });
  });
}
