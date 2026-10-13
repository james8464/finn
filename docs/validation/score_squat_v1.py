"""Score the frozen Plumb squat validation sheet. Standard library only."""

import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path


COLUMNS = (
    "set_id participant_id split consent_version capture_date device_model ios_build "
    "app_commit rubric_version camera orientation side view_category distance_m camera_height_cm "
    "lighting clothing_contrast body_visible bystander setup_attempts reference_method "
    "human_reps_a human_reps_b adjudicated_reps app_outcome app_reps cue_kind "
    "cue_rep_numbers expert_supported expert_show expert_unassessable expert_view_suitable "
    "result_latency_ms capture_duration_s interruption thermal_issue failure_reason notes"
).split()
RUBRIC = "squat-side-v7"


class ValidationError(ValueError):
    pass


def _number(row, field, integer=True):
    value = row.get(field, "").strip()
    if not value:
        return None
    try:
        number = int(value) if integer else float(value)
    except ValueError as error:
        raise ValidationError(f"{row['set_id']}: {field} must be a number") from error
    if number < 0 or (integer and str(number) != value):
        raise ValidationError(f"{row['set_id']}: {field} must be nonnegative")
    return number


def _metric(numerator, denominator, status):
    return {"numerator": numerator, "denominator": denominator, "status": status}


def _gate(numerator, denominator, threshold, ready):
    if denominator == 0 or not ready:
        return "unverified"
    return "pass" if numerator / denominator >= threshold else "fail"


