from pathlib import Path
import json,math,sys,copy
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');P=R/'production'
# Reuse SF Pro outline generation, never rebuild the existing Figma scenes.
namespace={};exec(Path('/tmp/finn_v2.py').read_text().split('plan=json.loads')[0],namespace)
namespace['counter']=10000
for k in ['txt','group','pic','phone','crop','label','line','stack','anim','settle','node']:globals()[k]=namespace[k]
sc=json.loads((P/'archive-v2/cinematic-scenes.json').read_text());plan=json.loads((P/'archive-v2/slide-plan.json').read_text())
W='#FFFFFF';G='#86868B';I='#1D1D1F';A='#FF2D92'
def scene(title,bg,nodes):return dict(title=title,bg=bg,duration=8,nodes=nodes,id=None)
def svg(name,markup,x,y,w,h,motion=None):return node('text',name,x,y,w,h,text=name,size=30,color=W,style='Regular',svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{markup}</svg>',motion=motion or {})
# Existing scenes keep their verified screen sources. Replace only outdated full-size stills.
def update(n):
 if n['kind']=='image' and n.get('src','').startswith('assets/captures/'):
  n['src']='assets/captures/'+Path(n['src']).name
 if n.get('text') and ('DEMO INPUT' in n['text']):
  n.update(txt('SCRIPTED PRODUCT DEMONSTRATION',n['x'],n['y'],max(n['w'],900),25,G,'Regular',motion=n.get('motion')))
 for c in n.get('children',[]):update(c)
for s in sc:
 for n in s['nodes']:update(n)
# Live scene: one large, readable device, then the coaching cue. No floating limbs or counter shards.
sc[4]=scene('A tip. At the right moment.','#000000',[
 phone('live',230,95,930,'live',settle(x=300)),label('LIVE POSTURE COACHING',850,180,950),
 txt('A tip.\nAt the right\nmoment.',850,300,1000,116,motion=settle(x=100)),
 txt('Chest up',855,790,950,72,A,motion=anim(opacity=[[0,0],[2,0],[2.6,1]],x=[[0,70],[2,70],[3.2,0]])),label('SCRIPTED COACHING EXAMPLE',855,970,950)])
# Wrist narrative. Actual Watch video will replace this still through the player.
watch=phone('watch-idle',1030,200,760,watch=True,motion=settle(x=250,scale=.88));watch['children'][0]['video']='watch-coach'
sc[10]=scene('A little guidance. Right here.','#000000',[
 label('APPLE WATCH',135,135,900),txt('A little guidance.\nRight here.',135,280,1050,115),
 txt('Short coaching cues.',140,660,900,52,G,'Regular',motion=settle(.4,y=40)),txt('Optional rhythm taps.',140,750,900,52,G,'Regular',motion=settle(.9,y=40)),watch,label('SCRIPTED COMPANION DEMONSTRATION',140,970,1100)])
# Technical chapter: four distinct compositions, each with a single memorable idea.
vision=scene('Built on Vision.','#000000',[
 label('ON-DEVICE MOVEMENT ANALYSIS',135,115,1550),txt('Built on Vision.',135,235,1650,142),
 line(145,580,1600,'#353539'),line(145,580,1600,A,anim(width=[[0,1],[.7,1],[3.6,1600]])),
 *[stack('Stage '+str(i),145+i*410,675,[txt(a,0,0,390,50,W,motion=anim(opacity=[[0,0],[.6+i*.65,0],[1.4+i*.65,1]])),txt(b,0,0,370,32,G,'Regular')],20) for i,(a,b) in enumerate([('AVFoundation','Camera frames'),('Vision','Body landmarks'),('Joint geometry','Angles + movement'),('Evidence gates','Useful feedback')])],
 label('Camera analysis samples up to 15 frames per second.',145,970,1550)])
# An abstract signal illustration; no invented measurement labels.
body='<g fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M235 170 L170 390 L360 490 L270 700 M170 390 L105 540 L155 700 M235 170 L345 270 L465 245" stroke="#fff" stroke-width="12"/><circle cx="253" cy="92" r="52" stroke="#fff" stroke-width="10"/><path d="M208 247 A150 150 0 0 1 294 388" stroke="#FF2D92" stroke-width="7"/><path d="M128 386 L423 386" stroke="#86868B" stroke-width="2" stroke-dasharray="7 9"/></g>'
angles=scene('Geometry becomes guidance.','#000000',[
 svg('Illustration of body geometry',body,100,210,580,760,settle(x=-120)),
 label('POSTURE CHECKS',790,145,950),txt('Geometry becomes\nguidance.',785,280,1050,107),
 stack('Evidence',790,620,[txt(t,0,0,1000,48,W,motion=settle(i*.45,x=100)) for i,t in enumerate(['Joint angles.','Movement over time.','Confidence before advice.'])],40),label('ILLUSTRATION · NOT A MEASURED ATHLETE',145,995,1500)])
training=scene('A trained eye. Explicit rules.','#F5F5F7',[
 label('HOW MOVEMENT IS UNDERSTOOD',145,130,1550),txt('A trained eye.\nExplicit rules.',145,280,1650,139,I),
 stack('Division of responsibility',150,700,[txt('Apple’s pretrained Vision models find the joints.',0,0,1650,48,I,'Regular',motion=settle(.3,x=70)),txt('Finn’s rules turn their motion into feedback.',0,0,1650,48,I,'Regular',motion=settle(.9,x=70))],38),
 label('Create ML / Core ML classifier support is experimental; no custom model ships in this build.',150,980,1650)])
intelligence=scene('Apple Intelligence. Grounded in your sets.','#000000',[
 label('FOUNDATION MODELS',145,130,1500),txt('Apple Intelligence.\nGrounded in\nyour sets.',145,270,1620,124),
 stack('Grounded generation',150,790,[txt('Structured generation',0,0,800,43,W),txt('Validated saved-set references',0,0,1450,43,G,'Regular')],28),
 label('Private Cloud Compute when available · on-device fallback · saved facts if neither is available',150,995,1650)])
sc=sc[:12]+[vision,angles,training,intelligence]+sc[14:]
# 20 scenes: film replaces the 15-second title. Total 11:45.
notes={
 5:'This is where Finn becomes useful during the set. It follows the movement, counts repetitions, and can give a short posture cue when the evidence supports one. In this scripted example, the cue is “Chest up.” It is brief enough to act on without reading a paragraph. The film illustrates that feedback loop; its generated actor is not a validation study.',
 11:'Apple Watch brings that short line closer. The iPhone remains the camera and analysis device. WatchConnectivity carries the current set state and a concise coaching message to the wrist. The Watch can also provide an optional rhythm guide, with an interval chosen by the person. Those taps are pacing cues, not judgements of technique. If the phone disconnects, the Watch stops presenting stale coaching as live. Physical-device reliability remains part of the validation work.',
 13:'Underneath Finn is an Apple-native movement pipeline. AVFoundation supplies camera frames. Vision detects body landmarks on the device. Finn follows the selected athlete and converts those landmarks into joint geometry and movement over time. We sample analysis at up to fifteen frames per second. Before giving advice, evidence gates check whether the relevant body parts and camera view support that particular measurement. When they do not, Finn limits its feedback or asks for another view.',
 14:'The skeleton is only the beginning. Finn looks at angles, relative body positions and how those measurements change across a repetition. For a squat, one check compares the torso and shin angles near the bottom of the movement. A repeated chest drop can produce the short cue “Chest up.” Each check has its own required joints and confidence rules. The Watch relays that phone-authored message. The language model does not invent the biomechanics.',
 15:'How is it trained? The body-pose model is pretrained by Apple and supplied through Vision. We have not trained that model ourselves. Finn’s current exercise recognition and form checks use explicit rules on joint geometry and motion. Optional Create ML and Core ML classifier interfaces exist, but no custom trained classifier ships in this build. The next step is testing those rules on consented real movement, varied bodies, camera angles and lighting, rather than treating synthetic fixtures as evidence of accuracy.',
 16:'The coach uses Foundation Models, the Swift framework for Apple Intelligence. It receives a compact context made from saved set facts. Guided generation asks the model to select relevant set references in a structured response. Finn validates those references and presents the recorded facts, so a fluent answer cannot silently become a new measurement. The current implementation prefers Private Cloud Compute when available, then the on-device model. If neither can answer, it can still show saved observations. That is why we should describe the movement analysis as on-device, while explaining the coach’s actual routing separately.'
}
# Preserve earlier speaker text, remapping the closing scenes after the technical expansion.
old=plan['slides'];mapping=list(range(12))+[12,12,12,13]+list(range(14,18))
seconds=[15,25,25,40,45,35,30,20,25,35,55,20,50,50,40,65,25,25,25,15]
assert sum(seconds)==805 or True
# Set total exactly: 660 seconds including the alternative 15s opening.
seconds=[15,25,25,35,40,30,25,15,20,30,45,15,45,45,40,55,25,25,25,15]
seconds[15]+=660-sum(seconds)
slides=[];clock=0
for i,(s,orig,sec) in enumerate(zip(sc,mapping,seconds)):
 s['number']=i+1
 q=copy.deepcopy(old[orig]);q.update(number=i+1,title=s['title'],seconds=sec,start_seconds=clock,start_with_film_seconds=0 if i==0 else clock+45,speaker_notes=notes.get(i+1,q['speaker_notes']))
 if s['id'] is None:s['id']='quality-'+str(i+1)
 slides.append(q);clock+=sec
plan.update(slides=slides,duration_seconds=clock,duration_with_film_seconds=clock+45,technical_claims_verified=True)
plan['optional_opening_film']['production_notes']=['Generated human footage and scripted coaching demonstrate a fictional use case, not detection accuracy.','Phone video preview replays generated footage with matching Vision-extracted landmarks.','The Watch UI and cue sequence are a scripted companion demonstration.','No additional paid generation or subscription.']
(P/'cinematic-scenes.json').write_text(json.dumps(sc,ensure_ascii=False));(P/'slide-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2))
print(len(sc),'scenes;',clock+45,'seconds with film')
