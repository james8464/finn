from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
import numpy as np, subprocess as sp, json, math, wave, sys

R = Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16')
P = R / 'production/film'
W = P / 'render'
W.mkdir(exist_ok=True)
FF = '/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
FPS = 24
SIZE = (1920, 1080)
REG = '/Users/james/Library/Fonts/SF-Pro-Display-Regular.otf'
BOLD = '/Users/james/Library/Fonts/SF-Pro-Display-Semibold.otf'
pink = (255, 45, 146)
paths = {k: R / f'assets/film/{k}-source.mp4' for k in ['morning', 'office', 'workout']}
paths.update({k: R / f'videos/{k}.mp4' for k in ['setup', 'live', 'result']})


def run(a):
    sp.run(a, check=True, stdout=sp.DEVNULL, stderr=sp.DEVNULL)


for k, path in paths.items():
    d = W / k
    d.mkdir(exist_ok=True)
    if not (d / '0001.jpg').exists():
        run([FF, '-y', '-i', str(path), '-vf', f'fps={FPS}', '-q:v', '2', str(d / '%04d.jpg')])
print('Decoded plates', flush=True)
files = {k: sorted((W / k).glob('*.jpg')) for k in paths}


def source(k, t):
    f = files[k][min(len(files[k]) - 1, max(0, int(t * FPS)))]
    return Image.open(f).convert('RGB')


def ease(t):
    return 1 - (1 - max(0, min(1, t))) ** 4


fonts = {}


def text(im, s, xy, size=80, color='white', bold=True, center=False, opacity=1):
    key = (size, bold)
    if key not in fonts:
        fonts[key] = ImageFont.truetype(BOLD if bold else REG, size)
    f = fonts[key]
    d = ImageDraw.Draw(im)
    w = d.textlength(s, font=f)
    x, y = xy
    if center:
        x -= w / 2
    if opacity >= 0.999:
        d.text((round(x), round(y)), s, font=f, fill=color, anchor='lt', stroke_width=0)
    else:
        l = Image.new('RGBA', im.size)
        ImageDraw.Draw(l).text((round(x), round(y)), s, font=f, fill=color, anchor='lt')
        l.putalpha(l.getchannel('A').point(lambda v: round(v * max(0, opacity))))
        im.paste(l, (0, 0), l)


def fit(im, zoom=1, cx=0.5, cy=0.5):
    w, h = im.size
    ratio = 16 / 9
    cw = min(w, h * ratio) / zoom
    ch = cw / ratio
    x = max(0, min(w - cw, cx * w - cw / 2))
    y = max(0, min(h - ch, cy * h - ch / 2))
    return im.crop((round(x), round(y), round(x + cw), round(y + ch))).resize(SIZE, Image.Resampling.LANCZOS)


# 27 human cuts: urgency grows, then a deliberate breath.
edl = []


def cut(end, k, src, speed=1, zoom=1, cx=0.5, cy=0.5):
    start = edl[-1]['out'] if edl else 0
    edl.append(dict(start=start, out=end, source=k, source_in=src, speed=speed, zoom=zoom, cx=cx, cy=cy))


cut(0.85, 'morning', 0.05)
cut(1.4, 'morning', 1.12)
cut(2.1, 'morning', 2.1)
cut(2.55, 'morning', 3.35)
cut(4, 'morning', 4.2)
cut(4.55, 'morning', 2.55, 1, 1.3, 0.47, 0.56)
cut(5.5, 'morning', 7.35)
cut(6, 'office', 0.2, 1, 1.12)
cut(6.45, 'morning', 3.3, 1, 1.15)
cut(7.5, 'morning', 5.3)
cut(8.45, 'morning', 8.4)
cut(9.35, 'office', 3.4)
cut(9.9, 'office', 1.3, 1, 1.18)
cut(10.5, 'office', 5.25)
cut(11.15, 'office', 4.1)
cut(11.65, 'office', 1.8, 1, 1.28)
cut(12.2, 'morning', 6.15, 1, 1.12)
cut(12.7, 'office', 6, 1, 1.2)
cut(13.1, 'office', 0.6, 1, 1.3)
cut(13.5, 'office', 4.4, 1, 1.14)
cut(14.25, 'office', 5.4)
cut(15.5, 'office', 7.1, 0.9)
cut(18.25, 'office', 5.15, 0.6, 1.05)
cut(19.5, 'office', 8.65, 0.9)
cut(20.15, 'workout', 0.1)
cut(20.85, 'workout', 1.1)
cut(22.5, 'workout', 2.2)
cut(28.5, 'workout', 4, 1)
cut(30, 'workout', 8.45, 0.95, 1.1)
(P / 'edit-decision-list.json').write_text(
    json.dumps(
        {
            'fps': 24,
            'duration': 60,
            'human_cuts': edl,
            'product': [
                {'start': 30, 'out': 35, 'screen': 'setup'},
                {'start': 35, 'out': 42, 'screen': 'live'},
                {'start': 42, 'out': 51, 'screen': 'result'},
            ],
            'resolution': [51, 55],
            'end_card': [55, 60],
        },
        indent=2,
    )
)
bezel = Image.open(R / 'assets/apple/iphone18promax-silver.png').convert('RGBA')
capture = Image.open(R / 'assets/captures/result.png').convert('RGB')
card = capture.crop((60, 2095, 1260, 2440))
maskcache = {}


def rounded(im, r):
    im = im.convert('RGBA')
    m = Image.new('L', im.size)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=r, fill=255)
    im.putalpha(m)
    return im


def over(im, layer, xy, alpha=1, shadow=0):
    x, y = map(round, xy)
    layer = layer.convert('RGBA')
    if alpha < 1:
        layer.putalpha(layer.getchannel('A').point(lambda v: round(v * alpha)))
    if shadow:
        sh = Image.new('RGBA', im.size)
        sh.paste(
            (0, 0, 0, 55),
            (x + 15, y + 25, x + 15 + layer.width, y + 25 + layer.height),
            layer.getchannel('A'),
        )
        sh = sh.filter(ImageFilter.GaussianBlur(shadow))
        im.paste(sh, (0, 0), sh)
    im.paste(layer, (x, y), layer)


def phone(im, screen, x, y, h, alpha=1):
    z = h / 3000
    w = round(1470 * z)
    can = Image.new('RGBA', (w, round(h)))
    screen = rounded(
        screen.resize((round(1320 * z), round(2868 * z)), Image.Resampling.LANCZOS), round(145 * z)
    )
    can.paste(screen, (round(75 * z), round(66 * z)), screen)
    b = bezel.resize(can.size, Image.Resampling.LANCZOS)
    can.alpha_composite(b)
    over(im, can, (x, y), alpha)
