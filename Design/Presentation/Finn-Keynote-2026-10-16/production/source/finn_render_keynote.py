from pathlib import Path
from PIL import Image,ImageDraw
import json,subprocess as sp,sys
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';S=json.loads((K/'five-minute-scenes.json').read_text());FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1';cache={};video={}
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
  t=(a+b)/2;x=3*(1-t)**2*t*.22+3*(1-t)*t*t*.36+t**3
  if x<p:a=t
  else:b=t
 return 3*(1-t)**2*t+3*(1-t)*t*t+t**3
def value(points,t,default=0):
 if not points:return default
 if t<=points[0][0]:return points[0][1]
 for i in range(1,len(points)):
  b,y=points[i];a,x=points[i-1]
  if t<=b:return x+(y-x)*ease((t-a)/(b-a or 1))
 return points[-1][1]
def rendernode(n,t):
 w=max(1,round(n['w']));h=max(1,round(n['h']));m=n.get('motion',{});alpha=value(m.get('opacity'),t,1)
 if n['kind']=='group':
  im=Image.new('RGBA',(w,h),n.get('bg') or (0,0,0,0))
  for c in n.get('children',[]):
   layer,x,y=rendernode(c,t);im.alpha_composite(layer,(x,y))
 elif n['kind']=='text':im=load(n['raster']).resize((w,h),Image.Resampling.LANCZOS).copy()
 elif n['kind']=='image':
  if n.get('video'):
   fs=video[n['video']];vt=min(t,.8) if n['video']=='finn-launch-animation' else t
   p=fs[min(len(fs)-1,max(0,int(vt*24)))];im=Image.open(p).convert('RGBA').resize((w,h),Image.Resampling.LANCZOS)
  else:im=load(n['src']).resize((w,h),Image.Resampling.LANCZOS).copy()
 elif n['kind']=='rect':
  w=max(1,round(value(m.get('width'),t,n['w'])));im=Image.new('RGBA',(w,h),n['color'])
 if n.get('radius'):
  mask=Image.new('L',im.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,im.width-1,im.height-1),radius=n['radius'],fill=255);im.putalpha(mask)
 if alpha<1:im.putalpha(im.getchannel('A').point(lambda a:round(a*alpha)))
 scale=value(m.get('scale'),t,1);x=n['x']+value(m.get('x'),t);y=n['y']+value(m.get('y'),t)
 if scale!=1:
  nw=max(1,round(w*scale));nh=max(1,round(h*scale));im=im.resize((nw,nh),Image.Resampling.LANCZOS);x+=(w-nw)/2;y+=(h-nh)/2
 return im,round(x),round(y)
def frame(s,t):
 im=Image.new('RGBA',(1920,1080),s['bg'])
 for n in s['nodes']:
  layer,x,y=rendernode(n,t);im.alpha_composite(layer,(x,y))
 return im.convert('RGB')
for s in S:
 i=s['number'];key=f'{i:02}'
 if '--identity' in sys.argv and i not in [4,10]:continue
 if i==1:
  run([FF,'-y','-i',str(R/'videos/finn-opening-film.mp4'),'-frames:v','1',str(K/f'preview/{key}.png')]);continue
 frame(s,8).save(K/f'preview/{key}.png');frame(s,0).save(K/f'preview/{key}-poster.png')
 if '--stills' in sys.argv:continue
 out=K/f'media/{key}.mp4'
 if out.exists() and '--force' not in sys.argv:continue
 short=K/f'build/{key}-motion.mp4';proc=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p',str(short)],stdin=sp.PIPE)
 for z in range(192):proc.stdin.write(frame(s,z/24).tobytes())
 proc.stdin.close();assert proc.wait()==0
 run([FF,'-y','-i',str(short),'-vf',f'tpad=stop_mode=clone:stop_duration={s["seconds"]-8}','-t',str(s['seconds']),'-an','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(out)])
 print(key,s['title'],s['seconds'],'seconds',flush=True)
print('Keynote motion media ready',flush=True)
