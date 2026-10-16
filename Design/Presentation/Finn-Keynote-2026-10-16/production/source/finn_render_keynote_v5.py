from pathlib import Path
from PIL import Image,ImageDraw
import json,subprocess as sp,sys
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';S=json.loads((K/'five-minute-scenes.json').read_text());FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1';cache={};video={};resized={}
def run(a):sp.run(a,check=True,stdout=sp.DEVNULL,stderr=sp.PIPE)
for key in ['setup','live','watch-coach','finn-launch-animation']:
 d=K/'build'/('video-'+key);d.mkdir(exist_ok=True)
 if not (d/'0001.jpg').exists():run([FF,'-y','-i',str(R/f'videos/{key}.mp4'),'-vf','fps=24','-q:v','2',str(d/'%04d.jpg')])
 video[key]=sorted(d.glob('*.jpg'))
def load(path):
 if path not in cache:cache[path]=Image.open(R/path).convert('RGBA')
 return cache[path]
def ease(p):
 p=max(0,min(1,p));a=0;b=1
 for i in range(12):
  z=(a+b)/2;x=3*(1-z)**2*z*.22+3*(1-z)*z*z*.36+z**3
  if x<p:a=z
  else:b=z
 return 3*(1-z)**2*z+3*(1-z)*z*z+z**3

def value(points,t,default=0):
 if not points:return default
 if t<=points[0][0]:return points[0][1]
 for i in range(1,len(points)):
  b,y=points[i];a,x=points[i-1]
  if t<=b:return x+(y-x)*ease((t-a)/(b-a or 1))
 return points[-1][1]
def vid(n,t):
 key=n['video'];st=n.get('video_start',0);sw=n.get('video_switch')
 if sw and t>=sw['at']:key=sw['video'];st=sw['start']
 vt=max(0,t-st)+n.get('video_offset',0)
 if key=='finn-launch-animation':vt=min(vt,.8)
 fs=video[key];idx=min(len(fs)-1,max(0,int(vt*24)));return key,idx,fs[idx]
def signature(n,t):
 m=n.get('motion',{});a=value(m.get('opacity'),t,1)
 if a<=0:return (0,)
 sig=(n['key'],*(round(value(m.get(k),t,d),6) for k,d in [('opacity',1),('scale',1),('x',0),('y',0)]))
 if n.get('video'):sig+=vid(n,t)[:2]
 if n.get('overlay_cue'):sig+=(round(value([[0,0],[4,0],[4.7,1],[5.8,1],[6.7,0]],t),5),)
 return sig+tuple(signature(c,t) for c in n.get('children',[]))
def rendernode(n,t):
 w=max(1,round(n['w']));h=max(1,round(n['h']));m=n.get('motion',{});alpha=value(m.get('opacity'),t,1);x=n['x']+value(m.get('x'),t);y=n['y']+value(m.get('y'),t)
 if alpha<=0:return None,0,0
 if n['kind']=='group':
  im=Image.new('RGBA',(w,h),n.get('bg') or (0,0,0,0))
  for c in n.get('children',[]):
   layer,xx,yy=rendernode(c,t)
   if layer is not None:im.alpha_composite(layer,(xx,yy))
 else:
  path=str(vid(n,t)[2].relative_to(R)) if n.get('video') else n.get('raster',n.get('src'))
  key=(path,w,h,n.get('radius',0))
  if key not in resized:
   im=load(path).resize((w,h),Image.Resampling.LANCZOS).copy()
   if n.get('radius'):
    mask=Image.new('L',im.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),radius=n['radius'],fill=255);im.putalpha(mask)
   resized[key]=im
  im=resized[key].copy()
  if n.get('overlay_cue'):
   q=value([[0,0],[4,0],[4.7,1],[5.8,1],[6.7,0]],t);tip=load('assets/captures/posture-cue-detail.png').resize((round(w*1176/1320),round(w*230/1320)),Image.Resampling.LANCZOS)
   tip.putalpha(tip.getchannel('A').point(lambda a:round(a*q)));im.alpha_composite(tip,(round(w*72/1320),round(w*645/1320)))
 if alpha<1:im.putalpha(im.getchannel('A').point(lambda a:round(a*alpha)))
 scale=value(m.get('scale'),t,1)
 if scale!=1:
  nw=max(1,round(w*scale));nh=max(1,round(h*scale));im=im.resize((nw,nh),Image.Resampling.LANCZOS);x+=(w-nw)/2;y+=(h-nh)/2
 return im,round(x),round(y)
def frame(s,t):
 im=Image.new('RGBA',(1920,1080),s['bg'])
 for n in s['nodes']:
  layer,x,y=rendernode(n,t)
  if layer is not None:im.alpha_composite(layer,(x,y))
 return im.convert('RGB')
for s in S:
 i=s['number'];key=f'{i:02}'
 if '--camera' in sys.argv and i not in [5,6,7,9]:continue
 if '--watch' in sys.argv and i!=7:continue
 if '--cues' in sys.argv and i not in [6,7]:continue
 if i==1:
  run([FF,'-y','-i',str(R/'videos/finn-opening-film.mp4'),'-frames:v','1',str(K/f'preview/{key}.png')]);continue
 frame(s,s.get('preview_time',8)).save(K/f'preview/{key}.png');frame(s,0).save(K/f'preview/{key}-poster.png')
 for t in ([0,2,5,8,16,27] if i in [4,5,6,7,9] else [2,12]):
  if t<s['seconds']:frame(s,t).save(K/f'preview/{key}-{t:02}.jpg',quality=92)
 if '--stills' in sys.argv:continue
 out=K/f'media/{key}.mp4';pr=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out)],stdin=sp.PIPE)
 prev=None;data=None
 for z in range(s['seconds']*24):
  t=z/24;sig=tuple(signature(n,t) for n in s['nodes'])
  if sig!=prev:data=frame(s,t).tobytes();prev=sig
  pr.stdin.write(data)
 pr.stdin.close();assert pr.wait()==0
 resized.clear();cache.clear();print(key,s['title'],s['seconds'],'seconds',flush=True)
print('Revised motion media ready',flush=True)
