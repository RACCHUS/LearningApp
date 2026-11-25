import copy
import sys
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import verify_research as v  # noqa: E402

OPP = v.RESEARCH / "opportunities" / "open-college-algebra-ch1.yaml"
SRC = v.RESEARCH / "sources" / "libretexts.yaml"
REG = v.load_registry()


def opp(**changes):
    data = yaml.safe_load(OPP.read_text(encoding="utf-8"))
    data.update(changes)
    return data


def observation(**changes):
    o = {"evidence_class": "education", "metric": "completions", "value": 1200, "state": "observed",
         "unit": "count", "geography": "US", "population": "all", "period": "2024",
         "source_locator": "https://nces.ed.gov/ipeds/", "publisher": "NCES", "checked_on": "2026-11-20",
         "directness": "indirect", "cohort": "algebra-courses"}
    o.update(changes)
    return o


def problems(data):
    return v.check_opportunity(OPP, data)


class ScoringTests(unittest.TestCase):
    def test_only_known_weights_count_and_bounds_are_shown(self):
        f = {k: {"score": None} for k in v.WEIGHTS}
        f["demand"] = {"score": 5}
        f["outcome_value"] = {"score": 0}
        pr = v.priority(f)
        self.assertEqual(pr["known_weight"], 45)
        self.assertEqual(pr["provisional_score"], round(100 * 25 / 45, 1))
        self.assertEqual((pr["lower_bound"], pr["upper_bound"]), (25.0, 80.0))
        self.assertFalse(pr["usable"])

    def test_seventy_percent_known_is_usable(self):
        f = {k: {"score": 3} for k in ("demand", "underserved_need", "outcome_value")}
        f["source_feasibility"] = {"score": 5}
        self.assertEqual(v.priority(f)["known_weight"], 75)
        self.assertTrue(v.priority(f)["usable"])

    def test_nothing_known_has_no_score(self):
        self.assertIsNone(v.priority({})["provisional_score"])
        self.assertEqual(v.priority({})["upper_bound"], 100.0)


class OpportunityTests(unittest.TestCase):
    def test_the_real_files_pass(self):
        self.assertEqual(v.main([]), 0)

    def test_unknown_is_null_and_a_score_needs_evidence(self):
        d = opp()
        d["factors"]["underserved_need"] = {"score": 4, "evidence": [], "rated_by": None}
        out = problems(d)
        self.assertTrue(any("no evidence" in p for p in out))
        self.assertTrue(any("no rated_by" in p for p in out))
        d["factors"]["underserved_need"] = {"score": 7, "evidence": ["x"], "rated_by": "y"}
        self.assertTrue(any("integer 0-5 or null" in p for p in problems(d)))

    def test_observed_values_need_a_source_and_other_states_are_null(self):
        self.assertTrue(any("source_locator" in p for p in problems(opp(observations=[observation(source_locator="")]))))
        self.assertTrue(any("must be null" in p for p in problems(opp(observations=[observation(state="suppressed", value=0)]))))
        self.assertEqual(problems(opp(observations=[observation(state="suppressed", value=None)])), [])

    def test_measured_comparable_needs_two_classes_and_a_cohort_pair(self):
        one = [observation()]
        self.assertTrue(any("measured_comparable" in p for p in problems(opp(demand_status="measured_comparable", observations=one))))
        two = [observation(), observation(evidence_class="labor", metric="openings")]
        self.assertEqual(problems(opp(demand_status="measured_comparable", observations=two)), [])

    def test_demand_score_and_high_demand_lane_need_measured_demand(self):
        d = opp()
        d["factors"]["demand"] = {"score": 4, "evidence": ["x"], "rated_by": "y"}
        self.assertTrue(any("needs measured demand" in p for p in problems(d)))
        self.assertTrue(any("high_demand lane" in p for p in problems(opp(lane="high_demand"))))

    def test_gates_come_before_scoring(self):
        self.assertTrue(any("hard gate" in p for p in problems(opp(recommendation="acquire"))))
        gates = {g: True for g in v.GATES}
        self.assertEqual(problems(opp(recommendation="acquire", gates=gates)), [])

    def test_defer_needs_a_reason_and_a_trigger(self):
        out = problems(opp(recommendation="defer"))
        self.assertTrue(any("defer_reason" in p for p in out))
        self.assertTrue(any("revisit_trigger" in p for p in out))

    def test_no_personal_fields(self):
        d = opp(observations=[observation(user_id="abc")])
        self.assertTrue(any("personal field" in p for p in problems(d)))


class SourceTests(unittest.TestCase):
    def src(self, **changes):
        data = yaml.safe_load(SRC.read_text(encoding="utf-8"))
        data.update(changes)
        return v.check_source(SRC, data, REG)

    def test_unverified_rights_allow_only_safe_actions(self):
        self.assertEqual(self.src(), [])
        self.assertTrue(any("only discover, link and reference" in p for p in self.src(permitted_actions=["adapt"])))

    def test_verified_rights_need_evidence_and_the_registry(self):
        out = self.src(rights_review_state="verified", permitted_actions=["adapt"])
        self.assertTrue(any("license_evidence_locator" in p for p in out))
        self.assertTrue(any("need a registry_source_id" in p for p in out))
        self.assertTrue(any("not in data/content_sources.json" in p
                            for p in self.src(registry_source_id="no-such-source")))

    def test_actions_cannot_exceed_the_registry(self):
        out = self.src(rights_review_state="verified", license_evidence_locator="https://ocw.mit.edu/",
                       registry_source_id="mit-ocw", permitted_actions=["discover", "adapt"])
        self.assertTrue(any("beyond the registry" in p for p in out))


if __name__ == "__main__":
    unittest.main()
