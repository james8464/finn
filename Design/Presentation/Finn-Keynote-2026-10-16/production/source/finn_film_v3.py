from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import json,math,subprocess as sp,sys
# Keep the established human edit and original score; rebuild the product film.
exec(Path('/tmp/finn_film.py').read_text().split("if '--stills' in sys.argv:")[0])
old_render=render
V=P/'render-v3';V.mkdir(exist_ok=True)
for key,path in [('native-live',R/'videos/live.mp4')]:
 d=V/key;d.mkdir(exist_ok=True)
 if not (d/'0001.jpg').exists():run([FF,'-y','-i',str(path),'-vf','fps=24','-q:v','2',str(d/'%04d.jpg')])
 files[key]=sorted(d.glob('*.jpg'));assert files[key]
watch_bezel=Image.open(R/'assets/apple/watch11-black.png').convert('RGBA')
watch_screen=Image.open(R/'assets/captures/watch-coach.png').convert('RGB')
posture=Image.open(R/'assets/captures/posture.png').convert('RGB')
cue=Image.open('/tmp/finn-clean-posture-tip.png').convert('RGB').crop((72,645,1248,875))
reminders=Image.open(R/'assets/apple/reminders-icon.png').convert('RGBA')
cache={}
def phone(im,screen,x,y,h,alpha=1):
 z=h/3000;wh=(round(1470*z),round(h));can=Image.new('RGBA',wh);sc=rounded(screen.resize((round(1320*z),round(2868*z)),Image.Resampling.LANCZOS),round(145*z));can.paste(sc,(round(75*z),round(66*z)),sc)
 if wh not in cache:cache[wh]=bezel.resize(wh,Image.Resampling.LANCZOS)
 can.alpha_composite(cache[wh]);over(im,can,(x,y),alpha)
def watch(im,screen,x,y,h,alpha=1):
 z=h/880;wh=(round(560*z),round(h));can=Image.new('RGBA',wh);sc=rounded(screen.resize((round(416*z),round(496*z)),Image.Resampling.LANCZOS),round(92*z));can.paste(sc,(round(72*z),round(192*z)),sc)
 key=('watch',wh)
 if key not in cache:cache[key]=watch_bezel.resize(wh,Image.Resampling.LANCZOS)
 can.alpha_composite(cache[key]);over(im,can,(x,y),alpha)
def notification(im,t):
 p=ease((t-15.65)/.55);w,h=760,204;x,y=round(1055+70*(1-p)),round(270-45*(1-p));bg=im.crop((x,y,x+w,y+h)).filter(ImageFilter.GaussianBlur(22)).convert('RGBA');white=Image.new('RGBA',(w,h),(250,250,252,228));bg=Image.alpha_composite(bg,white)
 d=ImageDraw.Draw(bg);d.rounded_rectangle((1,1,w-2,h-2),38,outline=(255,255,255,165),width=2)
 icon=reminders.resize((82,82),Image.Resampling.LANCZOS);bg.alpha_composite(icon,(26,30));text(bg,'Reminders',(130,27),30,(80,80,86),False);text(bg,'now',(652,29),27,(115,115,120),False)
 text(bg,'Make time to move',(130,79),39,(29,29,31));text(bg,'One set. A little time for yourself.',(130,132),31,(49,49,54),False)
 bg=rounded(bg,38);over(im,bg,(x,y),p,20)
def tip(im,xy,w,alpha=1):
 lay=rounded(cue.resize((round(w),round(cue.height*w/cue.width)),Image.Resampling.LANCZOS),round(w*.035));over(im,lay,xy,alpha,14)
