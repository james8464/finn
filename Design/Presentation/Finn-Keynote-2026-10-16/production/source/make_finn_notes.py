from pathlib import Path
from PIL import Image,ImageFont,ImageDraw
import json
r=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');(r/'production/notes').mkdir(exist_ok=True)
regular=ImageFont.truetype('/Users/james/Library/Fonts/SF-Pro-Display-Regular.otf',25);bold=ImageFont.truetype('/Users/james/Library/Fonts/SF-Pro-Display-Semibold.otf',25)
def lines(text,font,width):
 out=[];line=''
 for word in text.split():
  candidate=(line+' '+word).strip()
  if font.getlength(candidate)>width:out.append(line);line=word
  else:line=candidate
 if line:out.append(line)
 return out
for s in json.loads((r/'production/slide-plan.json').read_text())['slides']:
 im=Image.new('RGBA',(1920,240),(0,0,0,0));d=ImageDraw.Draw(im)
 t=s['start_with_film_seconds'];caption=f'{s["number"]:02d} · {t//60}:{t%60:02d} · {s["seconds"]}s   |   '+s['motion'];d.text((0,0),caption,font=bold,fill='white')
 text=s['speaker_notes']
 if s['number']==1:text='OPTIONAL ALTERNATIVE OPENING. Main running order: play the 60-second Make room film, then continue at slide 2. Total 11:45. '+text
 for j,line in enumerate(lines(text,regular,1900)):d.text((0,48+j*33),line,font=regular,fill='#B6B6BB')
 im.save(r/'production/notes'/f'{s["number"]:02d}.png')
print('18 note cards rendered with SF Pro')
