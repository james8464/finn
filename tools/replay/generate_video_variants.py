#!/usr/bin/env python3
"""Rebuild synthetic camera-condition variants from the checked-in squat fixture.

Requires ffmpeg on PATH, or the imageio-ffmpeg Python package used in this workspace.
No real workout recording is read or written.
"""

from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent
FIXTURES = ROOT / "fixtures"
SOURCE = FIXTURES / "squat-six-reps.mp4"
VARIANTS = {
    "squat-mirrored.mp4": "hflip",
    "squat-dim.mp4": "eq=brightness=-0.23:saturation=0.7",
    "squat-far.mp4": "scale=432:576,pad=720:960:144:192:color=0xbcbec1",
    "squat-too-far.mp4": "scale=216:288,pad=720:960:252:336:color=0xbcbec1",
    "squat-slow.mp4": "setpts=1.5*PTS",
    "squat-overexposed.mp4": "eq=brightness=0.22:contrast=0.75:saturation=0.8",
    "squat-warm-indoor.mp4": "colorbalance=rs=0.10:gs=0.02:bs=-0.08",
    "squat-low-resolution.mp4": "scale=180:240:flags=bilinear,scale=720:960:flags=neighbor",
    "squat-off-center.mp4": "crop=576:960:144:0,pad=720:960:0:0:color=0xbcbec1",
    "squat-angled-phone.mp4": "rotate=0.12:fillcolor=0xbcbec1:ow=iw:oh=ih",
    "squat-motion-blur.mp4": "tmix=frames=3:weights=1 1 1",
    "squat-phone-shake.mp4": "crop=600:960:x='60+50*sin(n/8)':y=0,pad=720:960:60:0:color=0xbcbec1",
}


def ffmpeg_path() -> str:
    if binary := shutil.which("ffmpeg"):
        return binary
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError as error:
        raise SystemExit("Install ffmpeg or imageio-ffmpeg to rebuild these fixtures") from error


def main() -> None:
    binary = ffmpeg_path()
    for name, video_filter in VARIANTS.items():
        output = FIXTURES / name
        subprocess.run(
            [binary, "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
             "-i", str(SOURCE), "-vf", video_filter, "-an", "-c:v", "libx264",
             "-crf", "28", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
             str(output)],
            check=True,
        )
        print(f"{name}: {output.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
