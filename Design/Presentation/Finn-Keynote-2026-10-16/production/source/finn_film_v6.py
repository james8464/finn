from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,math,sys,subprocess as sp,numpy as np,wave
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';D=K/'build/smooth-native';P=R/'production/film';FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
# Reuse verified compositing helpers and official device artwork, never the old cut sequence.
script=Path('/tmp/finn_film_v3.py').read_text().split("\nif '--stills' in sys.argv:")[0].replace("R/'assets/apple/reminders-icon.png'","R/'assets/captures/finn-app-icon.png'").replace("text(bg,'Reminders'","text(bg,'Finn'")
exec(script)
files['smooth-live']=sorted((D/'live').glob('*.png'))[24:-1];files['smooth-setup']=sorted((D/'setup').glob('*.png'))[24:-1]
segments=[dict(start=0,out=8,source='morning',source_in=0,speed=1.25,source_out=10),dict(start=8,out=18,source='office',source_in=0,speed=1,source_out=10),dict(start=18,out=22,source='workout',source_in=0,speed=1,source_out=4),dict(start=26,out=29.041667,source='workout',source_in=5,speed=1,source_out=8.041667),dict(start=51,out=55,source='workout',source_in=8.083333,speed=.47,source_out=9.963333)]
# Each original frame belongs to one moving shot only. Device footage follows the same workout once.
for key in ['morning','office','workout']:
 a=[x for x in segments if x['source']==key]
 for x,y in zip(a,a[1:]):assert x['source_out']<=y['source_in']+.000001
(P/'edit-decision-list-v6.json').write_text(json.dumps({'duration':60,'fps':24,'segments':segments,'no_reused_moving_source_ranges':True,'product_camera':{'source':'workout','source_range':[5,8.041667],'film_range':[26,29.041667],'after':'Hold last frame during cue extraction and Watch handoff. No replay.'}},indent=2))
def render(t):
 if t<22:
  e=next(e for e in segments[:3] if e['start']<=t<e['out']);im=fit(source(e['source'],e['source_in']+(t-e['start'])*e['speed']),1.035 if e['source']=='workout' else 1)
  if 13.1<=t<15.15:notification(im,15.65+t-13.1)
  return im
 if t<26:
  u=t-22;p=ease(u/1.2);im=Image.new('RGB',SIZE);phone(im,source('smooth-setup',0),1100-60*p,75,930)
  text(im,'Make room.',(130,300),125,opacity=p);text(im,'For your next set.',(135,510),74,bold=False,opacity=ease((u-.8)/1))
  return im
 if t<38:
  u=t-26;p=ease(u/1.2);im=Image.new('RGB',SIZE);screen=source('smooth-live',min(u,4.04)).resize((1320,2868),Image.Resampling.LANCZOS)
  if u>2.1:
   q=ease((u-2.1)/.55);layer=rounded(cue.resize((1176,230),Image.Resampling.LANCZOS),50);over(screen,layer,(72,645),q)
  phone(im,screen,195+845*(1-p),75,930)
  text(im,'A small adjustment.',(790,230),103,opacity=ease((u-1)/.7))
  q=ease((u-4.2)/1.8);tip(im,(790-480*(1-q),475-170*(1-q)),870-500*(1-q),q)
  text(im,'For a better next rep.',(800,745),58,bold=False,opacity=ease((u-6.2)/1))
  text(im,'ILLUSTRATIVE COACHING SEQUENCE',(800,975),23,(145,145,150),False,opacity=ease(u-1));return im
 if t<45:
  u=t-38;p=ease(u/1.45);im=Image.new('RGB',SIZE)
  screen=source('smooth-live',4.04).resize((1320,2868),Image.Resampling.LANCZOS);layer=rounded(cue.resize((1176,230),Image.Resampling.LANCZOS),50);over(screen,layer,(72,645))
  phone(im,screen,195-90*p,75+170*p,930-200*p)
  if u<1.7:tip(im,(790+285*p,475-30*p),870-520*p,1-p)
  watch(im,watch_screen,1230-190*p,210-160*p,760+170*p,p)
  text(im,'On your',(600,170),86,opacity=ease((u-.9)/.9));text(im,'wrist.',(600,285),112,opacity=ease((u-1.1)/.9))
  text(im,'One clear cue.',(600,795),62,bold=False,opacity=ease((u-1.8)/.8));text(im,'SCRIPTED COMPANION DEMONSTRATION',(600,975),23,(145,145,150),False,opacity=p);return im
 if t<51:
  u=t-45;p=ease(u/1.2);im=Image.new('RGB',SIZE,(245,245,247));phone(im,posture,1205-110*p,120,920)
  text(im,'Take it into',(130,270),105,(29,29,31),opacity=p);text(im,'your next rep.',(130,405),105,(29,29,31),opacity=ease((u-.35)/1));text(im,'ACTUAL POSTURE GUIDE',(135,975),23,(120,120,126),False,opacity=p);return im
 if t<55:
  im=fit(source('workout',8.083333+(t-51)*.47),1.035);text(im,'A little time.',(130,730),88,opacity=ease((t-51)/.6));text(im,'A clearer next step.',(130,840),88,opacity=ease((t-52)/.7))
  if t>54.5:im=Image.blend(im,Image.new('RGB',SIZE),ease((t-54.5)/.5))
  return im
 im=Image.new('RGB',SIZE);u=t-55;text(im,'Finn',(960,330),250,center=True,opacity=ease(u/.8));text(im,'Stronger starts together',(960,650),68,center=True,bold=False,opacity=ease((u-.7)/.9));return im