def render(t):
 if t<30:
  e=next(e for e in edl if e['start']<=t<e['out']);im=fit(source(e['source'],e['source_in']+(t-e['start'])*e['speed']),e['zoom']*(1.035 if e['source']=='workout' else 1),e['cx'],e['cy'])
  if 15.65<=t<18.25:notification(im,t)
  return im
 if t<38:
  u=t-30;p=ease(u/1.2);im=Image.new('RGB',SIZE);screen=source('native-live',max(0,min(u,4.5))).resize((1320,2868),Image.Resampling.LANCZOS)
  # The short coaching line is an illustrative product composite, not a finding on this actor.
  if u>2.1:
   q=ease((u-2.1)/.55);layer=rounded(cue.resize((1176,230),Image.Resampling.LANCZOS),50);over(screen,layer,(72,645),q)
  phone(im,screen,195+75*(1-p),75+65*(1-p),930)
  text(im,'A small adjustment.',(790,230),103,opacity=p)
  q=ease((u-2.8)/1.0);tip(im,(790,475+45*(1-q)),870,q)
  text(im,'For a better next rep.',(800,745),58,bold=False,opacity=ease((u-4.2)/1.0))
  text(im,'ILLUSTRATIVE COACHING SEQUENCE',(800,975),23,(145,145,150),False,opacity=ease(u-1));return im
 if t<45:
  u=t-38;p=ease(u/1.45);im=Image.new('RGB',SIZE)
  # Shared phone position and cue hand-off to the wrist, with a quiet pacing pulse.
  phone(im,source('native-live',min(4.5,max(0,u))),195-90*p,75+170*p,930-200*p)
  if u<1.7:tip(im,(790+285*p,475-30*p),870-520*p,1-p)
  watch(im,watch_screen,1230-190*p,210-160*p,760+170*p,p)
  text(im,'On your',(600,170),86,opacity=ease((u-.9)/.9));text(im,'wrist.',(600,285),112,opacity=ease((u-1.1)/.9))
  text(im,'One clear cue.',(600,795),62,bold=False,opacity=ease((u-1.8)/.8))
  text(im,'SCRIPTED COMPANION DEMONSTRATION',(600,975),23,(145,145,150),False,opacity=p);return im
 if t<51:
  u=t-45;p=ease(u/1.2);im=Image.new('RGB',SIZE,(245,245,247));phone(im,posture,1205-110*p,120,920)
  text(im,'Take it into',(130,270),105,(29,29,31),opacity=p);text(im,'your next rep.',(130,405),105,(29,29,31),opacity=ease((u-.35)/1))
  text(im,'Clear guidance. A useful next step.',(135,700),48,(105,105,111),False,opacity=ease((u-1)/.8))
  text(im,'ACTUAL POSTURE GUIDE',(135,975),23,(120,120,126),False,opacity=p);return im
 return old_render(t)

