from pathlib import Path
from PIL import Image
import json, subprocess as sp

R = Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16')
K = R / 'keynote'
D = K / 'build/smooth-native'
D.mkdir(exist_ok=True)
FF = '/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'


def run(a):
    sp.run(a, check=True, stdout=sp.PIPE, stderr=sp.PIPE)


plates = D / 'plates'
plates.mkdir(exist_ok=True)
run(
    [
        FF,
        '-y',
        '-i',
        '/tmp/finn-keynote-portrait.mp4',
        '-vf',
        'fps=24,scale=660:1335',
        '-q:v',
        '2',
        str(plates / '%04d.jpg'),
    ]
)
# Use measured Vision observations, interpolated only for presentation drawing. No new detection claim.
raw = json.loads(Path('/tmp/finn-keynote-portrait-poses.json').read_text())
for f in raw:
    f['joints'] = {f['joints'][i]: f['joints'][i + 1] for i in range(0, len(f['joints']), 2)}
# Three-sample symmetric filter removes tracker noise without temporal lag.
filtered = []
for i, f in enumerate(raw):
    d = {}
    for name, v in f['joints'].items():
        samples = [
            (raw[j]['joints'].get(name, v), w)
            for j, w in [(max(0, i - 1), 0.2), (i, 0.6), (min(len(raw) - 1, i + 1), 0.2)]
        ]
        d[name] = {k: sum(a[k] * w for a, w in samples) for k in ['x', 'y', 'confidence']}
    filtered.append(dict(time=f['time'], joints=d))
(D / 'poses.json').write_text(json.dumps(filtered))
# Native status bar and the actual iOS stop control are preserved as captured assets.
a = Image.open(R / 'assets/captures/live.png').convert('RGBA')
bar = a.crop((0, 0, 1320, 180))
bar.putalpha(bar.convert('RGB').point(lambda x: x).convert('L').point(lambda v: 255 if v > 20 else 0))
bar.save(D / 'status.png')
b = a.crop((360, 2328, 960, 2514))
mask = Image.new('L', b.size)
from PIL import ImageDraw

ImageDraw.Draw(mask).rounded_rectangle((0, 0, 599, 185), 92, fill=255)
b.putalpha(mask)
b.save(D / 'stop.png')
# Retain the production app's painter verbatim.
source = Path('/Users/james/Developer/Hackathon/Finn/Finn/Capture/CameraFeedView.swift').read_text()
painter = source[
    source.index('enum SkeletonPainter {') : source.index('/// shows the frames the analysis receives')
]
(D / 'Painter.swift').write_text('import SwiftUI\n' + painter)
print('Continuous source frames and native UI assets prepared')
