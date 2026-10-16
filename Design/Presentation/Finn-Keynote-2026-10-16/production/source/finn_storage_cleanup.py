from pathlib import Path
import json,subprocess,shutil,hashlib,time
ROOT=Path('/Users/james/Developer/Hackathon');R=ROOT/'Design/Presentation/Finn-Keynote-2026-10-16';K=R/'keynote';out=ROOT/'docs/maintenance';out.mkdir(exist_ok=True)
report=out/'storage-cleanup-2026-10-16.json'
log=json.loads(report.read_text()).get('deleted',[]) if report.exists() else []
def remove(p,why):
 p=Path(p)
 if not p.exists() or p.is_symlink():return
 if p.is_mount():return
 if p.is_dir() and (p/'.git').exists():raise RuntimeError('Repository protected '+str(p))
 kb=int(subprocess.check_output(['du','-sk',str(p)]).split()[0]);log.append({'path':str(p),'allocated_bytes':kb*1024,'reason':why})
 report.write_text(json.dumps({'deleted':log},indent=2))
 if p.is_dir():shutil.rmtree(p)
 else:p.unlink()
# Current native file must have all ten current masters before removing redundant exports.
z=__import__('zipfile').ZipFile(K/'output/Finn-WWDC-5min-Polished.key');hs={hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.endswith('.mp4')}
for i in range(1,11):assert hashlib.sha256((R/'videos/finn-opening-film.mp4' if i==1 else K/f'media/{i:02}.mp4').read_bytes()).hexdigest() in hs
# Retain small unique inputs needed to regenerate the final film, not decoded render caches.
inputs=R/'production/source-inputs';inputs.mkdir(exist_ok=True)
for name in ['finn-keynote-portrait.mp4','finn-keynote-portrait-poses.json','finn-clean-posture-tip.png']:
 p=Path('/tmp')/name
 if p.exists():shutil.copy2(p,inputs/name)
for p in Path('/tmp').glob('finn*'):
 if p.suffix in ['.py','.cjs','.swift'] and p.is_file():shutil.copy2(p,R/'production/source'/p.name)
for p in (R/'production').glob('archive-v*'):remove(p,'Superseded presentation revision')
keep={'Finn-WWDC-5min-Polished.key','Finn-WWDC-5min-Polished.pptx','Finn-WWDC-5min-Playback.mp4'}
for p in (K/'output').iterdir():
 if p.name not in keep:remove(p,'Superseded or duplicate presentation export')
for p in (K/'build').iterdir():
 if p.name=='smooth-native':
  for sub in ['live','setup']:remove(p/sub,'Regenerable native frame export; plates and poses retained')
 elif p.suffix not in ['.mjs','.cjs','.json']:remove(p,'Intermediate presentation render or decoded cache')
for p in [R/'production/film/render',R/'production/film/render-v3',R/'production/film/mix-pre-master.wav',R/'production/film/sound-design.wav']:remove(p,'Superseded film render cache or audio mix')
# Only clearly identified project compilation caches, without source worktrees.
names=['finn-ui-improvements','finn-layered-icon-build','finn-rebrand-derived','finn-icon-consistency-build','finn-keynote-apple-downloads','finn-keynote-watch','finn-backend-watch-derived','finn-backend-derived','finn-audit-dark-dd','finn-ui-full-final','finn-max-capture-build','finn-audit-dd','finn-presentation-build','finn-ui-final-regressions','finn-icon-launch-phone-build','finn-final-release','finn-ui-release','finn-keynote-iphone','finn-ui-next','finn-backend-core-tests','finn-audit-swift-cache']
for n in names:remove(Path('/tmp')/n,'Rebuildable Finn compilation/test cache; no build process running')
# Huge intermediate recordings used only to derive the retained selected clip and finished masters.
for n in ['finn-keynote-camera-take.mov','finn-camera-smooth-take.mov','finn-keynote-demo.mp4','finn-keynote-walkthrough-raw.mp4','finn-keynote-navigation.mp4','finn-clean-result-coach-take.mov']:remove(Path('/tmp')/n,'Superseded capture; selected source and current masters preserved')
for p in Path('/Users/james/Library/Developer/Xcode/DerivedData').glob('Finn-*'):remove(p,'Rebuildable Finn Xcode derived data')
# Remove downloaded film clips only if their bytes match retained project source.
sources={hashlib.sha256(p.read_bytes()).hexdigest() for p in (R/'assets/film').glob('*.mp4')}
for p in Path('/Users/james/Downloads').glob('Man_*.mp4'):
 if hashlib.sha256(p.read_bytes()).hexdigest() in sources:remove(p,'Exact duplicate of retained film source')
(out/'storage-cleanup-2026-10-16.json').write_text(json.dumps({'deleted':log,'allocated_bytes_removed':sum(x['allocated_bytes'] for x in log)},indent=2))
print(json.dumps({'items_removed':len(log),'GiB_removed':round(sum(x['allocated_bytes'] for x in log)/1024**3,2),'report':str(out/'storage-cleanup-2026-10-16.json')}))