if '--stills' in sys.argv:
 times=[.3,8.8,12.9,16.7,20.2,24.8,29,31.5,34.8,39.7,42.5,47.8,52.3,57.5];sheet=Image.new('RGB',(1280,math.ceil(len(times)/2)*360),'#222')
 for i,t in enumerate(times):
  im=render(t);im.save(V/f'proof-{t:05.1f}.jpg',quality=94);shot=im.resize((640,360));ImageDraw.Draw(shot).text((12,10),f'{t:.1f}s',font=ImageFont.truetype(REG,20),fill='white');sheet.paste(shot,(i%2*640,i//2*360))
 sheet.save(P/'film-storyboard-v3.jpg',quality=92);render(34.8).save(P/'film-poster-v3.jpg',quality=95);print('V3 storyboard ready');sys.exit()
if '--audio' in sys.argv:
 # Source room tone + original score and restrained accents. No licensed tracks.
 SR=48000;N=60*SR;audio=np.zeros((N,2),np.float32);music=np.zeros_like(audio);sfx=np.zeros_like(audio);rng=np.random.default_rng(20261016)
 source_audio={}
 for k in ['morning','office','workout']:
  raw=sp.check_output([FF,'-v','error','-i',str(paths[k]),'-f','f32le','-ar',str(SR),'-ac','2','-']);source_audio[k]=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
 def place(dst,a,t,gain=1):
  start=round(t*SR);end=min(N,start+len(a));
  if end>start:dst[start:end]+=a[:end-start]*gain
 for e in edl:
  n=round((e['out']-e['start'])*SR);ix=np.minimum(len(source_audio[e['source']])-1,(e['source_in']*SR+np.arange(n)*e['speed']).astype(int));a=source_audio[e['source']][ix].copy();fade=min(960,n//4);a[:fade]*=np.linspace(0,1,fade)[:,None];a[-fade:]*=np.linspace(1,0,fade)[:,None];place(audio,a,e['start'],.35)
 a=source_audio['workout'][np.minimum(len(source_audio['workout'])-1,(8*SR+np.arange(4*SR)*.49).astype(int))].copy();place(audio,a,51,.3)
 def tone(freq,dur,decay=.8,kind='bell'):
  t=np.arange(round(dur*SR))/SR;env=(1-np.exp(-t*180))*np.exp(-t/decay)*np.minimum(1,(dur-t)/.08)
  if kind=='bass':v=np.sin(2*np.pi*freq*t)+.23*np.sin(4*np.pi*freq*t)
  else:v=np.sin(2*np.pi*freq*t)+.2*np.sin(2*np.pi*freq*2*t)+.08*np.sin(2*np.pi*freq*3*t)
  return v*env
 
 def stereo(v,pan=0):return np.stack((v*math.sqrt((1-pan)/2),v*math.sqrt((1+pan)/2)),axis=1)
 # Tick-and-bass pulse: dense morning, silence for the reminder, warmer continuation.
 for bt in np.arange(0,14.5,.5):
  t=np.arange(round(.21*SR))/SR;v=np.sin(2*np.pi*(48*t+35*.03*(1-np.exp(-t/.03))))*np.exp(-t*27);place(music,stereo(v),bt,.17 if int(bt*2)%4==0 else .08)
 for bt in np.arange(.25,14.5,.25):
  n=int(.045*SR);noise=rng.normal(0,1,n);noise=np.concatenate(([0],np.diff(noise)));noise*=np.exp(-np.arange(n)/SR*100);place(music,stereo(noise,.4 if int(bt*4)%2 else -.4),bt,.024)
 for bt in np.arange(18.5,30,.5):
  t=np.arange(round(.23*SR))/SR;v=np.sin(2*np.pi*53*t)*np.exp(-t*22);place(music,stereo(v),bt,.11)
 for i,bt in enumerate(np.arange(0,14.1,.5)):
  place(music,stereo(tone([164.81,196,246.94,293.66][i%4],.38,.12),-.25 if i%2 else .25),bt,.025)
 for bt,freq in [(15.7,659.25),(15.86,987.77)]:place(sfx,stereo(tone(freq,.7,.17)),bt,.11)
 # Warm, spare harmonic bed under the real product demonstration.
 for st,notes in [(18.5,[164.81,246.94,329.63]),(26.5,[196,293.66,392]),(34.5,[164.81,246.94,329.63]),(42.5,[130.81,196,261.63]),(50.5,[164.81,246.94,329.63])]:
  dur=9;t=np.arange(int(dur*SR))/SR;env=np.minimum(1,t/1.8)*np.minimum(1,(dur-t)/2.5);v=sum(np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*(f+.6)*t) for f in notes)/len(notes);place(music,stereo(v*env),st,.048)
 for i,bt in enumerate(np.arange(20,51,1)):
  place(music,stereo(tone([329.63,493.88,587.33,392][i%4],1.4,.3),(-.25,.25)[i%2]),bt,.035)
 # Brief movement accents, used only when the UI crosses the device boundary.
 for st in [32.8,38.0]:
  n=int(.55*SR);noise=rng.normal(0,1,n);noise=np.convolve(noise,np.ones(80)/80,mode='same');env=np.sin(np.linspace(0,np.pi,n))**2;place(sfx,stereo(noise*env),st,.12)
 for st,freq in [(55.05,164.81),(55.1,329.63),(55.16,493.88)]:place(music,stereo(tone(freq,4.6,1.6)),st,.045)
 # Fade source and score ends; gentle peak control before loudness normalisation.
 audio+=music+sfx;audio*=np.minimum(1,np.arange(N)/SR/.06)[:,None];audio*=np.minimum(1,(N-1-np.arange(N))/SR/1.2)[:,None];audio=np.tanh(audio*.9)
 def wav(path,a):
  with wave.open(str(path),'w') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
 wav(P/'original-score.wav',music);wav(P/'sound-design.wav',sfx);wav(P/'mix-pre-master.wav',audio)
 print('Sound stems ready',flush=True)
 sys.exit()

proc=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',str(V/'picture-master.mp4')],stdin=sp.PIPE)
for i in range(1440):
 proc.stdin.write(render(i/24).tobytes())
 if i%240==0:print(f'Film picture {i//24}/60s',flush=True)
proc.stdin.close();assert proc.wait()==0
run([FF,'-y','-i',str(V/'picture-master.mp4'),'-i',str(P/'mix-pre-master.wav'),'-map','0:v','-map','1:a','-c:v','copy','-af','loudnorm=I=-16:TP=-1.5:LRA=9','-c:a','aac','-b:a','256k','-ar','48000','-t','60','-movflags','+faststart',str(R/'videos/finn-opening-film.mp4')])
print('V3 film master ready',flush=True)
