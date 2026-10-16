"""Add native Progress choreography to the last ten seconds of the Watch scene.

Uses the current app's isolated ProgressDemo fixture, recorded manually in Device Hub.
Only typography and Apple bezel placement are composited; chart animation is native.
"""
from pathlib import Path
import html
import json
import re
import shutil
import subprocess as sp
import zipfile
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageFont

R = Path(__file__).resolve().parents[2]
K = R / 'keynote'
D = K / 'build/progress'
D.mkdir(parents=True, exist_ok=True)
FF = '/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
INPUT = R / 'production/source-inputs/progress/native-capture.mp4'
FPS = 30

def run(args):
    sp.run([FF, '-y', '-v', 'error', *map(str, args)], check=True)

def extract(name, start, duration):
    folder = D / name
    folder.mkdir(exist_ok=True)
    run(['-ss', start, '-i', INPUT, '-t', duration, '-vf', f'fps={FPS},scale=440:956', '-q:v', 2, folder / '%04d.jpg'])
    return [Image.open(p).convert('RGBA') for p in sorted(folder.glob('*.jpg'))]

history = extract('history', 32.35, 1.4)
projection = extract('projection', 17.35, 2.2)
bezel = Image.open(R / 'assets/apple/iphone18promax-silver.png').convert('RGBA').resize((490, 1000), Image.Resampling.LANCZOS)
mask = Image.new('L', (440, 956))
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 439, 955), 48, fill=255)

def ease(t):
    t = max(0, min(1, t))
    return 1 - (1 - t) ** 4

