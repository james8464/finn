from pathlib import Path
import json,copy
from PIL import Image
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote'
ns={};exec(Path('/tmp/finn_v2.py').read_text().split('plan=json.loads')[0],ns);ns['counter']=50000
T=ns['txt'];P=ns['phone'];N=ns['node']
W='#FFFFFF';G='#86868B';A='#FF2D92';B='#000000'
def show(a,b,stop=None):
 p=[[0,0],[a,0],[b,1]] if a else [[0,0],[b,1]]
 if stop:p += [[stop,1],[stop+.65,0]]
 return p
def text(s,x,y,w,size=112,color=W,at=0,until=None):return T(s,x,y,w,size,color,motion={'opacity':show(at,at+.65,until)})
def image(src,x,y,w,h,m=None):return N('image',Path(src).stem,x,y,w,h,src=src,motion=m or {})
def scene(title,items,old):
 z=copy.deepcopy(old);z.update(title=title,nodes=items,duration=z['seconds']);return z
old=json.loads((R/'production/archive-v4/keynote/five-minute-scenes.json').read_text());s=[copy.deepcopy(old[0])]
s[0]['notes'] += ' The Finn reminder is a proposed notification experience, composited for this film.'
# Two functions of the existing category. Photographic evidence has room to breathe.
a=text('Workouts to follow',125,110,1650,120,'#1D1D1F',0,11)
b=text('Progress to track',125,110,1650,120,'#1D1D1F',11.5)
hero=image('assets/apple/fitness-plus-official-2x.jpg',125,365,1450,667,{'opacity':[[0,0],[.8,1],[10.5,1],[12.2,0]],'scale':[[0,1.035],[2.1,1]],'x':[[0,0],[10.5,0],[12.5,-175]]})
plan=image('assets/apple/fitness-custom-plans-2x.jpg',1260,310,500,673,{'opacity':show(11,12.3),'x':[[0,160],[11,160],[13,0]]})
s.append(scene('Workouts to follow. Progress to track.',[hero,a,b,plan],old[1]))
s[-1]['preview_time']=18
# A clean verbal reset. Only the question, without the ornamental underline.
s.append(scene('What about your movement?',[text('What about',140,275,1650,155,at=0),text('your movement?',140,470,1650,155,at=1.7)],old[2]));s[-1]['preview_time']=5
# Identity holds first. The mark then yields the stage to the product.
icon=image('assets/captures/finn-app-icon.png',745,155,430,430,{'opacity':show(0,.7,4.4),'scale':[[0,.96],[1.4,1]]})
name=text('Finn',140,650,1640,160,at=.6,until=4.4);name=T('Finn',140,650,1640,160,align='CENTER',motion=name['motion'])
p=P('home',1180,75,930,'finn-launch-animation',{'opacity':show(4.6,5.3),'scale':[[0,1.08],[4.6,1.08],[6.2,1]]});p['children'][0]['video_start']=5
s.append(scene('Meet Finn',[icon,name,text('Meet Finn',130,330,1000,155,at=5.1),text('Stronger starts\ntogether',140,565,900,62,G,6.2),p],old[3]));s[-1]['preview_time']=8
# The same device crosses into setup. Words follow setup and movement, not a three-word template.
p=P('setup',780,75,930,'setup',{'x':[[0,400],[1.5,0]]});p['children'][0]['video_start']=1.2
s.append(scene('Ready when you are',[p,text('Ready when\nyou are',130,300,610,112,at=.8,until=12),text('Start your set',130,365,610,108,at=13),text('A clear view',1320,495,490,64,G,at=4,until=12)],old[4]));s[-1]['preview_time']=7
# The native cue travels from its exact position inside the screen into a readable close-up.
Image.open('/tmp/finn-clean-posture-tip.png').crop((72,645,1248,875)).save(R/'assets/captures/posture-cue-detail.png')
p=P('live',210,75,930,'live',{'x':[[0,570],[1.7,0]]})
cue=image('assets/captures/posture-cue-detail.png',810,625,900,176,{'opacity':show(4,4.7),'scale':[[0,.405],[5.8,.405],[8.3,1]],'x':[[0,-822.18],[5.8,-822.18],[8.3,0]],'y':[[0,-381.95],[5.8,-381.95],[8.3,0]]})
s.append(scene('A better next rep',[p,text('A better\nnext rep',810,220,1000,132,at=1.2),cue],old[5]));s[-1]['preview_time']=10
# Cue hand-off: phone continuity first, readable cue travels to the wrist, Watch resolves in place.
p=P('live',210,75,930,'live',{'opacity':[[0,1],[1.8,1],[3.4,0]],'x':[[0,0],[1.7,0],[3.4,-160]]});p['children'][0]['video_offset']=5
w=P('watch-idle',1085,140,820,watch=True,motion={'opacity':show(2.4,3.6),'scale':[[0,.94],[2.4,.94],[4.2,1]]});w['children'][0].update(src='assets/captures/watch-coach.png',video='watch-coach',video_start=3.6,motion={'opacity':show(3.7,4.15)})
cue=image('assets/captures/posture-cue-detail.png',810,625,900,176,{'opacity':[[0,1],[1.2,1],[3.1,1],[3.65,0]],'scale':[[0,1],[1.2,1],[3.5,.26]],'x':[[0,0],[1.2,0],[3.5,86]],'y':[[0,0],[1.2,0],[3.5,-196]]})
s.append(scene('Right on your wrist',[p,w,cue,T('A better\nnext rep',810,220,1000,132,motion={'opacity':[[0,1],[.7,0]]}),text('Right on\nyour wrist',135,245,900,132,at=3.8),text('Optional rhythm taps',140,755,900,54,G,at=15)],old[6]));s[-1]['preview_time']=18
# The framework icon gets a deliberate still, logo-only stage.
s.append(scene('Foundation Models',[image('assets/apple/foundation-models.png',760,340,400,400,{'opacity':show(0,.8)})],old[7]));s[-1]['preview_time']=3
# Camera evidence remains present while technical explanations advance at speaking speed.
p=P('live',210,75,930,'live',{'opacity':show(0,.8)})
n=[p]
for a,b,at,until in [('Vision','Pretrained body pose',0,11.7),('Joint geometry','Repetitions and posture',12.4,25),('Confidence','Before advice',25.7,None)]:
 n += [text(a,810,300,1020,118,at=at,until=until),text(b,820,495,950,58,G,at=at+.5,until=until)]
