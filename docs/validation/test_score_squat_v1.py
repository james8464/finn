"""Regression checks for camera-view validation and honest missing-evidence status."""

import unittest

from score_squat_v1 import COLUMNS, ValidationError, evaluate, render_report


def row(set_id, participant_id, view, suitable, outcome):
    result = dict.fromkeys(COLUMNS, "")
    result.update(
        set_id=set_id,
        participant_id=participant_id,
        split="holdout",
        consent_version="v1",
        device_model="iPhone",
        ios_build="27.0",
        app_commit="abc123",
        rubric_version="squat-side-v7",
        lighting="even",
        side="left",
        view_category=view,
        body_visible="yes",
        bystander="no",
        setup_attempts="1",
        app_outcome=outcome,
        app_reps="5" if outcome == "measured" else "",
        expert_view_suitable=suitable,
    )
    return result


class ViewValidationTests(unittest.TestCase):
    def test_empty_holdout_is_unverified(self):
        result = evaluate([])
        self.assertEqual(result["unsuitable_view_acceptance"]["status"], "unverified")

    def test_measured_front_view_is_visible_as_false_acceptance(self):
        result = evaluate(
            [
                row("front-1", "person-a", "front", "no", "measured"),
                row("quarter-1", "person-b", "three_quarter", "no", "insufficient_view"),
                row("side-1", "person-c", "side", "yes", "measured"),
            ]
        )
        self.assertEqual(
            result["unsuitable_view_acceptance"], {"numerator": 1, "denominator": 2, "status": "reported"}
        )
        report = render_report(result)
        self.assertIn("Measured on unsuitable view (lower is better) | 1 / 2", report)
        self.assertIn("| view_category | front | 1 |", report)

    def test_missing_expert_view_label_cannot_look_complete(self):
        result = evaluate([row("front-1", "person-a", "front", "", "measured")])
        self.assertEqual(result["unsuitable_view_acceptance"]["status"], "unverified")

    def test_unknown_view_category_is_rejected(self):
        with self.assertRaisesRegex(ValidationError, "invalid view_category"):
            evaluate([row("front-1", "person-a", "diagonal", "no", "measured")])

    def test_posture_cue_can_be_reviewed_in_holdout(self):
        sample = row("side-1", "person-a", "side", "yes", "measured")
        sample["cue_kind"] = "torsoTiltIncreased"
        sample["cue_rep_numbers"] = "4;5"
        sample["expert_supported"] = "yes"
        sample["expert_show"] = "yes"
        evaluate([sample])


if __name__ == "__main__":
    unittest.main()
