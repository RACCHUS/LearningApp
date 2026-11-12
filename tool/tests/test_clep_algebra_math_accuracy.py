"""Mathematical accuracy of the *shipped* CLEP College Algebra manifest.

Reads the committed ``content/clep_college_algebra.yaml`` (the file that is
ingested), indexes items by their stable authored IDs, and checks each one
against an independent, ID-keyed oracle in ``clep_algebra_oracles.py``
(plan PR-2c, closes finding Q-03):

1. Every one of the 60 simulation items and 40 formative questions has an
   oracle, and every oracle has an item (no silent gaps either way).
2. For every item, exactly one option is mathematically correct according to
   the oracle's own computation from the prompt, and it is the keyed option;
   every distractor is proven wrong.
3. Each prompt matches the fingerprint its oracle was derived from, so a
   reworded prompt fails until the oracle is re-derived.
4. Targeted mutations of the real items (key, option text, option order,
   prompt, ID, and the two content defects fixed in PR-2c) are detected.
5. Psychometric structure (Haladyna rules, key-position balance) and the
   item #23 / #8 explanation regressions still hold.

Generator-to-YAML parity is enforced separately by
tool/ci/check_algebra_manifest_parity.py, so the authoring modules and the
committed YAML cannot drift apart.
"""
from __future__ import annotations

import copy
import re
import sys
from pathlib import Path

import pytest
import sympy as sp
import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import clep_algebra_oracles as oracles  # noqa: E402
from clep_algebra_oracles import ORACLES, PROMPT_SHA256, is_correct, verify_item  # noqa: E402

MANIFEST = Path(__file__).resolve().parents[2] / "content" / "clep_college_algebra.yaml"


def _load():
    with MANIFEST.open(encoding="utf-8") as fh:
        manifest = yaml.safe_load(fh)
    simulation, formative = {}, {}
    for domain in manifest["domains"]:
        for objective in domain["objectives"]:
            for lesson in objective["lessons"]:
                for item in lesson.get("assessment_items", []):
                    simulation[item["id"]] = item
                for question in lesson.get("questions", []):
                    formative[question["id"]] = question
    return simulation, formative


SIMULATION, FORMATIVE = _load()


def _shape(item_id: str, item: dict) -> tuple[str, list[str], int]:
    """(prompt, options, key) for either item shape."""
    if item_id in SIMULATION or "prompt" in item:
        return item["prompt"], list(item["response_spec"]["options"]), item["scoring_spec"]["correct_index"]
    return item["question_text"], list(item["options"]), item["correct_answer"]


def _verify(item_id: str, item: dict) -> list[str]:
    return verify_item(item_id, *_shape(item_id, item))


ALL_ITEMS = {**SIMULATION, **FORMATIVE}


# --------------------------------------------------------------------------
# Coverage: every shipped item has an oracle and vice versa
# --------------------------------------------------------------------------


def test_shipped_counts_and_oracle_coverage_are_exact():
    assert len(SIMULATION) == 60
    assert len(FORMATIVE) == 40
    assert set(ALL_ITEMS) == set(ORACLES), {
        "items_without_oracle": sorted(set(ALL_ITEMS) - set(ORACLES)),
        "oracles_without_item": sorted(set(ORACLES) - set(ALL_ITEMS)),
    }
    assert set(PROMPT_SHA256) == set(ORACLES)


def test_definitional_oracles_are_few_and_documented():
    """Reviewed (non-computed) truths must carry a rationale and stay rare."""
    reviewed = {i: o for i, o in ORACLES.items() if o.reviewed}
    assert all(len(o.reviewed) > 40 for o in reviewed.values())
    assert len(reviewed) <= 8, sorted(reviewed)


# --------------------------------------------------------------------------
# Every shipped item against its independent oracle
# --------------------------------------------------------------------------


@pytest.mark.parametrize("item_id", sorted(ALL_ITEMS))
def test_shipped_item_matches_independent_oracle(item_id):
    assert _verify(item_id, ALL_ITEMS[item_id]) == []


# --------------------------------------------------------------------------
# Mutations of the real items must be detected
# --------------------------------------------------------------------------


@pytest.mark.parametrize("item_id", sorted(ALL_ITEMS))
def test_every_wrong_key_is_detected(item_id):
    prompt, options, key = _shape(item_id, ALL_ITEMS[item_id])
    for wrong in range(len(options)):
        if wrong != key:
            assert verify_item(item_id, prompt, options, wrong), f"key {wrong} accepted"


def test_out_of_range_and_boolean_keys_are_rejected():
    item_id = "alg-sim-rational-equation-extraneous-root"
    prompt, options, _ = _shape(item_id, ALL_ITEMS[item_id])
    for key in (-1, 4, True, None, "2"):
        assert verify_item(item_id, prompt, options, key)


def test_edited_selected_option_is_detected():
    item_id = "alg-sim-linear-equation-with-fractions"
    prompt, options, key = _shape(item_id, ALL_ITEMS[item_id])
    options[key] = r"x = \frac{36}{4}"
    assert any("option text differs" in p for p in verify_item(item_id, prompt, options, key))


def test_reordered_options_without_moving_key_are_detected():
    item_id = "alg-sim-absolute-value-equation-linear-rhs"
    prompt, options, key = _shape(item_id, ALL_ITEMS[item_id])
    other = (key + 1) % len(options)
    options[key], options[other] = options[other], options[key]
    assert any("keyed position" in p for p in verify_item(item_id, prompt, options, key))


def test_reordered_options_with_moved_key_still_verify():
    item_id = "alg-sim-absolute-value-equation-linear-rhs"
    prompt, options, key = _shape(item_id, ALL_ITEMS[item_id])
    options = list(reversed(options))
    assert verify_item(item_id, prompt, options, len(options) - 1 - key) == []


