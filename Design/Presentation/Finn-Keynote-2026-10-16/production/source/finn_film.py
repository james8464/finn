from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter,ImageEnhance
import numpy as np, subprocess as sp, json, math, wave, sys
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');P=R/'production/film';W=P/'render';W.mkdir(exist_ok=True)
FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
FPS=24;SIZE=(1920,1080);REG='/Users/james/Library/Fonts/SF-Pro-Display-Regular.otf';BOLD='/Users/james/Library/Fonts/SF-Pro-Display-Semibold.otf';pink=(255,45,146)
paths={k:R/f'assets/film/{k}-source.mp4' for k in ['morning','office','workout']};paths.update({k:R/f'videos/{k}.mp4' for k in ['setup','live','result']})
def run(a):sp.run(a,check=True,stdout=sp.DEVNULL,stderr=sp.DEVNULL)
for k,path in paths.items():
 d=W/k;d.mkdir(exist_ok=True)
 if not (d/'0001.jpg').exists():run([FF,'-y','-i',str(path),'-vf',f'fps={FPS}', '-q:v','2',str(d/'%04d.jpg')])
print('Decoded plates',flush=True)
files={k:sorted((W/k).glob('*.jpg')) for k in paths}
def source(k,t):
 f=files[k][min(len(files[k])-1,max(0,int(t*FPS)))];return Image.open(f).convert('RGB')
def ease(t):return 1-(1-max(0,min(1,t)))**4
fonts={}
def text(im,s,xy,size=80,color='white',bold=True,center=False,opacity=1):
 key=(size,bold)
 if key not in fonts:fonts[key]=ImageFont.truetype(BOLD if bold else REG,size)
 f=fonts[key];d=ImageDraw.Draw(im);w=d.textlength(s,font=f);x,y=xy
 if center:x-=w/2
 if opacity>=.999:d.text((round(x),round(y)),s,font=f,fill=color,anchor='lt',stroke_width=0)
 else:
  l=Image.new('RGBA',im.size);ImageDraw.Draw(l).text((round(x),round(y)),s,font=f,fill=color,anchor='lt');l.putalpha(l.getchannel('A').point(lambda v:round(v*max(0,opacity))));im.paste(l,(0,0),l)
def fit(im,zoom=1,cx=.5,cy=.5):
 w,h=im.size;ratio=16/9;cw=min(w,h*ratio)/zoom;ch=cw/ratio;x=max(0,min(w-cw,cx*w-cw/2));y=max(0,min(h-ch,cy*h-ch/2));return im.crop((round(x),round(y),round(x+cw),round(y+ch))).resize(SIZE,Image.Resampling.LANCZOS)
# 27 human cuts: urgency grows, then a deliberate breath.
edl=[]
def cut(end,k,src,speed=1,zoom=1,cx=.5,cy=.5):
 start=edl[-1]['out'] if edl else 0;edl.append(dict(start=start,out=end,source=k,source_in=src,speed=speed,zoom=zoom,cx=cx,cy=cy))
cut(.85,'morning',.05);cut(1.4,'morning',1.12);cut(2.1,'morning',2.1);cut(2.55,'morning',3.35);cut(4,'morning',4.2);cut(4.55,'morning',2.55,1,1.3,.47,.56);cut(5.5,'morning',7.35);cut(6,'office',.2,1,1.12);cut(6.45,'morning',3.3,1,1.15);cut(7.5,'morning',5.3);cut(8.45,'morning',8.4);cut(9.35,'office',3.4);cut(9.9,'office',1.3,1,1.18);cut(10.5,'office',5.25);cut(11.15,'office',4.1);cut(11.65,'office',1.8,1,1.28);cut(12.2,'morning',6.15,1,1.12);cut(12.7,'office',6,1,1.2);cut(13.1,'office',.6,1,1.3);cut(13.5,'office',4.4,1,1.14);cut(14.25,'office',5.4);cut(15.5,'office',7.1,.9);cut(18.25,'office',5.15,.6,1.05);cut(19.5,'office',8.65,.9);cut(20.15,'workout',.1);cut(20.85,'workout',1.1);cut(22.5,'workout',2.2);cut(28.5,'workout',4,1);cut(30,'workout',8.45,.95,1.1)
(P/'edit-decision-list.json').write_text(json.dumps({'fps':24,'duration':60,'human_cuts':edl,'product':[{'start':30,'out':35,'screen':'setup'},{'start':35,'out':42,'screen':'live'},{'start':42,'out':51,'screen':'result'}],'resolution':[51,55],'end_card':[55,60]},indent=2))
bezel=Image.open(R/'assets/apple/iphone18promax-silver.png').convert('RGBA');capture=Image.open(R/'assets/captures/result.png').convert('RGB');card=capture.crop((60,2095,1260,2440));maskcache={}
def rounded(im,r):
 im=im.convert('RGBA');m=Image.new('L',im.size);ImageDraw.Draw(m).rounded_rectangle((0,0,im.width-1,im.height-1),radius=r,fill=255);im.putalpha(m);return im

