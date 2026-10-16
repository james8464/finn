from pathlib import Path
from PIL import Image,PngImagePlugin
import json
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');D=R/'production/native-stills';D.mkdir(exist_ok=True);sc=json.loads((R/'production/cinematic-scenes.json').read_text());ops=[]
def walk(n,path):
 pp=path+[n['name']]
 if n['kind']=='image' and not n.get('video') and n['name'] not in ['iphone','watch']:
  ops.append({'frame':s['id'],'path':pp,'file':str(D/(s['id'].replace(':','-')+'-'+n['key']+'.png')),'key':n['key'],'image':n['src'],'crop':None,'x':n['x'],'y':n['y'],'w':n['w'],'h':n['h']})
 for c in n.get('children',[]):
  if n['name'].startswith('UI detail') and c['kind']=='image' and not c.get('video'):
   z=c['w']/Image.open(R/c['src']).width;box=(-c['x']/z,-c['y']/z,(n['w']-c['x'])/z,(n['h']-c['y'])/z)
   ops.append({'frame':s['id'],'path':pp+[c['name']],'file':str(D/(s['id'].replace(':','-')+'-'+c['key']+'.png')),'key':c['key'],'image':c['src'],'crop':[round(v) for v in box],'x':0,'y':0,'w':n['w'],'h':n['h']})
  else:walk(c,pp)
for s in sc:
 for n in s['nodes']:walk(n,[])
for i,op in enumerate(ops):
 im=Image.open(R/op['image']);im=im.crop(op['crop']) if op['crop'] else im;meta=PngImagePlugin.PngInfo();meta.add_text('Title',f'Finn cinematic v2 verified still {i+1} / 16 October 2026');im.save(op['file'],pnginfo=meta)
(R/'production/static-image-fixes.json').write_text(json.dumps(ops));print(len(ops),'verified image replacements')
