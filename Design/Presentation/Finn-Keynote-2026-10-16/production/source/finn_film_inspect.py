from pathlib import Path
import subprocess,shutil,json
from PIL import Image,ImageDraw
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');D=R/'assets/film';F='/Users/james/.local/lib/python3.14/site-packages/imageio_ffmpeg/binaries/ffmpeg-macos-aarch64-v7.1'
manifest=[]
for key,pattern in [('morning','Man_rushing*mp4'),('office','Man_working*mp4'),('workout','Man_dropping*mp4')]:
 src=sorted(Path('/Users/james/Downloads').glob(pattern),key=lambda p:p.stat().st_mtime)[-1];target=D/(key+'-source.mp4');shutil.copy2(src,target)
 info=subprocess.run([F,'-hide_banner','-i',str(target)],capture_output=True,text=True).stderr
 print(key,'; '.join(x.strip() for x in info.splitlines() if 'Duration:' in x or 'Stream #' in x))
 out=D/(key+'-frames');out.mkdir(exist_ok=True)
 subprocess.run([F,'-v','error','-y','-i',str(target),'-vf','fps=1,scale=384:216',str(out/'%02d.jpg')],check=True)
 ims=sorted(out.glob('*.jpg'));sheet=Image.new('RGB',(384*5,246*((len(ims)+4)//5)),'#161616');draw=ImageDraw.Draw(sheet)
 for i,p in enumerate(ims):
  x=i%5*384;y=i//5*246;sheet.paste(Image.open(p),(x,y));draw.text((x+10,y+222),f'{key} {i}s',fill='white')
 sheet.save(D/(key+'-contact.jpg'));manifest.append({'key':key,'file':str(target.relative_to(R)),'tool':'Google Flow agent','model':'Omni 1.1 Flash as quoted by Flow','cost_included_credits':15,'source_resolution':'720p','source':'AI-generated fictional person','inspection':info})
(R/'production/film/source-manifest.json').write_text(json.dumps(manifest,indent=2))
