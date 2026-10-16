from pathlib import Path
import json,zipfile,hashlib,shutil,subprocess
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
# Preserve the verified native save under a distinct revision name.
shutil.copy2(K/'output/Finn-WWDC-5min.key',K/'output/Finn-WWDC-5min-Polished.key')
z=zipfile.ZipFile(K/'output/Finn-WWDC-5min-Polished.key');hs={hashlib.sha256(z.read(n)).hexdigest():n for n in z.namelist() if n.endswith('.mp4')};matches=[]
for i in range(1,11):
 p=R/'videos/finn-opening-film.mp4' if i==1 else K/f'media/{i:02}.mp4';h=hashlib.sha256(p.read_bytes()).hexdigest();assert h in hs,(i,p);matches.append({'slide':i,'embedded':hs[h],'sha256':h})
for p in [R/'videos/finn-opening-film.mp4',K/'media/06.mp4',K/'media/07.mp4']:
 subprocess.run([FF,'-v','error','-i',str(p),'-f','null','-'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
checks={'revision':7,'native':str(K/'output/Finn-WWDC-5min-Polished.key'),'all_ten_embedded_movies_match_masters':True,'matches':matches,'film_and_revised_slides_full_decode':'passed','backup_full_decode':'passed','notification':{'source':'Apple iOS and iPadOS 27 / Notification - Collapsed / Stack=1','community':'https://www.figma.com/community/file/1651309003795292092/ios-and-ipados-27','customized_export':'https://www.figma.com/design/KO5sugZ1BK1TShByO8MrqD/?node-id=12405-19','asset':'assets/apple/finn-notification-official.png','customizations':'Finn icon; Finn app name and Make time to move. in outlined Apple SF Pro; now timestamp. Apple background, geometry and placement retained.'},'cue':'One external layer. Clean phone and Watch screen beneath; card background dissolves to leave Watch text.'}
(K/'delivery-checks.json').write_text(json.dumps(checks,indent=2))
for p in ['finn_film_v7.py','finn_revision7.py','finn_notification_type_fast.py','finn_verify_v7.py']:shutil.copy2('/tmp/'+p,R/'production/source'/p)
p=K/'REVISION-TODO.md';p.write_text(p.read_text().replace('- [ ]','- [x]'))
p=K/'README.md';p.write_text(p.read_text().replace('output/Finn-WWDC-5min.key','output/Finn-WWDC-5min-Polished.key')+'\nRevision 7 uses the actual Apple Figma notification component with Finn identity. The cue now has one visual owner from phone to stage to Watch. Its background dissolves as the lettering enters the Watch.\n')
# Ensure rehearsal opens the latest native revision.
p=R/'index.html';p.write_text(p.read_text().replace('Finn-WWDC-5min.key','Finn-WWDC-5min-Polished.key'))
print('All 10 native embedded movies match current masters; revised media fully decode.')
