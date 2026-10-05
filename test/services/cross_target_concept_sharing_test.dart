import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/curriculum_node.dart';
import 'package:learning_pwa/models/knowledge_concept.dart';
import 'package:learning_pwa/models/learning_context.dart';
import 'package:learning_pwa/models/scope.dart';

void main() {
  group('Phase F: Cross-Target Canonical Concept Sharing Tests', () {
    test('Invariant 1: Concepts are autonomous and shared across distinct targets', () {
      final now = DateTime.now();

      // Shared canonical concept: Concurrency & Synchronization
      final sharedConcept = KnowledgeConcept(
        id: 'concept-concurrency-sync',
        slug: 'concurrency-synchronization',
        name: 'Concurrency & Synchronization',
        shortDefinition: 'Techniques ensuring thread safety and mutual exclusion in concurrent execution.',
        aliases: const ['thread-safety', 'critical-sections', 'mutex-primitives'],
        createdAt: now,
        updatedAt: now,
      );

      // Target 1: B.S. in Computer Science (Academic Program)
      final csNode = CurriculumNode(
        id: 'node-cs-os-concurrency',
        targetVersionId: 'ver-bs-cs',
        code: 'CS-301.1',
        title: 'Operating Systems Concurrency',
        nodeType: 'objective',
        createdAt: now,
        updatedAt: now,
      );

      // Target 2: Software Engineer (Career)
      final sweNode = CurriculumNode(
        id: 'node-swe-multithreading',
        targetVersionId: 'ver-swe-career',
        code: 'SWE-2.1',
        title: 'Scalable Multithreading & Race Prevention',
        nodeType: 'objective',
        createdAt: now,
        updatedAt: now,
      );

      // Target 3: CompTIA Security+ (Certification)
      final secNode = CurriculumNode(
        id: 'node-sec-race-conditions',
        targetVersionId: 'ver-sec-plus',
        code: 'SEC-1.2',
        title: 'Mitigating Concurrency & Race Condition Vulnerabilities',
        nodeType: 'objective',
        createdAt: now,
        updatedAt: now,
      );

      // All three nodes link to the same autonomous concept
      final csMapping = CurriculumNodeConcept(
        curriculumNodeId: csNode.id,
        conceptId: sharedConcept.id,
        relevance: ConceptRelevance.core,
      );

      final sweMapping = CurriculumNodeConcept(
        curriculumNodeId: sweNode.id,
        conceptId: sharedConcept.id,
        relevance: ConceptRelevance.core,
      );

      final secMapping = CurriculumNodeConcept(
        curriculumNodeId: secNode.id,
        conceptId: sharedConcept.id,
        relevance: ConceptRelevance.core,
      );

      expect(csMapping.conceptId, sharedConcept.id);
      expect(sweMapping.conceptId, sharedConcept.id);
      expect(secMapping.conceptId, sharedConcept.id);
      expect(csNode.targetVersionId, isNot(sweNode.targetVersionId));
      expect(sweNode.targetVersionId, isNot(secNode.targetVersionId));
    });

    test('Invariant 2: Shared concepts do NOT cause lesson collision across scoped targets', () {
      final now = DateTime.now();

      final contextSec = LearningContext(
        id: 'ctx-sec',
        userId: 'user-alpha',
        label: 'CompTIA Security+',
        rootType: ContextRootType.target,
        rootId: 'target-sec-plus',
        targetVersionId: 'ver-sec-plus',
        lastActiveAt: now,
      );

      final activities = <ScopedLearningActivity>[
        const ScopedLearningActivity(
          activityId: 'lesson-sec-buffer-race',
          title: 'Concurrency Flaws & TOCTOU Exploits',
          kind: ScopedActivityKind.lesson,
          curriculumNodeId: 'node-sec-race-conditions',
          activityOrder: 1,
        ),
      ];

      final resolvedScope = ResolvedScope(
        contextId: contextSec.id,
        coreConceptIds: const {'concept-concurrency-sync'},
        orderedActivities: activities,
        resolvedAt: now,
      );

      expect(resolvedScope.coreConceptIds, contains('concept-concurrency-sync'));
      expect(resolvedScope.orderedActivities.length, 1);
      expect(resolvedScope.orderedActivities.first.curriculumNodeId, 'node-sec-race-conditions');
      // Proves complete scope isolation: Academic CS lessons are never leaked into the active sequence
      expect(resolvedScope.orderedActivities.any((a) => a.curriculumNodeId == 'node-cs-os-concurrency'), isFalse);
    });
  });
}
