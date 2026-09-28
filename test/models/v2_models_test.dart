import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/flashcard.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_target.dart';
import 'package:learning_pwa/models/module.dart';
import 'package:learning_pwa/models/scope.dart';
import 'package:learning_pwa/models/user_concept_state.dart';

void main() {
  group('LearningTarget & TargetVersion Models', () {
    test('round-trips LearningTarget to and from JSON', () {
      final target = LearningTarget(
        id: 'target-123',
        targetType: TargetType.licensureExam,
        fieldId: 'field-hvac',
        title: 'Florida Air Conditioning Contractor Class A',
        slug: 'florida-ac-class-a',
        description: 'Comprehensive licensure exam preparation',
        providerName: 'Florida DBPR',
        jurisdiction: 'Florida',
        emoji: '❄️',
        isPublic: true,
        isOfficial: true,
        status: TargetStatus.published,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final json = target.toJson();
      expect(json['id'], 'target-123');
      expect(json['target_type'], 'licensure_exam');
      expect(json['title'], 'Florida Air Conditioning Contractor Class A');
      expect(json['is_official'], isTrue);

      final fromJson = LearningTarget.fromJson(json);
      expect(fromJson.id, target.id);
      expect(fromJson.targetType, TargetType.licensureExam);
      expect(fromJson.title, target.title);
      expect(fromJson.emoji, '❄️');
      expect(fromJson.isOfficial, isTrue);
    });

    test('round-trips TargetVersion to and from JSON', () {
      final version = TargetVersion(
        id: 'ver-123',
        targetId: 'target-123',
        versionCode: '2026-v1',
        title: '2026 Candidate Information Booklet Spec',
        metadata: const {'passThreshold': 0.70},
        status: TargetVersionStatus.published,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final json = version.toJson();
      expect(json['version_code'], '2026-v1');
      expect(json['metadata']['passThreshold'], 0.70);

      final fromJson = TargetVersion.fromJson(json);
      expect(fromJson.id, version.id);
      expect(fromJson.versionCode, '2026-v1');
      expect(fromJson.metadata['passThreshold'], 0.70);
      expect(fromJson.status, TargetVersionStatus.published);
    });
  });

  group('CurriculumNode & Teaching Bindings', () {
    test('handles node hierarchy and serialization', () {
      final node = CurriculumNode(
        id: 'node-domain-1',
        targetVersionId: 'ver-123',
        parentId: null,
        nodeType: 'domain',
        title: 'Trade Knowledge & Refrigeration Systems',
        code: 'DOM-01',
        sortOrder: 1,
        importance: CurriculumImportance.core,
        weight: 0.40,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      expect(node.isRoot, isTrue);
      final json = node.toJson();
      expect(json['code'], 'DOM-01');
      expect(json['importance'], 'core');

      final fromJson = CurriculumNode.fromJson(json);
      expect(fromJson.isRoot, isTrue);
      expect(fromJson.code, 'DOM-01');
      expect(fromJson.weight, 0.40);
    });

    test('serializes curriculum bindings', () {
      final courseBinding = const CurriculumNodeCourse(
        curriculumNodeId: 'node-1',
        courseId: 'course-thermo',
        sortOrder: 1,
      );
      expect(courseBinding.toJson()['course_id'], 'course-thermo');

      final moduleBinding = const CurriculumNodeModule(
        curriculumNodeId: 'node-1',
        moduleId: 'mod-cycles',
        sortOrder: 2,
      );
      expect(moduleBinding.toJson()['module_id'], 'mod-cycles');

      final lessonBinding = const CurriculumNodeLesson(
        curriculumNodeId: 'node-1',
        lessonId: 'lesson-superheat',
        sortOrder: 3,
      );
      expect(lessonBinding.toJson()['lesson_id'], 'lesson-superheat');

      final conceptBinding = const CurriculumNodeConcept(
        curriculumNodeId: 'node-1',
        conceptId: 'concept-superheat',
        relevance: ConceptRelevance.core,
        weight: 0.85,
      );
      expect(conceptBinding.toJson()['relevance'], 'core');
    });
  });

  group('Module Model', () {
    test('serializes Module correctly', () {
      final module = Module(
        id: 'mod-1',
        courseId: 'course-1',
        title: 'Vapor Compression Cycle',
        description: 'Principles of refrigerant phase changes',
        emoji: '🔄',
        sortOrder: 2,
        isRequired: true,
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final json = module.toJson();
      expect(json['id'], 'mod-1');
      expect(json['course_id'], 'course-1');
      expect(json['title'], 'Vapor Compression Cycle');
      expect(json['sort_order'], 2);

      final fromJson = Module.fromJson(json);
      expect(fromJson.id, module.id);
      expect(fromJson.emoji, '🔄');
    });
  });

  group('KnowledgeConcept & ConceptRelation Models', () {
    test('serializes KnowledgeConcept and aliases', () {
      final concept = KnowledgeConcept(
        id: 'kc-superheat',
        name: 'Superheat',
        slug: 'superheat',
        description: 'Sensible heat added to vapor above boiling point',
        shortDefinition: 'Heat added to vapor above its saturation temperature',
        aliases: const ['Vapor Superheat', 'Evaporator Superheat'],
        emoji: '🌡️',
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      final json = concept.toJson();
      expect(json['name'], 'Superheat');
      expect(json['aliases'], contains('Vapor Superheat'));

      final fromJson = KnowledgeConcept.fromJson(json);
      expect(fromJson.name, 'Superheat');
      expect(fromJson.aliases.length, 2);
    });

    test('serializes ConceptRelation with prerequisite kind', () {
      final relation = const ConceptRelation(
        fromConceptId: 'kc-latent-heat',
        toConceptId: 'kc-superheat',
        relationType: ConceptRelationType.prerequisite,
        prerequisiteKind: PrerequisiteKind.required,
        autoInclude: true,
        strength: 0.95,
      );

      final json = relation.toJson();
      expect(json['relation_type'], 'prerequisite');
      expect(json['prerequisite_kind'], 'required');

      final fromJson = ConceptRelation.fromJson(json);
      expect(fromJson.relationType, ConceptRelationType.prerequisite);
      expect(fromJson.autoInclude, isTrue);
      expect(fromJson.strength, 0.95);
    });
  });

  group('Flashcard & Standalone Decks', () {
    test('detects standalone flashcard when lessonId is null', () {
      final standaloneCard = Flashcard(
        id: 'fc-1',
        lessonId: null,
        front: 'What is subcooling?',
        back: 'Lowering the temperature of liquid refrigerant below condensing temperature',
        createdAt: DateTime(2026, 9, 25),
        updatedAt: DateTime(2026, 9, 25),
      );

      expect(standaloneCard.isStandalone, isTrue);
      final json = standaloneCard.toJson();
      expect(json['lesson_id'], isNull);

      final fromJson = Flashcard.fromJson(json);
      expect(fromJson.isStandalone, isTrue);
    });
  });

  group('UserConceptState Projection', () {
    test('calculates accuracy accurately and parses bands', () {
      final state = UserConceptState(
        userId: 'u1',
        conceptId: 'kc-1',
        retrievalBand: RetrievalBand.developing,
        confidence: ConceptConfidence.medium,
        evidenceCount: 5,
        weightedCorrect: 3.5,
        weightedTotal: 5.0,
        updatedAt: DateTime(2026, 9, 25),
      );

      expect(state.accuracy, 0.70);
      expect(state.retrievalBand.displayName, 'Developing');

      final json = state.toJson();
      expect(json['retrieval_band'], 'developing');
      expect(json['confidence'], 'medium');

      final fromJson = UserConceptState.fromJson(json);
      expect(fromJson.accuracy, 0.70);
      expect(fromJson.retrievalBand, RetrievalBand.developing);
    });
  });

  group('Scope & Deterministic Sequence Models', () {
    test('serializes ScopedLearningActivity and ResolvedScope', () {
      final activity = const ScopedLearningActivity(
        activityId: 'lesson-compressors',
        kind: ScopedActivityKind.lesson,
        curriculumNodeId: 'node-1',
        curriculumOrder: 1,
        activityOrder: 2,
        role: ScopeRole.core,
        title: 'Reciprocating Compressors',
        estimatedDuration: Duration(minutes: 15),
      );

      final scope = ResolvedScope(
        contextId: 'ctx-1',
        coreConceptIds: const {'c1', 'c2'},
        supportingConceptIds: const {'c3'},
        relatedConceptIds: const {'c4'},
        curriculumNodeIds: const {'node-1'},
        orderedActivities: [activity],
        questionIds: const {'q1', 'q2'},
        termIds: const {'t1'},
        flashcardIds: const {'f1'},
        resolvedAt: DateTime(2026, 9, 25),
      );

      expect(scope.activeConceptIds, {'c1', 'c2', 'c3'});
      expect(scope.containsConcept('c1'), isTrue);
      expect(scope.containsConcept('c3'), isTrue);
      expect(scope.containsConcept('c4'), isFalse);
      expect(scope.containsActivity('lesson-compressors'), isTrue);

      final json = scope.toJson();
      final fromJson = ResolvedScope.fromJson(json);
      expect(fromJson.contextId, 'ctx-1');
      expect(fromJson.activeConceptIds, {'c1', 'c2', 'c3'});
      expect(fromJson.orderedActivities.first.title, 'Reciprocating Compressors');
    });

    test('serializes ContextCurriculumSnapshot', () {
      final snapshot = ContextCurriculumSnapshot(
        contextId: 'ctx-1',
        targetVersionId: 'ver-1',
        nodes: const [
          SnapshotNode(
            id: 'n1',
            title: 'Refrigeration Cycle',
            code: 'REF-01',
            nodeType: 'domain',
          ),
        ],
        activeFocusId: 'n1',
        snapshotAt: DateTime(2026, 9, 25),
      );

      final json = snapshot.toJson();
      final fromJson = ContextCurriculumSnapshot.fromJson(json);
      expect(fromJson.targetVersionId, 'ver-1');
      expect(fromJson.nodes.first.title, 'Refrigeration Cycle');
      expect(fromJson.activeFocusId, 'n1');
    });
  });
}
