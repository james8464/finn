from pathlib import Path
import json
r=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');sc=json.loads((r/'production/cinematic-scenes.json').read_text());hashes={'live':'af6a16e4928e18559ffe683dd01a08394cb470fc','setup':'b0e894175ec534ccc2682dcec89bfb26b07cb41d','result':'7866b7f1cb6d78a8ce3126c08a806c592d970ef2','history-coach':'98a348c5272476570d2ac4b0ade3d3a36208eae7'}
ops=[]
def walk(n,path):
 if n.get('video'):ops.append({'frame':s['id'],'path':path+[n['name']],'source':{'live':'203:2','setup':'203:5','result':'203:4','history-coach':'203:3'}[n['video']]})
 for c in n.get('children',[]):walk(c,path+[n['name']])
for s in sc:
 for n in s['nodes']:walk(n,[])
code="const p=await figma.getNodeByIdAsync('99:2');await figma.setCurrentPageAsync(p);const mutated=[];for(const op of "+json.dumps(ops)+"){let n=await figma.getNodeByIdAsync(op.frame);for(const name of op.path)n=n.children.find(c=>c.name===name);if(n.fills.some(f=>f.type==='VIDEO'))continue;const src=await figma.getNodeByIdAsync(op.source);const v=src.clone();const par=n.parent;par.insertChild(par.children.indexOf(n),v);v.x=n.x;v.y=n.y;v.resize(n.width,n.height);v.cornerRadius=n.cornerRadius;v.name=n.name;mutated.push(v.id,n.id,par.id);n.remove();}const lib=await figma.getNodeByIdAsync('181:2');for(const [i,id]of ['203:2','203:3','203:4','203:5'].entries()){const n=await figma.getNodeByIdAsync(id);lib.appendChild(n);n.resize(220,478);n.x=i*250;n.y=900;n.name='Native video source · '+n.name;mutated.push(n.id);}for(const id of "+json.dumps([s['id'] for s in sc])+"){const f=await figma.getNodeByIdAsync(id);const reactions=f.reactions.map(r=>({...r,actions:r.actions.map(a=>a.type==='NODE'?{...a,resetVideoPosition:true,transition:{type:'SMART_ANIMATE',easing:{type:'EASE_OUT'},duration:1}}:a)}));await f.setReactionsAsync(reactions);mutated.push(id);}return {mutatedNodeIds:mutated};"
(r/'production/attach-videos.js').write_text(code);(r/'production/native-videos.json').write_text(json.dumps(hashes,indent=2))
