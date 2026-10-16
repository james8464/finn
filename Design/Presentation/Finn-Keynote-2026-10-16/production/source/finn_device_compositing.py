from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import json, math, subprocess as sp, sys

# Keep the established human edit and original score; rebuild the product film.
exec(Path(__file__).with_name('finn_film_assets.py').read_text())
V = P / 'render-v3'
V.mkdir(exist_ok=True)
for key, path in [('native-live', R / 'videos/live.mp4')]:
    d = V / key
    d.mkdir(exist_ok=True)
    if not (d / '0001.jpg').exists():
        run([FF, '-y', '-i', str(path), '-vf', 'fps=24', '-q:v', '2', str(d / '%04d.jpg')])
    files[key] = sorted(d.glob('*.jpg'))
    assert files[key]
watch_bezel = Image.open(R / 'assets/apple/watch11-black.png').convert('RGBA')
watch_screen = Image.open(R / 'assets/captures/watch-coach.png').convert('RGB')
posture = Image.open(R / 'assets/captures/posture.png').convert('RGB')
cue = Image.open('/tmp/finn-clean-posture-tip.png').convert('RGB').crop((72, 645, 1248, 875))
cache = {}


def phone(im, screen, x, y, h, alpha=1):
    z = h / 3000
    wh = (round(1470 * z), round(h))
    can = Image.new('RGBA', wh)
    sc = rounded(screen.resize((round(1320 * z), round(2868 * z)), Image.Resampling.LANCZOS), round(145 * z))
    can.paste(sc, (round(75 * z), round(66 * z)), sc)
    if wh not in cache:
        cache[wh] = bezel.resize(wh, Image.Resampling.LANCZOS)
    can.alpha_composite(cache[wh])
    over(im, can, (x, y), alpha)


def watch(im, screen, x, y, h, alpha=1):
    z = h / 880
    wh = (round(560 * z), round(h))
    can = Image.new('RGBA', wh)
    sc = rounded(screen.resize((round(416 * z), round(496 * z)), Image.Resampling.LANCZOS), round(92 * z))
    can.paste(sc, (round(72 * z), round(192 * z)), sc)
    key = ('watch', wh)
    if key not in cache:
        cache[key] = watch_bezel.resize(wh, Image.Resampling.LANCZOS)
    can.alpha_composite(cache[key])
    over(im, can, (x, y), alpha)


def tip(im, xy, w, alpha=1):
    lay = rounded(
        cue.resize((round(w), round(cue.height * w / cue.width)), Image.Resampling.LANCZOS), round(w * 0.035)
    )
    over(im, lay, xy, alpha, 14)