if '--stills' in sys.argv:
 times=[.4,1.3,2.2,4.3,7.4,8.8,11.3,13.8,16,19,23.7,27.6,29.7,33.7,40.8,47,52.5,57.7];sheet=Image.new('RGB',(1440,math.ceil(len(times)/3)*270),'#222')
 for i,t in enumerate(times):
  im=render(t);im.save(K/f'preview/film-v6-{t:04.1f}.jpg',quality=94);im=im.resize((480,270));ImageDraw.Draw(im).text((8,8),str(t)+'s',fill='white',font=ImageFont.truetype(REG,18));sheet.paste(im,(i%3*480,i//3*270))
 sheet.save(P/'film-storyboard-v6.jpg',quality=92);print('V6 unique-shot storyboard ready');sys.exit()
if '--audio' in sys.argv:
 SR=48000;N=60*SR;audio=np.zeros((N,2),np.float32);sfx=np.zeros_like(audio);rng=np.random.default_rng(20261016)
 def place(a,st,gain):
  ix=round(st*SR);n=min(len(a),N-ix)
  if n>0:audio[ix:ix+n]+=a[:n]*gain
 for e in segments:
  raw=sp.check_output([FF,'-v','error','-i',str(paths[e['source']]),'-f','f32le','-ar',str(SR),'-ac','2','-']);a=np.frombuffer(raw,dtype='<f4').reshape(-1,2);n=round((e['out']-e['start'])*SR);ix=np.minimum(len(a)-1,(e['source_in']*SR+np.arange(n)*e['speed']).astype(int));b=a[ix].copy();fade=min(960,n//4);b[:fade]*=np.linspace(0,1,fade)[:,None];b[-fade:]*=np.linspace(1,0,fade)[:,None];place(b,e['start'],.25)
 with wave.open(str(P/'original-score.wav')) as f:score=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,2)/32767
 score=score[:N].copy();score[int(12.7*SR):int(15.4*SR)]*=.15;place(score,0,1)
 for st,freq in [(13.1,659.25),(13.26,987.77)]:
  t=np.arange(int(.7*SR))/SR;v=(np.sin(2*np.pi*freq*t)+.2*np.sin(4*np.pi*freq*t))*(1-np.exp(-t*180))*np.exp(-t/.17)*np.minimum(1,(.7-t)/.08);place(np.stack((v,v),axis=1),st,.08)
 for st in [30.2,38]:
  n=int(.5*SR);v=np.convolve(rng.normal(0,1,n),np.ones(80)/80,mode='same')*np.sin(np.linspace(0,np.pi,n))**2;place(np.stack((v,v),axis=1),st,.09)
 audio=np.tanh(audio*.9);audio*=np.minimum(1,(N-1-np.arange(N))/SR/1.2)[:,None]
 with wave.open(str(P/'mix-v6.wav'),'w') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
 print('V6 synchronized score and native notification accent ready');sys.exit()
out=K/'build/film-v6-picture.mp4';pr=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',str(out)],stdin=sp.PIPE)
for i in range(1440):
 pr.stdin.write(render(i/24).tobytes())
 if i%240==0:print(str(i//24)+'/60 seconds',flush=True)
pr.stdin.close();assert pr.wait()==0
run([FF,'-y','-i',str(out),'-i',str(P/'mix-v6.wav'),'-map','0:v','-map','1:a','-c:v','copy','-af','loudnorm=I=-16:TP=-1.5:LRA=9','-c:a','aac','-b:a','256k','-ar','48000','-t','60','-movflags','+faststart',str(R/'videos/finn-opening-film.mp4')]);print('V6 film ready',flush=True)