def text(s, size, colour, width=1000, weight='Semibold'):
    font = ImageFont.truetype(f'/Users/james/Library/Fonts/SF-Pro-Display-{weight}.otf', size)
    lines = s.split('\n')
    image = Image.new('RGBA', (width, round(size * 1.12 * len(lines))), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for i, line in enumerate(lines):
        draw.text((0, i * size * 1.12), line, font=font, fill=colour, anchor='lt', stroke_width=0)
    return image

title = text('Progress\nyou can see', 112, 'white')
saved = text('Latest best set', 42, '#86868B', weight='Regular')
latest = text('11 reps', 108, 'white')
ahead = text('Looking ahead', 76, 'white')
estimate = text('An estimate', 42, '#86868B', weight='Regular')
disclosure = text('Illustrative workout history', 24, '#86868B', weight='Regular')

def overlay(canvas, image, xy, opacity=1):
    if opacity <= 0:
        return
    layer = image.copy()
    if opacity < 1:
        layer.putalpha(layer.getchannel('A').point(lambda a: round(a * opacity)))
    canvas.alpha_composite(layer, xy)

def frame(t):
    image = Image.new('RGBA', (1920, 1080), 'black')
    # The phone remains fixed. History grows natively, then the app's Project action resolves.
    if t < 4.7:
        source = history[min(len(history) - 1, max(0, int((t - .55) * FPS)))]
    else:
        source = projection[min(len(projection) - 1, max(0, int((t - 4.7) * FPS)))]
    screen = source.copy()
    screen.putalpha(mask)
    image.alpha_composite(screen, (1220, 72))
    image.alpha_composite(bezel, (1195, 50))
    overlay(image, title, (140, 270))
    q = ease((t - 4.6) / .45)
    overlay(image, saved, (145, 555), 1 - q)
    overlay(image, latest, (140, 620), ease((t - 1.7) / .55) * (1 - q))
    overlay(image, ahead, (140, 590), q)
    overlay(image, estimate, (145, 700), q)
    overlay(image, disclosure, (145, 970))
    return image.convert('RGB')

movie = D / 'progress.mp4'
writer = sp.Popen([FF, '-y', '-v', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1920x1080', '-r', str(FPS), '-i', '-', '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(movie)], stdin=sp.PIPE)
for i in range(315):
    writer.stdin.write(frame(i / FPS).tobytes())
writer.stdin.close()
assert writer.wait() == 0
for t in [0, 1, 2.5, 5.5, 7.5, 10]:
    frame(t).save(D / f'progress-{t:04.1f}.jpg', quality=94)

# Preserve the first 19.5 seconds and the complete phone-to-Watch cue hand-off.
old = K / 'media/07.mp4'
combined = D / '07.mp4'
run(['-i', R / 'production/source-inputs/progress/watch-prefix.mp4', '-i', movie, '-filter_complex', '[0:v]trim=duration=20,setpts=PTS-STARTPTS,fps=30,format=yuv420p[a];[1:v]setpts=PTS-STARTPTS,fps=30,format=yuv420p[b];[a][b]xfade=transition=fade:duration=0.5:offset=19.5[v]', '-map', '[v]', '-an', '-t', 30, '-c:v', 'libx264', '-preset', 'fast', '-crf', 18, '-pix_fmt', 'yuv420p', '-movflags', '+faststart', combined])
shutil.copy2(combined, old)
shutil.copy2(D / 'progress-02.5.jpg', K / 'preview/07-progress.jpg')

plan_path = K / 'five-minute-scenes.json'
scenes = json.loads(plan_path.read_text())
scene = scenes[6]
old_notes = scene['notes']
scene['title'] = 'On your wrist. In your progress.'
scene['notes'] = "3:05–3:35. The same cue comes to your Apple Watch, while your iPhone performs the camera analysis. WatchConnectivity keeps the set and short guidance in sync. [At 20 seconds, Progress.] Your saved sets build a history. Here the latest best set is eleven reps. Project looks ahead from that history. It is an estimate, not a promise. These are illustrative workouts in the current native app, not a participant study."
scene['follow_on'] = {'at_seconds': 19.5, 'duration_seconds': 10.5, 'source': 'production/source-inputs/progress/native-capture.mp4', 'renderer': 'production/source/finn_progress_walkthrough.py', 'fixture': 'Finn/Finn/Progress/ProgressDemo.swift', 'history_source_seconds': [32.35, 33.75], 'projection_source_seconds': [17.35, 19.55], 'latest_saved_best_set_reps': 11, 'projection_two_weeks_reps': 13, 'notes': 'Current app UI and native Charts animation. Saved solid bars precede faint projected bars. No product UI is redrawn.'}
assert sum(s['seconds'] for s in scenes) == 300
plan_path.write_text(json.dumps(scenes, ensure_ascii=False))

# Patch the existing portable deck in place, retaining all other package parts and layouts.
deck = K / 'output/Finn-WWDC-5min-Polished.pptx'
candidate = D / deck.name
P = 'http://schemas.openxmlformats.org/presentationml/2006/main'
A = 'http://schemas.openxmlformats.org/drawingml/2006/main'
with zipfile.ZipFile(deck) as src, zipfile.ZipFile(candidate, 'w', zipfile.ZIP_DEFLATED) as dst:
    for item in src.infolist():
        data = src.read(item.filename)
        if item.filename == 'ppt/media/motion-07.mp4':
            data = old.read_bytes()
        elif re.fullmatch(r'ppt/notesSlides/notesSlide\d+\.xml', item.filename):
            note_index = int(re.search(r'notesSlide(\d+)', item.filename)[1]) - 1
            root = ET.fromstring(data)
            for shape in root.findall(f'.//{{{P}}}sp'):
                placeholder = shape.find(f'.//{{{P}}}ph')
                if placeholder is not None and placeholder.get('type') == 'body':
                    body = shape.find(f'{{{P}}}txBody')
                    for para in list(body.findall(f'{{{A}}}p')):
                        body.remove(para)
                    para = ET.SubElement(body, f'{{{A}}}p')
                    run_node = ET.SubElement(para, f'{{{A}}}r')
                    ET.SubElement(run_node, f'{{{A}}}t').text = scenes[note_index]['notes']
            data = ET.tostring(root, encoding='utf-8', xml_declaration=True)
        dst.writestr(item, data)
shutil.copy2(candidate, deck)

# Update the rehearsal's embedded scene data and the printable spoken script.
page = R / 'index.html'
page_text = page.read_text()
start = page_text.index('const scenes=') + len('const scenes=')
_, end = json.JSONDecoder().raw_decode(page_text[start:])
page.write_text(page_text[:start] + json.dumps(scenes, ensure_ascii=False) + page_text[start + end:])
script = R / 'speaker-notes.html'
script.write_text(script.read_text().replace(html.escape(old_notes), html.escape(scene['notes'])).replace('<h2>Right on your wrist</h2>', '<h2>On your wrist. In your progress.</h2>'))

# Patch only scene 7 of the uninterrupted backup and retain the existing soundtrack.
backup = K / 'output/Finn-WWDC-5min-Playback.mp4'
playback = D / backup.name
run(['-i', backup, '-i', old, '-filter_complex', '[0:v]trim=end=185,setpts=PTS-STARTPTS,fps=30[a];[1:v]setpts=PTS-STARTPTS,fps=30[b];[0:v]trim=start=215,setpts=PTS-STARTPTS,fps=30[c];[a][b][c]concat=n=3:v=1:a=0[v]', '-map', '[v]', '-map', '0:a', '-c:v', 'libx264', '-preset', 'fast', '-crf', 18, '-c:a', 'aac', '-b:a', '192k', '-af', 'atrim=duration=300', '-t', 300, '-movflags', '+faststart', playback])
shutil.copy2(playback, backup)
print('Progress walkthrough added: 10 scenes, 300 seconds. Replace scene 7 movie in native Keynote.', flush=True)
