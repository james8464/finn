"""Cut labeled exercise recordings into clips for a Create ML action classifier.

Standard library only; ffprobe and ffmpeg must be on PATH. Video never goes inside the
repository: the script refuses an output folder in this checkout.

Each recording is one participant doing one class, named <participant>_<label>_<take>.mov,
for example p01_push_up_02.mov. The script cuts it into fixed windows, drops the audio,
keeps every clip from one participant in the same split, and writes
<output>/train/<label>/... and <output>/validation/<label>/... plus manifest.csv.
"""

import argparse
import csv
import re
import shutil
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

# Folder names the Create ML classifier learns. The four exercise labels must match
# `classifierLabel` in Finn/Finn/Workout/ExerciseDefinition.swift.
EXERCISE_LABELS = ("squat", "push_up", "static_lunge", "stiff_leg_deadlift")
LABELS = EXERCISE_LABELS + ("other", "none")
VIDEO_SUFFIXES = {".mov", ".mp4", ".m4v"}
TAKE_NAME = re.compile(r"^(?P<participant>p\d{2})_(?P<label>[a-z_]+)_(?P<take>\d{2})$")
MIN_TRAINING_CLIPS = 50
REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_COLUMNS = ("clip", "split", "label", "participant", "source", "start_s", "duration_s")


class PrepareError(ValueError):
    pass


@dataclass(frozen=True)
class Take:
    path: Path
    participant: str
    label: str
    take: str


@dataclass(frozen=True)
class Clip:
    take: Take
    index: int
    start: float
    duration: float
    split: str

    def relative_path(self) -> Path:
        name = f"{self.take.participant}_{self.take.label}_{self.take.take}_{self.index:02d}.mov"
        return Path(self.split) / self.take.label / name


def parse_take(path: Path) -> Take:
    match = TAKE_NAME.match(path.stem)
    if not match or match["label"] not in LABELS:
        raise PrepareError(
            f"{path.name}: name it <participant>_<label>_<take>{path.suffix}, for example "
            f"p01_push_up_01{path.suffix}; labels are {', '.join(LABELS)}"
        )
    return Take(path, match["participant"], match["label"], match["take"])


def find_takes(raw: Path) -> list[Take]:
    files = sorted(p for p in raw.rglob("*") if p.is_file() and p.suffix.lower() in VIDEO_SUFFIXES)
    if not files:
        raise PrepareError(f"no .mov, .mp4 or .m4v recordings in {raw}")
    takes = [parse_take(path) for path in files]
    seen = Counter((t.participant, t.label, t.take) for t in takes)
    duplicates = [key for key, count in seen.items() if count > 1]
    if duplicates:
        raise PrepareError(f"duplicate take names: {duplicates}")
    return takes


def window_starts(duration: float, window: float, trim: float) -> list[float]:
    """Non-overlapping windows inside the recording, skipping `trim` seconds at each end."""
    if window <= 0 or trim < 0:
        raise PrepareError("window must be positive and trim nonnegative")
    starts, start = [], trim
    while start + window <= duration - trim + 1e-9:
        starts.append(round(start, 3))
        start += window
    return starts


def plan_clips(takes, durations, window, trim, validation_participants) -> list[Clip]:
    unknown = set(validation_participants) - {t.participant for t in takes}
    if unknown:
        raise PrepareError(f"validation participants not found in recordings: {sorted(unknown)}")
    clips = []
    for take in takes:
        split = "validation" if take.participant in validation_participants else "train"
        for index, start in enumerate(window_starts(durations[take.path], window, trim), 1):
            clips.append(Clip(take, index, start, window, split))
    if not clips:
        raise PrepareError("the recordings are too short for one clip; record longer takes")
    return clips