s.append(scene('How Finn sees movement',n,old[8]));s[-1]['preview_time']=17
# Finish on a single retained promise, with identity. No third line repeats the brand.
s.append(scene('Stronger starts together',[image('assets/captures/finn-app-icon.png',825,190,270,270,{'opacity':show(0,.65)}),T('Stronger starts\ntogether',140,540,1640,138,align='CENTER',motion={'opacity':show(.7,1.5)})],old[9]));s[-1]['preview_time']=4
# A spoken script, rather than a caption of what is already visible.
s[3]['notes']='1:45–2:05. Meet Finn. A second perspective on the way you move. Set down your iPhone, choose an exercise, and start a set. Finn is still in implementation. This walkthrough shows the current experience with scripted example coaching.'
s[4]['notes']='2:05–2:30. Start with the exercise you want to work on. Finn helps you find the right camera view. For this squat, that means standing sideways with your whole body visible. Once the camera can see the joints it needs, start the set and focus on the movement. [Advance to begin the set.]'
s[5]['notes']='2:30–3:05. Your iPhone follows the body landmarks and counts your reps. But the useful moment is the adjustment. [Let the cue enlarge at 6 seconds.] Sit lower. A short cue, connected to the movement in front of the camera. The next rep becomes a chance to use that guidance. Afterward, a compact review keeps the observation with your set. This cue is a scripted product demonstration, not a measured finding about the actor.'
s[6]['notes']='3:05–3:35. The same cue can come to your Apple Watch. [Let the cue travel into the Watch.] So you can stay with the set instead of turning back toward the phone. The iPhone still performs the camera analysis. WatchConnectivity sends the current set and a phone-authored coaching line to your wrist. Optional rhythm taps help you hold a pace you choose. Those taps guide timing, rather than judging form.'
s[8]['notes']='4:00–4:40. [0–12 seconds: Vision.] AVFoundation supplies camera frames. Apple’s pretrained Vision model finds the body landmarks on your device. We do not train that model ourselves. [12–25 seconds: Joint geometry.] Finn tracks the selected athlete and uses joint angles over time to count repetitions and apply exercise-specific posture rules. No custom trained classifier ships in this build. [26–40 seconds: Confidence.] A measurement has to pass visibility and confidence checks before it can support advice. If the camera cannot see enough, Finn should ask for a better view instead of guessing.\nSources: Finn/Capture/PoseFrameAnalyzer.swift; Finn/Workout/FormChecks.swift; tools/exercise-classifier/README.md; https://developer.apple.com/documentation/vision/vndetecthumanbodyposerequest'
s[9]['notes']='4:40–5:00. A second perspective. A useful adjustment. Guidance on your wrist. That is Finn. Our next step is validating the experience with real people, real movement and real devices. We want every set to leave you with something useful for the next one. Stronger starts together.'
s[0]['notes'] += ' Continuous source video replaces simulator playback. Vision landmark positions are interpolated for visual smoothness in this scripted product demonstration.'
clock=0
for i,z in enumerate(s):z.update(number=i+1,start_seconds=clock,id='keynote-'+str(i+1));clock+=z['seconds']
assert clock==300
(K/'five-minute-scenes.json').write_text(json.dumps(s,ensure_ascii=False))
(K/'motion-direction.md').write_text('''# Five-minute motion direction\n\nThe presenter owns the story. Animation directs the eye to the evidence, then holds. All device art is Apple artwork. Text is SF Pro. Product captures and identity are Finn assets.\n\n1. Film: native-format Finn notification, same original sound and human edit.\n2. Category: a guided class yields focus to the plan on iPhone at 12 seconds.\n3. Reset: the question stands alone, with a short pause before “your movement”.\n4. Reveal: icon and name hold before giving the stage to the real launch mark inside iPhone.\n5. Setup: device carries over from the previous position. Copy changes when the set starts.\n6. Observation: a crop of the native cue enlarges from its exact location in the phone.\n7. Continuity: that cue carries across the slide boundary into the Apple Watch screen.\n8. Framework: official Foundation Models icon alone. Silence in the visual gives the explanation room.\n9. Implementation: Vision, joint geometry, then confidence. Each gets its own speaking interval rather than a diagram arriving all at once.\n10. Close: app icon and one retained promise.\n\nMovies use custom cubic-bezier timing, matched device geometry and source-aligned cue extraction. No bounce, camera-spin preset, decorative signal line or continuous idle motion. After each explanation resolves, the composition holds still.\n''')
print('Revised story and motion: 10 scenes / 300 seconds')
