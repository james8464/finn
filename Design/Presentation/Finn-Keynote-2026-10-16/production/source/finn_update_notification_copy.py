from pathlib import Path
from PIL import Image
import subprocess as sp, os, json, zipfile, shutil

R = Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16')
K = R / 'keynote'
FF = '/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
D = Path('/tmp/finn-notification-edit')
D.mkdir(exist_ok=True)
asset = Image.open(R / 'assets/apple/finn-notification-official.png').convert('RGBA')
asset = asset.resize((820, round(asset.height * 820 / asset.width)), Image.Resampling.LANCZOS)
rd = sp.Popen(
    [
        FF,
        '-v',
        'error',
        '-ss',
        '5.125',
        '-i',
        str(R / 'assets/film/office-source.mp4'),
        '-vf',
        'fps=24,scale=1920:1080',
        '-frames:v',
        '49',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        '-',
    ],
    stdout=sp.PIPE,
)
wr = sp.Popen(
    [
        FF,
        '-y',
        '-v',
        'error',
        '-f',
        'rawvideo',
        '-pix_fmt',
        'rgb24',
        '-s',
        '1920x1080',
        '-r',
        '24',
        '-i',
        '-',
        '-an',
        '-c:v',
        'libx264',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        str(D / 'patch.mp4'),
    ],
    stdin=sp.PIPE,
)
for j in range(49):
    data = rd.stdout.read(1920 * 1080 * 3)
    assert len(data) == 1920 * 1080 * 3
    im = Image.frombytes('RGB', (1920, 1080), data)
    t = (315 + j) / 24
    p = 1 - (1 - max(0, min(1, (t - 13.1) / 0.55))) ** 4
    lay = asset.copy()
    lay.putalpha(lay.getchannel('A').point(lambda a: round(a * p)))
    im.paste(lay, (round(1025 + 70 * (1 - p)), round(250 - 45 * (1 - p))), lay)
    if j == 16:
        im.save(K / 'preview/notification-updated.jpg', quality=94)
    wr.stdin.write(im.tobytes())
wr.stdin.close()
assert wr.wait() == 0
assert rd.wait() == 0
film = R / 'videos/finn-opening-film.mp4'
out = D / 'film.mp4'
sp.run(
    [
        FF,
        '-y',
        '-v',
        'error',
        '-i',
        str(film),
        '-i',
        str(D / 'patch.mp4'),
        '-filter_complex',
        '[0:v]trim=end_frame=315,setpts=PTS-STARTPTS[a];[1:v]setpts=PTS-STARTPTS[b];[0:v]trim=start_frame=364,setpts=PTS-STARTPTS[c];[a][b][c]concat=n=3:v=1:a=0[v]',
        '-map',
        '[v]',
        '-map',
        '0:a',
        '-c:v',
        'libx264',
        '-preset',
        'fast',
        '-crf',
        '18',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'copy',
        '-movflags',
        '+faststart',
        str(out),
    ],
    check=True,
)
shutil.copy2(out, film)
# Preserve full playback timing/audio; replace its first minute from the revised film.
print('Opening film updated. Replace its movie in Finn — Stronger Starts Together.key.', flush=True)
