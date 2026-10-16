import json,subprocess
from pathlib import Path
repo='james8464/finn';data=json.load(open('/tmp/finn-cleanup-github-artifacts.json'))['artifacts'];keep=[];delete=[];counts={};active={'main','finn/backend-reliability','finn/interface-review','finn/onboarding'}
for a in data:
 branch=a['workflow_run']['head_branch'];n=counts.get(branch,0)
 if a['name'] not in ['plumb-test-report','finn-test-report']:keep.append(a);continue
 if branch in active and n<(2 if branch=='main' else 1):keep.append(a);counts[branch]=n+1
 else:delete.append(a)
report={'retained':[{'id':a['id'],'branch':a['workflow_run']['head_branch'],'name':a['name']} for a in keep],'deleted':[],'bytes_removed':0}
p=Path('/Users/james/Developer/Hackathon/docs/maintenance/github-storage-cleanup-2026-10-16.json')
for a in delete:
 r=subprocess.run(['gh','api','-X','DELETE',f'repos/{repo}/actions/artifacts/{a["id"]}'],capture_output=True,text=True)
 if r.returncode:print('FAILED',a['id'],r.stderr);continue
 report['deleted'].append({'id':a['id'],'name':a['name'],'bytes':a['size_in_bytes']});report['bytes_removed']+=a['size_in_bytes'];p.write_text(json.dumps(report,indent=2))
print(json.dumps({'deleted':len(report['deleted']),'retained':len(keep),'GiB_removed':round(report['bytes_removed']/2**30,2)}))