def evaluate(rows):
    """Return holdout metrics; never turn missing evidence into a passing gate."""
    seen = set()
    participant_splits = defaultdict(set)
    for row in rows:
        set_id = row.get("set_id", "").strip()
        participant = row.get("participant_id", "").strip()
        if not set_id or not participant:
            raise ValidationError("every row needs set_id and participant_id")
        if set_id in seen:
            raise ValidationError(f"duplicate set_id: {set_id}")
        seen.add(set_id)
        split = row.get("split", "").strip()
        if split not in {"tuning", "holdout"}:
            raise ValidationError(f"{set_id}: split must be tuning or holdout")
        participant_splits[participant].add(split)
        for field in ("consent_version", "device_model", "ios_build", "app_commit", "lighting", "side"):
            if not row.get(field, "").strip():
                raise ValidationError(f"{set_id}: missing {field}")
        if row.get("rubric_version", "").strip() != RUBRIC:
            raise ValidationError(f"{set_id}: rubric_version must be {RUBRIC}")
        if row.get("app_outcome", "").strip() not in {
            "measured", "insufficient_view", "failed", "interrupted"
        }:
            raise ValidationError(f"{set_id}: invalid app_outcome")
        if row.get("view_category", "").strip() not in {
            "side", "three_quarter", "front", "unclear"
        }:
            raise ValidationError(f"{set_id}: invalid view_category")
        for field in ("body_visible", "bystander"):
            if row.get(field, "").strip() not in {"yes", "no"}:
                raise ValidationError(f"{set_id}: {field} must be yes or no")
        for field in ("expert_supported", "expert_show", "expert_unassessable",
                      "expert_view_suitable"):
            if row.get(field, "").strip() not in {"", "yes", "no"}:
                raise ValidationError(f"{set_id}: {field} must be yes, no, or blank")
        for field in ("setup_attempts", "human_reps_a", "human_reps_b", "adjudicated_reps", "app_reps", "result_latency_ms"):
            _number(row, field)
        if _number(row, "setup_attempts") == 0:
            raise ValidationError(f"{set_id}: setup_attempts must be at least 1")
        if row["app_outcome"] == "measured" and _number(row, "app_reps") is None:
            raise ValidationError(f"{set_id}: measured outcome needs app_reps")
        if row["app_outcome"] != "measured" and row.get("app_reps", "").strip():
            raise ValidationError(f"{set_id}: rejected outcome cannot have app_reps")
        cue_kind = row.get("cue_kind", "").strip()
        if cue_kind not in {"", "rangeDecreased", "torsoTiltIncreased"}:
            raise ValidationError(f"{set_id}: invalid cue_kind for frozen rubric")
        if cue_kind and row["app_outcome"] != "measured":
            raise ValidationError(f"{set_id}: cue requires a measured outcome")
        references = row.get("cue_rep_numbers", "").strip()
        if cue_kind:
            parts = references.split(";")
            app_reps = _number(row, "app_reps")
            if not references or any(not part.isdigit() or not 1 <= int(part) <= app_reps
                                     for part in parts) or len(parts) != len(set(parts)):
                raise ValidationError(f"{set_id}: cue_rep_numbers must refer to app reps")
        elif references:
            raise ValidationError(f"{set_id}: cue_rep_numbers requires cue_kind")
    if any(len(splits) > 1 for splits in participant_splits.values()):
        raise ValidationError("participant appears in both splits")

    holdout = [row for row in rows if row["split"] == "holdout"]
    commits = {row["app_commit"] for row in holdout}
    if len(commits) > 1:
        raise ValidationError("holdout must use one frozen app_commit")
    sample_ready = len(rows) >= 30 and len(holdout) >= 18

    people = defaultdict(list)
    for row in holdout:
        people[row["participant_id"]].append(row)
    setup_ok = sum(any(
        row["app_outcome"] == "measured" and
        (_number(row, "setup_attempts") or 999) <= 2
        for row in sets
    ) for sets in people.values())
    setup_complete = all(_number(row, "setup_attempts") is not None for row in holdout)

    countable = [row for row in holdout if _number(row, "adjudicated_reps") is not None]
    rep_ok = sum(row["app_outcome"] == "measured" and
                 _number(row, "app_reps") == _number(row, "adjudicated_reps")
                 for row in countable)
    label_complete = all(row.get("reference_method", "").strip() and
                         _number(row, "human_reps_a") is not None and
                         _number(row, "human_reps_b") is not None
                         for row in countable)

    usable = [row for row in holdout if row["app_outcome"] == "measured"]
    emitted = [row for row in holdout if row.get("cue_kind", "").strip()]
    reviewed = [row for row in emitted if row.get("expert_supported", "").strip() and
                row.get("expert_show", "").strip()]
    show = sum(row["expert_supported"] == "yes" and row["expert_show"] == "yes"
               for row in reviewed)
    cue_status = ("not measurable" if not emitted else
                  _gate(show, len(emitted), .8, sample_ready and len(emitted) >= 5
                        and len(reviewed) == len(emitted)))

    timed = [row for row in usable if _number(row, "result_latency_ms") is not None]
    timely = sum(_number(row, "result_latency_ms") <= 5000 for row in timed)
    rejected = [row for row in holdout if row["app_outcome"] == "insufficient_view"]
    abstention_reviewed = [row for row in rejected if row.get("expert_unassessable", "").strip()]
    view_labels_complete = all(row.get("expert_view_suitable", "").strip() for row in holdout)
    unsuitable = [row for row in holdout if row.get("expert_view_suitable") == "no"]
    unsuitable_measured = sum(row["app_outcome"] == "measured" for row in unsuitable)
    view_status = ("unverified" if not holdout or not view_labels_complete else
                   "not measurable" if not unsuitable else "reported")

    breakdown = {}
    for field in ("device_model", "lighting", "side", "view_category"):
        groups = defaultdict(list)
        for row in holdout:
            groups[row[field]].append(row)
        breakdown[field] = {
            key: {"sets": len(group),
                  "countable": sum(_number(row, "adjudicated_reps") is not None for row in group),
                  "exact": sum(row["app_outcome"] == "measured" and
                               _number(row, "adjudicated_reps") is not None and
                               _number(row, "app_reps") == _number(row, "adjudicated_reps")
                               for row in group)}
            for key, group in sorted(groups.items())
        }
    failures = Counter(row.get("failure_reason", "").strip() or row["app_outcome"]
                       for row in holdout if row["app_outcome"] != "measured")
    return {
        "total_sets": len(rows), "holdout_sets": len(holdout),
        "holdout_people": len(people), "sample_ready": sample_ready,
        "app_commit": next(iter(commits), "unfrozen"),
        "setup": _metric(setup_ok, len(people), _gate(setup_ok, len(people), .8,
                                                      sample_ready and setup_complete)),
        "rep_count": _metric(rep_ok, len(countable), _gate(rep_ok, len(countable), .9,
                                                            sample_ready and len(countable) >= 18
                                                            and label_complete)),
        "cue_agreement": _metric(show, len(emitted), cue_status),
        "cue_reviews": _metric(len(reviewed), len(emitted),
                               "reported" if emitted else "not measurable"),
        "cue_coverage": _metric(len(emitted), len(usable), "reported" if usable else "unverified"),
        "latency": _metric(timely, len(usable), _gate(timely, len(usable), 1.0,
                                                       sample_ready and len(timed) == len(usable))),
        "abstention": _metric(sum(row["expert_unassessable"] == "yes" for row in abstention_reviewed),
                              len(rejected), "reported" if len(abstention_reviewed) == len(rejected)
                              and rejected else "unverified"),
        "unsuitable_view_acceptance": _metric(unsuitable_measured, len(unsuitable), view_status),
        "breakdown": breakdown, "failures": failures,
    }