def over(im,layer,xy,alpha=1,shadow=0):
 x,y=map(round,xy);layer=layer.convert('RGBA')
 if alpha<1:layer.putalpha(layer.getchannel('A').point(lambda v:round(v*alpha)))
 if shadow:
  sh=Image.new('RGBA',im.size);sh.paste((0,0,0,55),(x+15,y+25,x+15+layer.width,y+25+layer.height),layer.getchannel('A'));sh=sh.filter(ImageFilter.GaussianBlur(shadow));im.paste(sh,(0,0),sh)
 im.paste(layer,(x,y),layer)

def phone(im,screen,x,y,h,alpha=1):
 z=h/3000;w=round(1470*z);can=Image.new('RGBA',(w,round(h)));screen=rounded(screen.resize((round(1320*z),round(2868*z)),Image.Resampling.LANCZOS),round(145*z));can.paste(screen,(round(75*z),round(66*z)),screen);b=bezel.resize(can.size,Image.Resampling.LANCZOS);can.alpha_composite(b);over(im,can,(x,y),alpha)

def notification(im,t):
 p=ease((t-15.65)/.7);alpha=min(p,1);lay=Image.new('RGBA',(760,186),(0,0,0,0));d=ImageDraw.Draw(lay);d.rounded_rectangle((0,0,759,185),32,fill=(245,245,247,246));text(lay,'REMINDER',(38,25),25,(100,100,105),False);text(lay,'Make time to move.',(38,73),47,(29,29,31));text(lay,'now',(654,27),23,(110,110,115),False);over(im,lay,(1050-80*(1-p),290+45*(1-p)),alpha,22)

def render(t):
 if t<30:
  e=next(e for e in edl if e['start']<=t<e['out']);im=fit(source(e['source'],e['source_in']+(t-e['start'])*e['speed']),e['zoom']*(1.035 if e['source']=='workout' else 1),e['cx'],e['cy'])
  if 15.65<=t<18.25:notification(im,t)
  if 28.5<=t<30:
   fade=min(.25,(t-28.5)/6);im=Image.blend(im,Image.new('RGB',SIZE),fade)
  return im
 if t<35:
  u=t-30;im=Image.new('RGB',SIZE);p=ease(u/1.35);phone(im,source('setup',4+u),1140-100*p,160-85*p,1050-120*p)
  text(im,'Make room.',(130-70*(1-p),260),115,opacity=p)
  text(im,'For one set.',(130,430+30*(1-ease((u-1.4)/1.0))),90,pink,opacity=ease((u-1.4)/1))
  text(im,'ACTUAL APP · DEMO INPUT',(130,975),25,(155,155,160),False,opacity=ease(u-.8));return im
 if t<42:
  u=t-35;p=ease(u/1.5);im=Image.new('RGB',SIZE);screen=source('live',u)
  x=1040-810*p;phone(im,screen,x,75+5*p,930)
  # Actual live pose and rep counter detach from their source positions.
  q=ease((u-.55)/1.8);pose=screen.crop((195,660,520,1060));pw=round(155+255*q);pose=pose.resize((pw,round(pose.height*pw/pose.width)),Image.Resampling.LANCZOS)
  over(im,pose,(x+140+470*q,400-40*q),q)
  count=screen.crop((475,167,660,345));cw=round(80+240*q);count=count.resize((cw,round(count.height*cw/count.width)),Image.Resampling.LANCZOS);over(im,count,(x+350+650*q,250+85*q),q)
  text(im,'Find your rhythm.',(730,135),91,opacity=p);text(im,'ACTUAL APP · DEMO INPUT',(1240,940),25,(155,155,160),False);return im
 if t<51:
  u=t-42;p=ease(u/1.5);im=Image.new('RGB',SIZE,(245,245,247));phone(im,source('result',min(u,6.8)),220,200,800)
  text(im,'One useful observation.',(130,95),102,(29,29,31),opacity=p)
  q=ease((u-.65)/2.1);w=round(310+740*q);lay=rounded(card.resize((w,round(card.height*w/card.width)),Image.Resampling.LANCZOS),round(22*q+9));over(im,lay,(270+480*q,765-290*q),q,round(18*q))
  text(im,'A REAL RESULT · SYNTHETIC DEMO INPUT',(750,855),25,(110,110,116),False,opacity=ease(u-2.0));return im
 if t<55:
  im=fit(source('workout',8+(t-51)*.49),1.035);text(im,'A little time.',(130,730),88,opacity=ease((t-51)/.6));text(im,'A clearer next step.',(130,840),88,opacity=ease((t-52)/.7));
  if t>54.5:im=Image.blend(im,Image.new('RGB',SIZE),ease((t-54.5)/.5))
  return im
 im=Image.new('RGB',SIZE);u=t-55;text(im,'Finn',(960,330),250,center=True,opacity=ease(u/.8));text(im,'Find your line.',(960,650),62,center=True,bold=False,opacity=ease((u-.7)/.9));return im

