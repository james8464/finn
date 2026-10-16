from pathlib import Path
import json,sys,re,math
sys.path.insert(0,'/tmp/finn-font-tools')
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from PIL import ImageFont,Image
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16')
P=R/'production';A={x['key']:x for x in json.loads((P/'asset-manifest.json').read_text())}
H={x['key']:x['result']['imageHash'] for x in json.loads((P/'figma-assets.json').read_text())}
F={};counter=0
INK='#1D1D1F';PINK='#FF2D92';WHITE='#FFFFFF';GRAY='#86868B'
def anim(**kw):return {k:[[float(t),v] for t,v in vv] for k,vv in kw.items()}
def settle(delay=0,x=0,y=0,scale=1):
 d={}
 if x:d['x']=[[0,x],[delay,x],[delay+1.2,0]]
 if y:d['y']=[[0,y],[delay,y],[delay+1.2,0]]
 if scale!=1:d['scale']=[[0,scale],[delay,scale],[delay+1.2,1]]
 return d

def node(kind,name,x,y,w,h,**kw):
 global counter;counter+=1
 return dict(kind=kind,name=name,key=f'n{counter}',x=x,y=y,w=w,h=h,**kw)
def txt(text,x,y,w,size=96,color=WHITE,style='Semibold',align='LEFT',motion=None):
 global F
 path=f'/Users/james/Library/Fonts/SF-Pro-Display-{style}.otf'
 if style not in F:
  f=TTFont(path);F[style]=(f,f.getGlyphSet(),f.getBestCmap(),f['head'].unitsPerEm)
 ft,gs,cm,upm=F[style];pf=ImageFont.truetype(path,round(size*10));tr=-size*.025;lh=size*1.05
 def length(s):return pf.getlength(s)/10+max(0,len(s)-1)*tr
 lines=[]
 for hard in text.split('\n'):
  l=''
  for word in hard.split(' '):
   z=(l+' '+word) if l else word
   if l and length(z)>w:lines.append(l);l=word
   else:l=z
  lines.append(l)
 pen=SVGPathPen(gs);scale=size/upm;base=(lh+ft['OS/2'].sCapHeight*scale)/2
 for j,l in enumerate(lines):
  xx=(w-length(l))/2 if align=='CENTER' else 0
  for i,ch in enumerate(l):
   gl=gs.get(cm.get(ord(ch),'space'))
   if gl:gl.draw(TransformPen(pen,(scale,0,0,-scale,xx,base+j*lh)))
   adv=pf.getlength(ch)/10
   if i+1<len(l):adv+=(pf.getlength(ch+l[i+1])-pf.getlength(ch)-pf.getlength(l[i+1]))/10
   xx+=adv+tr
 h=math.ceil(lh*len(lines));d=re.sub(r'-?\d+\.\d+',lambda m:format(float(m[0]),'.3f').rstrip('0').rstrip('.'),pen.getCommands())
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><path fill="{color}" d="{d}"/></svg>'
 return node('text',text,x,y,w,h,text=text,size=size,color=color,style=style,svg=svg,motion=motion or {})
def group(name,x,y,w,h,children,motion=None,clip=False,radius=0,bg=None):return node('group',name,x,y,w,h,children=children,motion=motion or {},clip=clip,radius=radius,bg=bg)
def pic(key,x,y,w,h,video=None):return node('image',key,x,y,w,h,src=A[key]['path'],hash=H[key],video=video)
def phone(key,x,y,h=900,video=None,motion=None,watch=False):
 asset=A['watch' if watch else 'iphone'];ow,oh=asset['size'];z=h/oh;g=asset['screen'];screen=pic(key,g[0]*z,g[1]*z,g[2]*z,g[3]*z,video);screen['radius']=(92 if watch else 145)*z
 return group('Apple Watch' if watch else 'iPhone',x,y,ow*z,h,[screen,pic('watch' if watch else 'iphone',0,0,ow*z,h)],motion=motion)
def crop(key,box,x,y,w,video=None,motion=None,radius=30):
 sx,sy,sw,sh=box;z=w/sw;ow,oh=A[key]['size'];n=pic(key,-sx*z,-sy*z,ow*z,oh*z,video)
 return group('UI detail · '+key,x,y,w,sh*z,[n],motion=motion,clip=True,radius=radius)
def label(t,x,y,w=900,color=GRAY):return txt(t,x,y,w,27,color,'Regular')
def line(x,y,w,color=PINK,motion=None):return node('rect','Signal',x,y,w,3,color=color,motion=motion or {})
def stack(name,x,y,items,gap=12):
 yy=0
 for n in items:n['x']=0;n['y']=yy;yy+=n['h']+gap
 n=group(name,x,y,max(n['w'] for n in items),yy-gap,items);n['layout']='VERTICAL';n['gap']=gap;return n