def plan_warnings(clips, validation_participants) -> list[str]:
    counts = Counter((c.split, c.take.label) for c in clips)
    warnings = []
    for label in LABELS:
        if counts["train", label] < MIN_TRAINING_CLIPS:
            warnings.append(f"{label}: {counts['train', label]} training clips "
                            f"(aim for at least {MIN_TRAINING_CLIPS})")
        if validation_participants and counts["validation", label] == 0:
            warnings.append(f"{label}: no validation clip, so its validation score is unknown")
    participants = {c.take.participant for c in clips}
    if not validation_participants:
        warnings.append("no held-out participant: Create ML will split clips at random, and clips "
                        "cut from one recording will sit in both sets, which inflates the score")
    elif participants <= set(validation_participants):
        warnings.append("every participant is in validation; nothing is left to train on")
    return warnings


def ensure_outside_repo(output: Path) -> None:
    resolved = output.resolve()
    if resolved == REPO_ROOT or REPO_ROOT in resolved.parents:
        raise PrepareError(f"{output} is inside the repository; keep video outside it")


def probe_duration(path: Path) -> float:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        check=True, capture_output=True, text=True, stdin=subprocess.DEVNULL,
    )
    return float(result.stdout.strip())


def cut_clip(clip: Clip, output: Path, frame_rate: int) -> None:
    destination = output / clip.relative_path()
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-nostdin", "-loglevel", "error", "-ss", f"{clip.start:.3f}",
         "-i", str(clip.take.path), "-t", f"{clip.duration:.3f}", "-an",
         "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-r", str(frame_rate),
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(destination)],
        check=True, stdin=subprocess.DEVNULL,
    )


def write_manifest(clips, output: Path) -> None:
    with (output / "manifest.csv").open("w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(MANIFEST_COLUMNS)
        for clip in clips:
            writer.writerow([clip.relative_path().as_posix(), clip.split, clip.take.label,
                             clip.take.participant, clip.take.path.name,
                             f"{clip.start:.3f}", f"{clip.duration:.3f}"])


def summary_table(clips) -> str:
    counts = Counter((c.split, c.take.label) for c in clips)
    lines = [f"{'label':<20}{'train':>8}{'validation':>12}"]
    for label in LABELS:
        lines.append(f"{label:<20}{counts['train', label]:>8}{counts['validation', label]:>12}")
    return "\n".join(lines)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("raw", type=Path, help="folder of recordings named p01_squat_01.mov")
    parser.add_argument("output", type=Path, help="new dataset folder, outside the repository")
    parser.add_argument("--validation-participants", nargs="*", default=[],
                        help="participant IDs held out for validation, for example p04")
    parser.add_argument("--window", type=float, default=3.0, help="clip length in seconds")
    parser.add_argument("--trim", type=float, default=0.5,
                        help="seconds skipped at the start and end of each recording")
    parser.add_argument("--frame-rate", type=int, default=30)
    parser.add_argument("--dry-run", action="store_true", help="print the plan without cutting")
    args = parser.parse_args(argv)

    try:
        ensure_outside_repo(args.output)
        if args.output.exists() and any(args.output.iterdir()):
            raise PrepareError(f"{args.output} is not empty; choose a new folder")
        for tool in ("ffprobe",) if args.dry_run else ("ffprobe", "ffmpeg"):
            if shutil.which(tool) is None:
                raise PrepareError(f"{tool} is not on PATH (brew install ffmpeg)")
        takes = find_takes(args.raw)
        durations = {take.path: probe_duration(take.path) for take in takes}
        clips = plan_clips(takes, durations, args.window, args.trim,
                           set(args.validation_participants))
    except (PrepareError, subprocess.CalledProcessError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    print(summary_table(clips))
    for warning in plan_warnings(clips, set(args.validation_participants)):
        print(f"warning: {warning}")
    if args.dry_run:
        return 0
    args.output.mkdir(parents=True, exist_ok=True)
    for clip in clips:
        cut_clip(clip, args.output, args.frame_rate)
    write_manifest(clips, args.output)
    print(f"wrote {len(clips)} clips and manifest.csv to {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
