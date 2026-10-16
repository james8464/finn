import csv
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from prepare_clips import (  # noqa: E402
    LABELS,
    PrepareError,
    REPO_ROOT,
    Take,
    ensure_outside_repo,
    main,
    parse_take,
    plan_clips,
    plan_warnings,
    window_starts,
)


def take(participant="p01", label="squat", number="01"):
    return Take(Path(f"/raw/{participant}_{label}_{number}.mov"), participant, label, number)


class NamingTests(unittest.TestCase):
    def test_parses_labels_containing_underscores(self):
        parsed = parse_take(Path("/raw/p02_stiff_leg_deadlift_03.MOV"))
        self.assertEqual(("p02", "stiff_leg_deadlift", "03"), (parsed.participant, parsed.label, parsed.take))

    def test_rejects_unknown_label_and_loose_names(self):
        for name in ("p01_burpee_01.mov", "james_squat_01.mov", "p01_squat.mov", "p1_squat_01.mov"):
            with self.subTest(name=name), self.assertRaises(PrepareError):
                parse_take(Path(name))

    def test_exercise_labels_match_the_app(self):
        source = (REPO_ROOT / "Finn/Finn/Workout/ExerciseDefinition.swift").read_text()
        for label in LABELS[:4]:
            self.assertIn(f'classifierLabel: "{label}"', source)


class PlanTests(unittest.TestCase):
    def test_windows_skip_trimmed_edges_and_do_not_overlap(self):
        self.assertEqual([0.5, 3.5, 6.5], window_starts(10.0, 3.0, 0.5))
        self.assertEqual([], window_starts(3.5, 3.0, 0.5))

    def test_participant_stays_in_one_split(self):
        takes = [take("p01"), take("p02"), take("p02", "push_up")]
        durations = {t.path: 10.0 for t in takes}
        clips = plan_clips(takes, durations, 3.0, 0.5, {"p02"})
        splits = {(c.take.participant, c.split) for c in clips}
        self.assertEqual({("p01", "train"), ("p02", "validation")}, splits)
        self.assertEqual(9, len(clips))
        self.assertEqual("validation/push_up/p02_push_up_01_03.mov", clips[-1].relative_path().as_posix())

    def test_unknown_validation_participant_is_an_error(self):
        with self.assertRaisesRegex(PrepareError, "p09"):
            plan_clips([take()], {take().path: 10.0}, 3.0, 0.5, {"p09"})

    def test_warnings_flag_small_classes_and_random_split(self):
        clips = plan_clips([take()], {take().path: 10.0}, 3.0, 0.5, set())
        warnings = plan_warnings(clips, set())
        self.assertTrue(any(w.startswith("push_up: 0 training clips") for w in warnings))
        self.assertTrue(any("no held-out participant" in w for w in warnings))

    def test_output_inside_repository_is_refused(self):
        with self.assertRaisesRegex(PrepareError, "inside the repository"):
            ensure_outside_repo(REPO_ROOT / "clips")
        ensure_outside_repo(Path(tempfile.gettempdir()) / "finn-clips")


@unittest.skipUnless(shutil.which("ffmpeg") and shutil.which("ffprobe"), "needs ffmpeg")
class CuttingTests(unittest.TestCase):
    def test_cuts_silent_clips_and_writes_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            raw = Path(directory) / "raw"
            raw.mkdir()
            for name in ("p01_squat_01.mov", "p02_squat_01.mov"):
                subprocess.run(
                    [
                        "ffmpeg",
                        "-nostdin",
                        "-loglevel",
                        "error",
                        "-f",
                        "lavfi",
                        "-i",
                        "testsrc=size=180x320:rate=30:duration=7",
                        "-f",
                        "lavfi",
                        "-i",
                        "sine=duration=7",
                        "-shortest",
                        "-c:v",
                        "libx264",
                        "-pix_fmt",
                        "yuv420p",
                        str(raw / name),
                    ],
                    check=True,
                    stdin=subprocess.DEVNULL,
                )
            output = Path(directory) / "dataset"
            self.assertEqual(0, main([str(raw), str(output), "--validation-participants", "p02"]))
            train = sorted((output / "train/squat").iterdir())
            self.assertEqual(["p01_squat_01_01.mov", "p01_squat_01_02.mov"], [p.name for p in train])
            streams = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-show_entries",
                    "stream=codec_type",
                    "-of",
                    "csv=p=0",
                    str(train[0]),
                ],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.split()
            self.assertEqual(["video"], streams)
            with (output / "manifest.csv").open() as file:
                rows = list(csv.DictReader(file))
            self.assertEqual({"train", "validation"}, {row["split"] for row in rows})
            self.assertEqual(2, main([str(raw), str(output)]), "a non-empty output is refused")


if __name__ == "__main__":
    unittest.main()