plan=json.loads((P/'slide-plan.json').read_text());frames=['182:2','182:20','182:31','182:51','182:495','182:515','182:542','182:571','182:627','182:647','182:667','182:703','182:724','182:840','182:880','182:898','182:924','182:942'];sc=[]
def slide(bg,items,title,duration=6):
 i=len(sc);s=dict(number=i+1,id=frames[i],title=title,bg=bg,duration=duration,nodes=items);sc.append(s);plan['slides'][i]['title']=title;return s
# A clean title. Main version later opens with the film.
slide('#000000',[txt('Finn',140,315,1640,250,align='CENTER',motion=anim(scale=[[0,1.12],[1.7,1]],opacity=[[0,0],[.6,1]])),txt('Find your line.',140,625,1640,54,style='Regular',align='CENTER',motion=anim(opacity=[[0,0],[.85,0],[1.8,1]]))],'Finn')
slide('#F5F5F7',[label('AFTER THE LAST REP',140,170,1200),txt('What changed?',140,350,1700,174,INK,motion=settle(x=80)),line(145,620,730,motion=anim(width=[[0,1],[.5,1],[1.6,730]])),txt('Make the next set count.',145,705,1500,54,GRAY,'Regular',motion=anim(opacity=[[0,0],[1.1,0],[2,1]]))],'What changed?')
slide('#000000',[txt('A new\nperspective.',130,220,1100,170,WHITE,motion=settle(x=-180)),phone('home',1280,60,1200,motion=settle(x=420,y=120,scale=1.14)),label('ON YOUR IPHONE',145,850)],'A new perspective.')
slide('#000000',[phone('setup',735,90,920,'setup',settle(x=530,scale=1.1)),txt('Choose.',135,260,620,106,motion=anim(opacity=[[0,0],[.3,1]],x=[[0,-90],[1.2,0]])),txt('Frame.',1300,455,500,106,motion=anim(opacity=[[0,0],[1.1,0],[1.6,1]],x=[[0,100],[1.1,100],[2.2,0]])),txt('Move.',135,735,620,106,PINK,motion=anim(opacity=[[0,0],[2,0],[2.6,1]],x=[[0,-90],[2,-90],[3.1,0]])),label('ACTUAL APP · DEMO INPUT',135,970,650)],'Choose. Frame. Move.',8)
slide('#000000',[phone('live',155,120,860,'live',settle(x=530)),txt('In the moment.',720,125,1100,100),crop('live',[390,1320,650,1000],790,300,450,'live',settle(x=-500,y=90,scale=.62),0),crop('live',[950,335,370,355],1320,350,350,'live',settle(x=-600,y=40,scale=.55),0),label('ACTUAL APP · DEMO INPUT',1230,900,650)],'In the moment.',8)
slide('#F5F5F7',[txt('One useful\nobservation.',130,110,1600,116,INK,motion=settle(x=80)),phone('result',235,380,650,'result',settle(x=-110)),crop('result',[60,2095,1200,345],790,570,1000,None,anim(x=[[0,-540],[.6,-540],[2.5,0]],y=[[0,150],[.6,150],[2.5,0]],scale=[[0,.56],[.6,.56],[2.5,1]],opacity=[[0,0],[.6,0],[1,1]]),28),label('A REAL RESULT · SYNTHETIC DEMO INPUT',790,930,1000)],'One useful observation.',8)
slide('#000000',[txt('Keep the insight.',130,110,1500,112),phone('history',210,360,640,motion=settle(y=350)),crop('detail',[60,1350,1200,1060],850,320,780,None,settle(x=350,y=80),32),label('HISTORY + COMPARABLE SETS',135,1015,700)],'Keep the insight.',6)
# Type sequence: six exercise names are the composition, not a feature-card grid.
slide('#FFFFFF',[txt('6',1350,90,530,720,INK,motion=anim(scale=[[0,.82],[1.5,1]],opacity=[[0,0],[.5,1]])),label('SUPPORTED MOVEMENTS',145,130,1000),stack('Exercise names',145,300,[txt(v,0,0,1120,70,INK,motion=settle(i*.12,x=-90)) for i,v in enumerate(['Squat','Push-up','Static lunge','Stiff-leg deadlift','Pull-up','Bar muscle-up'])],21)],'Six movements.')
slide('#000000',[txt('See the movement.',125,105,1700,108),crop('posture',[60,788,1200,1056],130,300,810,None,settle(x=-250),30),phone('posture',1420,330,700,motion=settle(y=200)),label('ILLUSTRATED GUIDANCE',130,250,1100)],'See the movement.')
slide('#000000',[txt('Your sets.\nIn context.',130,120,1120,130),phone('coach',1340,155,860,'history-coach',settle(x=450)),crop('coach',[60,464,1200,620],145,520,900,None,anim(y=[[0,180],[.45,180],[1.8,0]],opacity=[[0,0],[.45,0],[1.2,1]]),32),label('GROUNDED IN SAVED SETS',145,470,1100)],'Your sets. In context.',8)
slide('#F5F5F7',[txt('Stay in the set.',130,110,1600,116,INK),phone('live',300,340,700,motion=settle(x=-250)),phone('watch-idle',1070,340,640,watch=True,motion=settle(x=350,scale=.78)),label('WATCH COMPANION PREVIEW',1060,275,750)],'Stay in the set.',7)
slide('#FFFFFF',[txt('Closer.',140,120,1650,190,INK),stack('System surfaces',145,470,[txt(v,0,0,1500,82,INK,motion=settle(i*.42,x=160)) for i,v in enumerate(['Widgets','Live Activities','App Intents'])],54),label('APPLE SYSTEM INTEGRATIONS',140,980,1500)],'Closer.')
# Technical explanation uses a moving signal and named stages, no icon-card decoration.
slide('#000000',[txt('From movement\nto meaning.',130,110,1660,120),line(145,620,1620,'#424245'),line(145,620,1620,PINK,anim(width=[[0,1],[.9,1],[3.6,1620]])),*[stack('Stage '+str(i),145+i*425,715,[txt(a,0,0,405,50,WHITE,motion=anim(opacity=[[0,0],[.6+i*.65,0],[1.3+i*.65,1]])),txt(b,0,0,390,30,GRAY,'Regular')],18) for i,(a,b) in enumerate([('AVFoundation','Camera frames'),('Vision','Body pose'),('Evidence','Exercise rules'),('Feedback','One observation')])]],'From movement to meaning.',7)
slide('#F5F5F7',[label('FOUNDATION MODELS',145,135,1400),txt('Intelligence.\nGrounded.',145,300,1300,152,INK,motion=settle(x=-100)),stack('Grounding',1370,405,[txt(v,0,0,450,43,INK,motion=anim(opacity=[[0,0],[1+i*.5,0],[1.8+i*.5,1]])) for i,v in enumerate(['Saved sets.','Relevant context.','Recorded facts.'])],66)],'Intelligence. Grounded.')
slide('#000000',[txt('0',150,80,1620,680,WHITE,align='CENTER',motion=anim(scale=[[0,1.4],[2.2,1]],opacity=[[0,0],[.6,1]])),txt('workout videos saved',150,835,1620,62,WHITE,'Regular','CENTER',anim(opacity=[[0,0],[1.3,0],[2.2,1]]))],'Zero workout videos saved.')
slide('#000000',[stack('The loop',150,260,[txt(v,0,0,1650,146,PINK if i==1 else WHITE,motion=anim(x=[[0,200],[i*.65,200],[1.4+i*.65,0]],opacity=[[0,0],[i*.65,0],[.8+i*.65,1]])) for i,v in enumerate(['One set.','One insight.','Another step.'])],22)],'One set. One insight. Another step.')
slide('#F5F5F7',[label('NEXT',145,150,1000),txt('Real-world reps.',145,345,1660,150,INK,motion=settle(x=80)),txt('Athletes. Trainers. Real devices.',150,660,1600,57,GRAY,'Regular',motion=anim(opacity=[[0,0],[.8,0],[1.8,1]]))],'Real-world reps.')
slide('#000000',[txt('Find your line.',140,325,1640,180,WHITE,align='CENTER',motion=anim(scale=[[0,1.06],[1.5,1]],opacity=[[0,0],[.6,1]])),txt('Finn',140,630,1640,64,WHITE,align='CENTER',motion=anim(opacity=[[0,0],[.7,0],[1.6,1]]))],'Find your line.')
plan['motion_system']='Custom 1.2–2.5s choreography: shared-device position changes, UI detail extraction, clipped reveals, progressive signal, delayed reading holds. No uniform fade-rise preset. Reduce Motion retains static composition.'
plan['typeface']='SF Pro Display outlined from installed Apple fonts; editable SF Pro source retained in Figma.'
for s in sc:
 plan['slides'][s['number']-1]['motion']='Cinematic v2: '+('shared device and extracted actual UI' if any(n['kind']=='group' for n in s['nodes']) else 'purposeful typographic reveal')
