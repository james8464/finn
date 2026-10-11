import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "docs" / "validation"))

from score_squat_v1 import ValidationError, evaluate  # noqa: E402


def row(set_id, participant_id, **changes):
    values = {
        "set_id": set_id,
        "participant_id": participant_id,
        "split": "holdout",
        "consent_version": "v1",
        "device_model": "iPhone 18 Pro",
        "ios_build": "27.0",
        "app_commit": "abc123",
        "rubric_version": "squat-side-v2",
        "side": "left",
        "view_category": "side",
        "lighting": "bright_even",
        "body_visible": "yes",
        "bystander": "no",
        "setup_attempts": "1",
        "reference_method": "live",
        "human_reps_a": "6",
        "human_reps_b": "6",
        "adjudicated_reps": "6",
        "app_outcome": "measured",
        "app_reps": "6",
        "cue_kind": "",
        "cue_rep_numbers": "",
        "expert_supported": "",
        "expert_show": "",
        "expert_unassessable": "",
        "expert_view_suitable": "yes",
        "result_latency_ms": "3200",
        "failure_reason": "",
    }
    values.update(changes)
    return values


class SquatScorerTests(unittest.TestCase):
    def test_countable_rejection_is_a_rep_miss_and_setup_uses_unique_people(self):
        rows = [
            row("a", "person-1"),
            row("b", "person-1"),
            row("c", "person-2", app_outcome="insufficient_view", app_reps="",
                result_latency_ms="", setup_attempts="3", failure_reason="low_confidence"),
        ]
        result = evaluate(rows)
        self.assertEqual((1, 2), (result["setup"]["numerator"], result["setup"]["denominator"]))
        self.assertEqual((2, 3), (result["rep_count"]["numerator"], result["rep_count"]["denominator"]))

    def test_participant_cannot_cross_tuning_and_holdout(self):
        with self.assertRaisesRegex(ValidationError, "both splits"):
            evaluate([row("a", "person-1", split="tuning"), row("b", "person-1")])

    def test_zero_emitted_cues_are_not_perfect_agreement(self):
        result = evaluate([row("a", "person-1")])
        self.assertEqual("not measurable", result["cue_agreement"]["status"])
        self.assertEqual((0, 1), (result["cue_coverage"]["numerator"], result["cue_coverage"]["denominator"]))

    def test_unreviewed_cue_cannot_pass_agreement(self):
        result = evaluate([row("a", "person-1", cue_kind="rangeDecreased",
                               cue_rep_numbers="5;6")])
        self.assertEqual("unverified", result["cue_agreement"]["status"])
        self.assertEqual((0, 1), (result["cue_agreement"]["numerator"], result["cue_agreement"]["denominator"]))

    def test_missing_result_latency_cannot_pass(self):
        result = evaluate([row("a", "person-1", result_latency_ms="")])
        self.assertEqual("unverified", result["latency"]["status"])
        self.assertEqual((0, 1), (result["latency"]["numerator"], result["latency"]["denominator"]))

    def test_mixed_app_commits_in_holdout_are_rejected(self):
        with self.assertRaisesRegex(ValidationError, "app_commit"):
            evaluate([row("a", "person-1"), row("b", "person-2", app_commit="def456")])

    def test_one_countable_set_cannot_validate_rep_gate(self):
        rows = [row(f"t{i}", f"tune-{i}", split="tuning") for i in range(12)]
        rows += [row(f"h{i}", f"hold-{i}", adjudicated_reps="" if i else "6",
                     human_reps_a="" if i else "6", human_reps_b="" if i else "6")
                 for i in range(18)]
        result = evaluate(rows)
        self.assertTrue(result["sample_ready"])
        self.assertEqual("unverified", result["rep_count"]["status"])

    def test_zero_setup_attempts_are_invalid(self):
        with self.assertRaisesRegex(ValidationError, "setup_attempts"):
            evaluate([row("a", "person-1", setup_attempts="0")])

    def test_full_synthetic_holdout_can_pass_numeric_gates(self):
        rows = [row(f"t{i}", f"tune-{i}", split="tuning") for i in range(12)]
        rows += [row(f"h{i}", f"hold-{i}", cue_kind="rangeDecreased" if i < 5 else "",
                     cue_rep_numbers="5;6" if i < 5 else "",
                     expert_supported="yes" if i < 5 else "",
                     expert_show="yes" if i < 5 else "") for i in range(18)]
        result = evaluate(rows)
        self.assertEqual(["pass"] * 4, [result[key]["status"] for key in
                                          ("setup", "rep_count", "cue_agreement", "latency")])
        self.assertEqual((5, 18), (result["cue_coverage"]["numerator"],
                                   result["cue_coverage"]["denominator"]))

    def test_single_reviewed_cue_is_too_few_to_validate_agreement(self):
        rows = [row(f"t{i}", f"tune-{i}", split="tuning") for i in range(12)]
        rows += [row(f"h{i}", f"hold-{i}", cue_kind="rangeDecreased" if i == 0 else "",
                     cue_rep_numbers="5;6" if i == 0 else "",
                     expert_supported="yes" if i == 0 else "",
                     expert_show="yes" if i == 0 else "") for i in range(18)]
        self.assertEqual("unverified", evaluate(rows)["cue_agreement"]["status"])

    def test_emitted_cue_requires_valid_rep_references(self):
        with self.assertRaisesRegex(ValidationError, "cue_rep_numbers"):
            evaluate([row("a", "person-1", cue_kind="rangeDecreased",
                          cue_rep_numbers="5;7")])


if __name__ == "__main__":
    unittest.main()
