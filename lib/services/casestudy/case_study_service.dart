import 'package:flutter/foundation.dart';
import '../../models/casestudy/case_study_scenario.dart';

/// Service managing scenario-based professional case studies with decision branching (P8-5).
class CaseStudyService extends ChangeNotifier {
  final List<CaseStudyScenario> _scenarios = _seedCaseStudies;

  List<CaseStudyScenario> getAllScenarios() => List.unmodifiable(_scenarios);

  CaseStudyScenario? getScenarioById(String id) {
    try {
      return _scenarios.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<CaseStudyScenario> getScenariosByDomain(String domain) {
    return _scenarios
        .where((s) => s.domain.toLowerCase() == domain.toLowerCase())
        .toList();
  }

  static const List<CaseStudyScenario> _seedCaseStudies = [
    CaseStudyScenario(
      id: 'case_osha_scaffold_1',
      title: 'The Scaffolding Near-Miss: An OSHA Incident Investigation',
      domain: 'OSHA Workplace Safety',
      difficulty: 'Intermediate',
      overview:
          'At 07:45 AM on a commercial build site in Orlando, FL, a third-party subcontractor was observed working on a 24-foot mobile tubular welded frame scaffold without guardrails. As the safety coordinator, you must take command of the incident.',
      steps: [
        CaseStudyStep(
          id: 'step_1_hazard_id',
          stepNumber: 1,
          narrative:
              'You arrive on the north courtyard and observe two workers stocking cinder blocks on the third scaffold tier (approximately 20 feet above the slab). The scaffold lacks midrails and toeboards, and neither worker is tied off to an independent lifeline.',
          exhibits: [
            CaseStudyExhibit(
              id: 'ex_photo_1',
              title: 'Field Observation Log #402',
              type: 'log',
              contentMarkdown:
                  '**Time:** 07:48 EST\n**Weather:** 14 mph gusts, overcast\n**Condition:** Scaffolding planking has ~12 inch deflection under pallet weight.',
            ),
            CaseStudyExhibit(
              id: 'ex_reg_1',
              title: 'OSHA Scaffolding Standard',
              type: 'citation',
              contentMarkdown:
                  '**29 CFR 1926.451(g)(1):** Each employee on a scaffold more than 10 feet above a lower level shall be protected from falling to that lower level.',
            ),
          ],
          choices: [
            CaseStudyDecisionChoice(
              id: 'c1_stop_work',
              text: 'Issue an immediate Stop-Work Order, instruct the workers to descend immediately, and establish a barricade around the scaffold perimeter.',
              isOptimal: true,
              feedback:
                  'Correct! When an imminent fall hazard exists (>10 ft with no personal fall arrest or guardrails per 29 CFR 1926.451), Stop-Work authority must be exercised immediately before any dialogue or paperwork.',
              regulatoryCitation: '29 CFR 1926.451(g)(1)',
            ),
            CaseStudyDecisionChoice(
              id: 'c1_warn_foreman',
              text: 'Walk to the subcontractor trailer to discuss the deficiency with their foreman while the workers continue stocking materials.',
              isOptimal: false,
              feedback:
                  'Critical Safety Error: Leaving workers exposed to an active 20-foot fall hazard while seeking supervision violates supervisory duty of care and risks catastrophic injury.',
            ),
            CaseStudyDecisionChoice(
              id: 'c1_photo_only',
              text: 'Take photographs for your weekly OSHA compliance report, tag the subcontractor for a non-urgent punchlist fine, and review tomorrow.',
              isOptimal: false,
              feedback:
                  'Dangerous Failure to Act: Administrative fines do not protect human lives against imminent physical hazards.',
            ),
          ],
        ),
        CaseStudyStep(
          id: 'step_2_remediation',
          stepNumber: 2,
          narrative:
              'The workers have safely descended to ground level. The subcontractor foreman arrives on scene visibly frustrated, claiming that erecting guardrails will delay the masonry schedule by four hours.',
          exhibits: [
            CaseStudyExhibit(
              id: 'ex_doc_2',
              title: 'Subcontractor Site Safety Agreement',
              type: 'document',
              contentMarkdown:
                  'Section 4.2: Subcontractor agrees that safety compliance takes precedence over project delivery schedules.',
            ),
          ],
          choices: [
            CaseStudyDecisionChoice(
              id: 'c2_lockout_remediate',
              text: 'Red-tag the scaffold with a "DANGER: DO NOT USE" tag, require installation of complete guardrail systems or an approved personal fall arrest system, and verify a competent person scaffold inspection before releasing the tag.',
              isOptimal: true,
              feedback:
                  'Optimal Protocol: Tagging out the defective scaffold and requiring a certified competent person inspection per 29 CFR 1926.451(f)(7) ensures complete legal and physical compliance.',
              regulatoryCitation: '29 CFR 1926.451(f)(7)',
            ),
            CaseStudyDecisionChoice(
              id: 'c2_compromise',
              text: 'Allow them to finish stocking for 30 minutes provided they promise to install guardrails immediately after lunch.',
              isOptimal: false,
              feedback:
                  'Illegal Compromise: OSHA standards permit zero discretionary waivers for unmitigated fall hazards exceeding 10 feet.',
            ),
          ],
        ),
      ],
    ),
  ];
}

