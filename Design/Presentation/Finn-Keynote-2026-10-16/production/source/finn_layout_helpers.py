from pathlib import Path
import json, sys, re, math

sys.path.insert(0, '/tmp/finn-font-tools')
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from PIL import ImageFont, Image

R = Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16')
P = R / 'production'
A = {x['key']: x for x in json.loads((P / 'asset-manifest.json').read_text())}
H = {x['key']: x['result']['imageHash'] for x in json.loads((P / 'figma-assets.json').read_text())}
F = {}
counter = 0
INK = '#1D1D1F'
PINK = '#FF2D92'
WHITE = '#FFFFFF'
GRAY = '#86868B'


def anim(**kw):
    return {k: [[float(t), v] for t, v in vv] for k, vv in kw.items()}


def settle(delay=0, x=0, y=0, scale=1):
    d = {}
    if x:
        d['x'] = [[0, x], [delay, x], [delay + 1.2, 0]]
    if y:
        d['y'] = [[0, y], [delay, y], [delay + 1.2, 0]]
    if scale != 1:
        d['scale'] = [[0, scale], [delay, scale], [delay + 1.2, 1]]
    return d


def node(kind, name, x, y, w, h, **kw):
    global counter
    counter += 1
    return dict(kind=kind, name=name, key=f'n{counter}', x=x, y=y, w=w, h=h, **kw)


def txt(text, x, y, w, size=96, color=WHITE, style='Semibold', align='LEFT', motion=None):
    global F
    path = f'/Users/james/Library/Fonts/SF-Pro-Display-{style}.otf'
    if style not in F:
        f = TTFont(path)
        F[style] = (f, f.getGlyphSet(), f.getBestCmap(), f['head'].unitsPerEm)
    ft, gs, cm, upm = F[style]
    pf = ImageFont.truetype(path, round(size * 10))
    tr = -size * 0.025
    lh = size * 1.05

    def length(s):
        return pf.getlength(s) / 10 + max(0, len(s) - 1) * tr

    lines = []
    for hard in text.split('\n'):
        l = ''
        for word in hard.split(' '):
            z = (l + ' ' + word) if l else word
            if l and length(z) > w:
                lines.append(l)
                l = word
            else:
                l = z
        lines.append(l)
    pen = SVGPathPen(gs)
    scale = size / upm
    base = (lh + ft['OS/2'].sCapHeight * scale) / 2
    for j, l in enumerate(lines):
        xx = (w - length(l)) / 2 if align == 'CENTER' else 0
        for i, ch in enumerate(l):
            gl = gs.get(cm.get(ord(ch), 'space'))
            if gl:
                gl.draw(TransformPen(pen, (scale, 0, 0, -scale, xx, base + j * lh)))
            adv = pf.getlength(ch) / 10
            if i + 1 < len(l):
                adv += (pf.getlength(ch + l[i + 1]) - pf.getlength(ch) - pf.getlength(l[i + 1])) / 10
            xx += adv + tr
    h = math.ceil(lh * len(lines))
    d = re.sub(r'-?\d+\.\d+', lambda m: format(float(m[0]), '.3f').rstrip('0').rstrip('.'), pen.getCommands())
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><path fill="{color}" d="{d}"/></svg>'
    return node(
        'text', text, x, y, w, h, text=text, size=size, color=color, style=style, svg=svg, motion=motion or {}
    )


def group(name, x, y, w, h, children, motion=None, clip=False, radius=0, bg=None):
    return node(
        'group', name, x, y, w, h, children=children, motion=motion or {}, clip=clip, radius=radius, bg=bg
    )


def pic(key, x, y, w, h, video=None):
    return node('image', key, x, y, w, h, src=A[key]['path'], hash=H[key], video=video)


def phone(key, x, y, h=900, video=None, motion=None, watch=False):
    asset = A['watch' if watch else 'iphone']
    ow, oh = asset['size']
    z = h / oh
    g = asset['screen']
    screen = pic(key, g[0] * z, g[1] * z, g[2] * z, g[3] * z, video)
    screen['radius'] = (92 if watch else 145) * z
    return group(
        'Apple Watch' if watch else 'iPhone',
        x,
        y,
        ow * z,
        h,
        [screen, pic('watch' if watch else 'iphone', 0, 0, ow * z, h)],
        motion=motion,
    )


def crop(key, box, x, y, w, video=None, motion=None, radius=30):
    sx, sy, sw, sh = box
    z = w / sw
    ow, oh = A[key]['size']
    n = pic(key, -sx * z, -sy * z, ow * z, oh * z, video)
    return group('UI detail · ' + key, x, y, w, sh * z, [n], motion=motion, clip=True, radius=radius)


def label(t, x, y, w=900, color=GRAY):
    return txt(t, x, y, w, 27, color, 'Regular')


def line(x, y, w, color=PINK, motion=None):
    return node('rect', 'Signal', x, y, w, 3, color=color, motion=motion or {})


def stack(name, x, y, items, gap=12):
    yy = 0
    for n in items:
        n['x'] = 0
        n['y'] = yy
        yy += n['h'] + gap
    n = group(name, x, y, max(n['w'] for n in items), yy - gap, items)
    n['layout'] = 'VERTICAL'
    n['gap'] = gap
    return n
