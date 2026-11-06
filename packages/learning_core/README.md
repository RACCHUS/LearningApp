# `learning_core`

A platform-independent, zero-Flutter-dependency Dart library containing the foundational domain algorithms, models, and validators of **LearningApp**:

- **FSRS-6 Scheduling Wrapper (`FsrsSchedulerCore`)**: Evidence-based spaced repetition memory state calculation ($S, D, R$).
- **Haladyna (2002) Item Writing Evaluator (`ItemEvaluatorCore`)**: Automated psychometric critique checking answer leakage, distractor length balance ($<1.5\times$), negative stems, absolute modifiers, and source citation presence.
- **Decomposed Provenance (`ProvenanceSnapshot`)**: 6-property provenance model (`origin`, `visibility`, `rights_status`, `review_status`, `source_authority`, `version_validity`).
- **Learning Event Ledger (`LearningEvent`)**: Immutable event modeling with canonical SHA-256 payload hashing and microsecond timestamp normalization.
- **Curriculum Manifest Validation (`ManifestValidatorCore`)**: Static structural validation for YAML curriculum manifests.