@pytest.mark.parametrize("item_id", ["alg-sim-complex-fraction-domain-exclusion", "alg-fmt-evaluate-log-base-4"])
def test_changed_prompt_is_detected(item_id):
    prompt, options, key = _shape(item_id, ALL_ITEMS[item_id])
    for edited in (prompt.replace("x", "z", 1), prompt + " ", prompt.replace(r"\pm", "")):
        if edited != prompt:
            assert any("prompt changed" in p for p in verify_item(item_id, edited, options, key))


def test_renamed_id_is_detected():
    item = ALL_ITEMS["alg-sim-slant-asymptote"]
    assert verify_item("alg-sim-slant-asymptote-v2", *_shape("alg-sim-slant-asymptote", item)) == [
        "alg-sim-slant-asymptote-v2: no oracle"
    ]


def test_oracle_respects_domain_exclusions():
    """x = 4 solves the cleared polynomial but is excluded by the denominator."""
    x = oracles.xr
    cleared = sp.solveset(x * (x - 4) + (x - 2) - 2, x, sp.S.Reals)
    assert cleared == sp.FiniteSet(-1, 4)
    assert ORACLES["alg-sim-rational-equation-extraneous-root"].truth == sp.FiniteSet(-1)
    assert ORACLES["alg-sim-radical-equation-extraneous-root"].truth == sp.FiniteSet(1)
    assert ORACLES["alg-sim-logarithmic-equation-domain-check"].truth == sp.FiniteSet(4)


def test_previous_ambiguous_distractor_would_be_caught():
    """PR-2c replaced distractor x >= 3: f(x) = (x - 2)^2 + 3 is one-to-one there too."""
    oracle = ORACLES["alg-sim-quadratic-inverse-domain-restriction"]
    assert is_correct(oracle, sp.Interval(3, sp.oo)), "x >= 3 is a valid restriction, so it cannot be a distractor"
    assert not is_correct(oracle, sp.Interval(-2, sp.oo))


def test_previous_rational_claim_was_false():
    """PR-2c removed 'rational' from the zero-discriminant key: x^2 - 2*sqrt(2)x + 2 has root sqrt(2)."""
    x = oracles.x
    poly = x**2 - 2 * sp.sqrt(2) * x + 2
    assert sp.discriminant(poly, x) == 0
    assert sp.roots(poly, x) == {sp.sqrt(2): 2}
    assert sp.sqrt(2).is_rational is False


# --------------------------------------------------------------------------
# Structure, balance and explanation regressions (on the shipped YAML)
# --------------------------------------------------------------------------


def test_all_60_simulation_items_structure_and_haladyna():
    key_counts = {0: 0, 1: 0, 2: 0, 3: 0}
    for item_id, item in SIMULATION.items():
        options = item["response_spec"]["options"]
        correct_idx = item["scoring_spec"]["correct_index"]
        assert len(options) == 4, f"{item_id} must have exactly 4 options"
        assert correct_idx in key_counts, f"{item_id} has invalid correct_index: {correct_idx}"
        key_counts[correct_idx] += 1
        for opt in options:
            lower = opt.lower()
            assert "all of the above" not in lower, f"{item_id} contains 'all of the above'"
            assert "none of the above" not in lower, f"{item_id} contains 'none of the above'"
        lengths = [len(opt.strip()) for opt in options if opt.strip()]
        ratio = max(lengths) / min(lengths)
        assert ratio <= 3.0, f"{item_id} distractor length ratio {ratio:.2f} exceeds 3.0: {options}"

    # Content-balance rule active in CI since PR-2a (plan §0A.2 step 12).
    for pos, count in key_counts.items():
        pct = count / 60.0
        assert 0.20 <= pct <= 0.30, f"Key position {pos} has unbalanced count: {count} ({pct:.1%})"


def test_all_40_formative_questions_structure():
    key_counts = {0: 0, 1: 0, 2: 0, 3: 0}
    for item_id, q in FORMATIVE.items():
        assert len(q["options"]) == 4, item_id
        assert q["correct_answer"] in key_counts, item_id
        key_counts[q["correct_answer"]] += 1
        assert len(q["explanation"].strip()) > 20, item_id
    assert all(count == 10 for count in key_counts.values()), key_counts


DRAFT_MARKERS = re.compile(r"\b(wait|recheck|todo|tbd|hmm|fixme)\b", re.IGNORECASE)


@pytest.mark.parametrize("item_id", sorted(ALL_ITEMS))
def test_explanations_have_no_draft_notes(item_id):
    explanation = ALL_ITEMS[item_id].get("explanation", "")
    assert explanation.strip(), f"{item_id} has no explanation"
    assert not DRAFT_MARKERS.search(explanation), f"{item_id} explanation contains draft notes"


def test_item_23_rational_equation_explanation_regression():
    item = SIMULATION["alg-sim-rational-equation-extraneous-root"]
    assert "x - 2" in item["prompt"] and "x - 4" in item["prompt"]
    assert item["response_spec"]["options"][item["scoring_spec"]["correct_index"]] == "x = -1 only"
    explanation = item["explanation"]
    assert "not equal" not in explanation
    assert "extraneous" in explanation.lower()
    assert "-1" in explanation


def test_item_08_complex_fraction_states_domain_exclusion():
    prompt = SIMULATION["alg-sim-complex-fraction-domain-exclusion"]["prompt"]
    assert r"\pm y" in prompt or r"x \neq -y" in prompt, f"Prompt must exclude x = -y: {prompt}"
