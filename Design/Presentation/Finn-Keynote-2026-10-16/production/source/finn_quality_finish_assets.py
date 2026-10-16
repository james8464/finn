import json,shutil
from pathlib import Path
from PIL import Image
r=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');s=json.loads((r/'production/cinematic-scenes.json').read_text())
for key,box in [('result-observation',(60,1400,1260,2120)),('coach-context',(60,390,1260,920)),('detail-comparison',(60,1070,1260,2090)),('posture-guide',(60,600,1260,1670))]:
 source=key.split('-')[0];Image.open(r/f'assets/captures/{source}.png').crop(box).save(r/f'assets/captures/{key}.png')
shutil.copy2('/tmp/finn-watch-short-tip.png',r/'assets/captures/watch-coach.png')
shutil.copy2('/tmp/finn-reminders-icon.png',r/'assets/apple/reminders-icon.png')
fix={'n8':'home','n36':'history','n54':'posture','n32':'result-observation','n39':'detail-comparison','n52':'posture-guide','n62':'coach-context'}
# Generate the revised cue outline from the same SF Pro text factory.
ns={};exec(Path('/tmp/finn_v2.py').read_text().split('plan=json.loads')[0],ns);ns['counter']=20000

def walk(n):
 if n['key'] in fix:
  key=fix[n['key']];n['src']=f'assets/captures/{key}.png'
  if n['key']=='n32':n.update(y=390,h=600)
  if n['key']=='n39':n['h']=663
  if n['key']=='n52':n['h']=722.25
  if n['key']=='n62':n['h']=397.5
 if n['kind']=='text' and n.get('text')=='Chest up':
  key=n['key'];n.update(ns['txt']('Sit lower',n['x'],n['y'],n['w'],n['size'],n['color'],n['style'],motion=n.get('motion')));n['key']=key
 if n['kind']=='image' and n.get('video')=='watch-coach':n['src']='assets/captures/watch-coach.png'
 for c in n.get('children',[]):walk(c)
for sc in s:
 for n in sc['nodes']:walk(n)
(r/'production/cinematic-scenes.json').write_text(json.dumps(s,ensure_ascii=False))
p=json.loads((r/'production/slide-plan.json').read_text());p['slides'][4]['speaker_notes']=p['slides'][4]['speaker_notes'].replace('Chest up','Sit lower');(r/'production/slide-plan.json').write_text(json.dumps(p,ensure_ascii=False,indent=2))