# Apply the exact stills verified against the live Figma browser.
fix_path=P/'static-image-fixes.json'
if fix_path.exists():
 fixes={o['key']:o for o in json.loads(fix_path.read_text())}
 def exact_stills(n):
  if n['key'] in fixes:
   f=fixes[n['key']];n.update(x=f['x'],y=f['y'],w=f['w'],h=f['h'],hash=f['hash'],src=str(Path(f['file']).relative_to(R)))
  for c in n.get('children',[]):exact_stills(c)
 for scene in sc:
  for n in scene['nodes']:exact_stills(n)
(P/'cinematic-scenes.json').write_text(json.dumps(sc,ensure_ascii=False));(P/'slide-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2))
# Produce one retry-safe script per slide, keeping under the connector payload cap.
base="""const p=await figma.getNodeByIdAsync('99:2');await figma.setCurrentPageAsync(p);for(const style of ['Regular','Semibold','Bold'])await figma.loadFontAsync({family:'SF Pro',style});const videoSources={};for(const [k,id]of Object.entries({live:'203:2',setup:'203:5',result:'203:4','history-coach':'203:3'}))videoSources[k]=await figma.getNodeByIdAsync(id);const created=[],mutated=[];function paint(h){return [{type:'SOLID',color:figma.util.rgb(h)}]};function motion(n,m){const map={x:'TRANSLATION_X',y:'TRANSLATION_Y',scale:'SCALE_XY',opacity:'OPACITY',width:'WIDTH'};const tracks={};for(const [k,v]of Object.entries(m||{})){let prev=-1;const vals=[];for(const [t,z]of v){if(t===prev)vals[vals.length-1]=[t,z];else vals.push([t,z]);prev=t;}tracks[map[k]]={keyframes:vals.map(([t,z],i)=>({timelinePosition:t,value:k==='scale'?{type:'VECTOR',value:{x:z,y:z}}:{type:'FLOAT',value:z},...(i?{easing:{type:'CUSTOM_CUBIC_BEZIER',easingFunctionCubicBezier:{x1:.22,y1:1,x2:.36,y2:1}}}:{})}))};}n.manualKeyframeTracks=tracks;}
function build(e,parent){let n;if(e.kind==='text'){n=figma.createNodeFromSvg(e.svg);created.push(n.id,...n.findAll().map(q=>q.id));const t=figma.createText();created.push(t.id);t.fontName={family:'SF Pro',style:e.style};t.fontSize=e.size;t.characters=e.text;t.name='Editable SF Pro source · '+e.text;t.visible=false;parent.appendChild(t);}else if(e.kind==='group'){n=e.layout?figma.createAutoLayout('VERTICAL',{itemSpacing:e.gap,fills:[]}):figma.createFrame();created.push(n.id);n.resize(e.w,e.h);n.fills=e.bg?paint(e.bg):[];n.clipsContent=!!e.clip;if(e.radius)n.cornerRadius=e.radius;for(const c of e.children)build(c,n);}else if(e.kind==='image'&&e.video){n=videoSources[e.video].clone();created.push(n.id);n.resize(e.w,e.h);if(e.radius)n.cornerRadius=e.radius;}else{n=figma.createRectangle();created.push(n.id);n.resize(e.w,e.h);n.fills=e.kind==='image'?[{type:'IMAGE',imageHash:e.hash,scaleMode:'FILL'}]:paint(e.color);if(e.radius)n.cornerRadius=e.radius;}parent.appendChild(n);n.name=e.name;n.x=e.x;n.y=e.y;motion(n,e.motion);return n;}
"""
for s in sc:
 code=base+'const spec='+json.dumps(s,ensure_ascii=False,separators=(',',':'))+";const f=await figma.getNodeByIdAsync(spec.id);const old=f.children.slice();for(const n of old){mutated.push(n.id);n.remove();}f.fills=paint(spec.bg);f.name='Keynote '+String(spec.number).padStart(2,'0')+' · '+spec.title;for(const n of spec.nodes)build(n,f);for(const t of f.timelines||[])f.setTimelineDuration(t.id,Math.max(t.duration||0,spec.duration));mutated.push(f.id);return {createdNodeIds:created,mutatedNodeIds:mutated,slide:spec.number,id:f.id,children:f.children.length};"
 (P/f'build-slide-{s["number"]:02}.js').write_text(code)
print('Cinematic compositions prepared:',len(sc),'Largest Figma script:',max((P/f'build-slide-{i:02}.js').stat().st_size for i in range(1,19)))