if '--stills' in sys.argv:
 times=[.3,2.3,4.8,8.8,12.9,16.7,20.2,24.8,29,32.8,37.5,45.5,52.3,57.5]
 sheet=Image.new('RGB',(1280,math.ceil(len(times)/2)*360),'#222')
 for i,t in enumerate(times):
  im=render(t);im.save(W/f'proof-{t:05.1f}.jpg',quality=92);im=im.resize((640,360));ImageDraw.Draw(im).text((10,10),f'{t:04.1f}s',fill='white',font=ImageFont.truetype(REG,20));sheet.paste(im,(i%2*640,i//2*360))
 sheet.save(P/'film-storyboard.jpg',quality=90);print('Storyboard ready');sys.exit()

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
for st in [35.55,42.65]:
 n=int(.55*SR);noise=rng.normal(0,1,n);noise=np.convolve(noise,np.ones(80)/80,mode='same');env=np.sin(np.linspace(0,np.pi,n))**2;place(sfx,stereo(noise*env),st,.12)
for st,freq in [(55.05,164.81),(55.1,329.63),(55.16,493.88)]:place(music,stereo(tone(freq,4.6,1.6)),st,.045)
# Fade source and score ends; gentle peak control before loudness normalisation.
audio+=music+sfx;audio*=np.minimum(1,np.arange(N)/SR/.06)[:,None];audio*=np.minimum(1,(N-1-np.arange(N))/SR/1.2)[:,None];audio=np.tanh(audio*.9)
def wav(path,a):
 with wave.open(str(path),'w') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes((np.clip(a,-1,1)*32767).astype('<i2').tobytes())
wav(P/'original-score.wav',music);wav(P/'sound-design.wav',sfx);wav(P/'mix-pre-master.wav',audio)
print('Sound stems ready',flush=True)
out=W/'picture-master.mp4';proc=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out)],stdin=sp.PIPE)
for i in range(60*FPS):
 im=render(i/FPS);proc.stdin.write(im.tobytes())
 if i%240==0:print(f'Rendered {i//FPS}/60 seconds',flush=True)
proc.stdin.close();assert proc.wait()==0
run([FF,'-y','-i',str(out),'-i',str(P/'mix-pre-master.wav'),'-map','0:v','-map','1:a','-c:v','copy','-af','loudnorm=I=-16:TP=-1.5:LRA=9','-c:a','aac','-b:a','256k','-ar','48000','-t','60','-movflags','+faststart',str(R/'videos/finn-opening-film.mp4')])
print('60-second film master ready',flush=True)
