from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import subprocess as sp,json,math
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';D=K/'build/film-finn';D.mkdir(exist_ok=True)
FF='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
def run(a):sp.run(a,check=True,stdout=sp.DEVNULL,stderr=sp.PIPE)
frames=D/'office';frames.mkdir(exist_ok=True)
if not (frames/'0001.jpg').exists():run([FF,'-y','-i',str(R/'assets/film/office-source.mp4'),'-vf','fps=24','-q:v','2',str(frames/'%04d.jpg')])
fs=sorted(frames.glob('*.jpg'));fonts={}
def text(im,s,xy,size,color,bold=False):
 key=(size,bold)
 if key not in fonts:fonts[key]=ImageFont.truetype('/Users/james/Library/Fonts/SF-Pro-Display-'+('Semibold' if bold else 'Regular')+'.otf',size)
 ImageDraw.Draw(im).text(xy,s,font=fonts[key],fill=color,anchor='lt')
def fit(im):
 w,h=im.size;cw=min(w,h*16/9)/1.05;ch=cw*9/16;x=max(0,min(w-cw,.5*w-cw/2));y=max(0,min(h-ch,.5*h-ch/2));return im.crop((round(x),round(y),round(x+cw),round(y+ch))).resize((1920,1080),Image.Resampling.LANCZOS)
icon=Image.open(R/'assets/captures/finn-app-icon.png').convert('RGBA').resize((82,82),Image.Resampling.LANCZOS)
def frame(t):
 im=fit(Image.open(fs[min(len(fs)-1,int((5.15+(t-15.5)*.6)*24))]).convert('RGB'))
 if t<15.65:return im
 p=1-(1-max(0,min(1,(t-15.65)/.55)))**4;w,h=760,204;x,y=round(1055+70*(1-p)),round(270-45*(1-p));bg=im.crop((x,y,x+w,y+h)).filter(ImageFilter.GaussianBlur(22)).convert('RGBA');bg=Image.alpha_composite(bg,Image.new('RGBA',(w,h),(250,250,252,228)))
 ImageDraw.Draw(bg).rounded_rectangle((1,1,w-2,h-2),38,outline=(255,255,255,165),width=2)
 bg.alpha_composite(icon,(26,30));text(bg,'Finn',(130,27),30,(80,80,86));text(bg,'now',(652,29),27,(115,115,120));text(bg,'Make time to move',(130,79),39,(29,29,31),True);text(bg,'One set. A little time for yourself.',(130,132),31,(49,49,54))
 mask=Image.new('L',(w,h));ImageDraw.Draw(mask).rounded_rectangle((0,0,w-1,h-1),38,fill=255);bg.putalpha(mask.point(lambda v:round(v*p)))
 sh=Image.new('RGBA',im.size);sh.paste((0,0,0,55),(x+15,y+25,x+15+w,y+25+h),bg.getchannel('A'));sh=sh.filter(ImageFilter.GaussianBlur(20));im.paste(sh,(0,0),sh);im.paste(bg,(x,y),bg);return im
out=D/'notification.mp4';pr=sp.Popen([FF,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','17','-pix_fmt','yuv420p',str(out)],stdin=sp.PIPE)
for i in range(63):pr.stdin.write(frame((375+i)/24).tobytes())
pr.stdin.close();assert pr.wait()==0
frame(16.7).save(K/'preview/finn-notification.jpg',quality=95)
orig=R/'production/archive-v4/videos/finn-opening-film.mp4'
run([FF,'-y','-i',str(orig),'-i',str(out),'-filter_complex',"[1:v]setpts=PTS+15.625/TB[patch];[0:v][patch]overlay=0:0:enable='gte(t,15.625)*lt(t,18.25)':eof_action=pass[v]",'-map','[v]','-map','0:a','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-c:a','copy','-t','60','-movflags','+faststart',str(R/'videos/finn-opening-film.mp4')])
print('Finn icon and app name corrected; original soundtrack preserved.',flush=True)
