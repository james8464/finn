from pathlib import Path
import json,subprocess as sp,shutil
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';S=json.loads((K/'five-minute-scenes.json').read_text());FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
def run(a):sp.run(a,check=True,stdout=sp.DEVNULL,stderr=sp.PIPE)
segments=[]
for s in S:
 i=s['number'];p=K/f'build/refined-playback-{i:02}.mp4';segments.append(p)
 if i==1:shutil.copy2(R/'videos/finn-opening-film.mp4',p)
 else:run([FF,'-y','-i',str(K/f'media/{i:02}.mp4'),'-f','lavfi','-i','anullsrc=r=48000:cl=stereo','-map','0:v','-map','1:a','-c:v','copy','-c:a','aac','-b:a','128k','-t',str(s['seconds']),str(p)])
f=K/'build/refined-concat.txt';f.write_text(''.join("file '"+str(p)+"'\n" for p in segments));out=K/'output/Finn-WWDC-5min-Playback.mp4'
run([FF,'-y','-f','concat','-safe','0','-i',str(f),'-c:v','copy','-c:a','aac','-b:a','192k','-t','300','-movflags','+faststart',str(out)])
# Rehearsal and script links resolve to this revision, with the current notes.
src=Path('/tmp/finn_keynote_handoff.py').read_text().split("for source in")[0].replace('Finn-Five-Minutes.key','Finn-WWDC-5min.key').replace('Finn-Five-Minutes-Playback.mp4','Finn-WWDC-5min-Playback.mp4').replace('536 words of speaker notes','approximately 500 spoken words')
exec(src,{})
(K/'README.md').write_text('''# Finn · Five minutes\n\nOpen `output/Finn-WWDC-5min.key` in Keynote. Select slide 1 and press Play. Movies begin automatically. Advance slides on click as you speak; the slide timings in the presenter notes total exactly 5:00, including the opening film.\n\nFor automatic uninterrupted playback, use `output/Finn-WWDC-5min-Playback.mp4`. It lasts exactly five minutes. The first minute includes sound. The remaining four minutes leave space for your voice.\n\nThe native Keynote contains all media, so it works offline without linked files. Motion, app footage and outlined SF Pro typography are embedded as full-slide movies. The choreography cannot be edited as separate native Keynote builds. Presenter notes are editable.\n\nThe browser rehearsal and printable script are one folder above. `motion-direction.md` preserves the design rationale and timings.\n\nThe film uses previously generated human footage. Native UI crops supply the scripted posture cue. The Finn notification is a proposed experience. These sequences illustrate the product concept and do not establish detection accuracy. Technical claims describe the current implementation: Vision body pose, joint-angle rules, evidence gates, WatchConnectivity, and Foundation Models for grounded conversation.\n''')
for name in ['finn_revision5.py','finn_render_keynote_v5.py','finn_film_finn_notification.py','finn_embed_media.py','finn_finish_refined.py']:shutil.copy2('/tmp/'+name,R/'production/source'/name)
# Archive implementation now retains the actual launch capture rather than recopying an old preview.
p=R/'production/source/finn_five_min.py';p.write_text(p.read_text().replace("shutil.copy2('/tmp/finn-custom-motion-native.mp4',R/'videos/finn-launch-animation.mp4')","# Native launch capture already exported from FinnLogoMotionFrame.swift."))
run([FF,'-v','error','-i',str(out),'-f','null','-'])
print('Refined five-minute playback decoded successfully. Rehearsal, notes and handoff updated.',flush=True)