def render_report(result):
    lines = ["# Squat v1 holdout score", "",
             f"Data: {result['total_sets']} total sets; {result['holdout_sets']} holdout sets; "
             f"{result['holdout_people']} holdout people. Frozen app commit: `{result['app_commit']}`.",
             "",
             "Sample gate: " + ("met" if result["sample_ready"] else
                                "unverified (need at least 30 total and 18 holdout sets)"),
             "", "| Measure | Numerator / denominator | Status |", "| --- | ---: | --- |"]
    labels = (("setup", "Setup within two attempts"), ("rep_count", "Exact rep count"),
              ("cue_agreement", "Cue agreement"), ("cue_reviews", "Cue reviews complete"),
              ("cue_coverage", "Cue coverage"), ("latency", "Results within 5 seconds"),
              ("abstention", "Reviewer agrees with view rejection"),
              ("unsuitable_view_acceptance", "Measured on unsuitable view (lower is better)"))
    for key, label in labels:
        metric = result[key]
        lines.append(f"| {label} | {metric['numerator']} / {metric['denominator']} | "
                     f"{metric['status']} |")
    lines += ["", "## Holdout breakdown", "", "| Factor | Value | Sets | Exact / countable |",
              "| --- | --- | ---: | ---: |"]
    for field, groups in result["breakdown"].items():
        for value, counts in groups.items():
            lines.append(f"| {field} | {value} | {counts['sets']} | "
                         f"{counts['exact']} / {counts['countable']} |")
    lines += ["", "## Non-measured outcomes", ""]
    if result["failures"]:
        lines += ["| Reason | Sets |", "| --- | ---: |"]
        lines += [f"| {reason} | {count} |" for reason, count in sorted(result["failures"].items())]
    else:
        lines.append("None recorded.")
    lines += ["", "A pass requires the full sample and complete relevant annotations. "
              "This report does not replace physical-device and specialist review.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sheet", type=Path, help="CSV using squat-v1-template.csv columns")
    parser.add_argument("--output", type=Path, help="write Markdown report (refuses overwrite)")
    args = parser.parse_args()
    try:
        with args.sheet.open(newline="", encoding="utf-8-sig") as file:
            reader = csv.DictReader(file)
            missing = set(COLUMNS) - set(reader.fieldnames or [])
            if missing:
                raise ValidationError("missing columns: " + ", ".join(sorted(missing)))
            rows = list(reader)
            if any(None in row or any(value is None for value in row.values()) for row in rows):
                raise ValidationError("CSV row has missing or extra cells")
        report = render_report(evaluate(rows))
        if args.output:
            with args.output.open("x", encoding="utf-8") as file:
                file.write(report)
        else:
            print(report)
    except (OSError, ValidationError) as error:
        parser.exit(2, f"Validation error: {error}\n")


if __name__ == "__main__":
    main()
