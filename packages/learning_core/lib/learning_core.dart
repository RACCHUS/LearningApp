/// Core domain models, FSRS-6 scheduler, Haladyna psychometric item evaluators,
/// and curriculum manifest validators for LearningApp (Platform & Ecosystem Core).
library learning_core;

export 'src/models/provenance_snapshot.dart';
export 'src/models/learning_task_profile.dart';
export 'src/models/content_complexity_profile.dart';
export 'src/models/item_psychometric_status.dart';
export 'src/models/assessment_item.dart';
export 'src/models/learning_event.dart';
export 'src/models/brand_config_core.dart';
export 'src/models/video_interactive_module.dart';
export 'src/models/procedural_rubric.dart';
export 'src/models/content_proposal.dart';
export 'src/models/entitlement_core.dart';
export 'src/models/tutoring_session.dart';

export 'src/algorithms/fsrs_scheduler_core.dart';
export 'src/algorithms/item_evaluator_core.dart';
export 'src/algorithms/learning_gain_calculator.dart';
export 'src/algorithms/procedural_evaluator_core.dart';
export 'src/algorithms/evidence_scorer_core.dart';
export 'src/algorithms/proposal_generator_core.dart';
export 'src/algorithms/coach_recommendation_engine.dart';
export 'src/algorithms/irt_calibrator_core.dart';
export 'src/validation/manifest_validator_core.dart';

export 'src/video/video_embed_resolver.dart';

export 'src/interop/qti_item_converter.dart';
export 'src/interop/xapi_statement_emitter.dart';
export 'src/interop/open_badge_converter.dart';
export 'src/interop/lti_launcher.dart';
export 'src/interop/case_standards_converter.dart';
export 'src/interop/cmi5_converter.dart';

