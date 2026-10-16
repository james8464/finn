from pathlib import Path
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote'
import shutil
A=R/'production/archive-v6';A.mkdir(exist_ok=True)
for p in [R/'videos/finn-opening-film.mp4',*list((K/'output').glob('*'))]:
 if p.is_file() and not (A/p.name).exists():shutil.copy2(p,A/p.name)
s=Path('/tmp/finn_film_v6.py').read_text()
s=s.replace("edit-decision-list-v6.json","edit-decision-list-v7.json").replace('film-v6','film-v7').replace('V6','V7')
pos=s.index('def render(t):')
s=s[:pos]+'''# A single visual owner: clean device screens beneath one continuous coaching card.
watch_clean=watch_screen.copy()
ImageDraw.Draw(watch_clean).rectangle((95,188,321,240),fill='black')
# Retain the native phone cue glyphs. The pill dissolves while its text becomes Watch white.
ca=np.asarray(cue.convert('L'));mask=np.zeros(ca.shape,dtype=np.uint8)
mask[45:185,180:1000]=255-ca[45:185,180:1000]
glyph=Image.fromarray(mask)
bbox=glyph.getbbox();print('Native cue glyph bounds',bbox,flush=True)
def travelling_cue(im,x,y,w,alpha=1,morph=0):
 h=round(230*w/1176);size=(max(1,round(w)),max(1,h));card=Image.new('RGBA',size)
 plate=rounded(Image.new('RGBA',size,(255,255,255,round(255*(1-morph)))),round(w*.043))
 card.alpha_composite(plate)
 ink=Image.new('RGBA',size,(round(255*morph),)*3+(255,))
 ink.putalpha(glyph.resize(size,Image.Resampling.LANCZOS));card.alpha_composite(ink)
 over(im,card,(x,y),alpha,round(14*(1-morph)))
''' +s[pos:]
a=s.index('  if u>2.1:');b=s.index('  phone(im,screen',a)
s=s[:a]+s[b:]
s=s.replace("q=ease((u-4.2)/1.8);tip(im,(790-480*(1-q),475-170*(1-q)),870-500*(1-q),q)","q=ease((u-4.2)/1.8);travelling_cue(im,240.57+(790-240.57)*q,295.41+(475-295.41)*q,364.56+(870-364.56)*q,ease((u-2.1)/.55))")
s=s.replace("screen=source('smooth-live',4.04).resize((1320,2868),Image.Resampling.LANCZOS);layer=rounded(cue.resize((1176,230),Image.Resampling.LANCZOS),50);over(screen,layer,(72,645))","screen=source('smooth-live',4.04).resize((1320,2868),Image.Resampling.LANCZOS)")
s=s.replace("  if u<1.7:tip(im,(790+285*p,475-30*p),870-520*p,1-p)\n  watch(im,watch_screen,1230-190*p,210-160*p,760+170*p,p)","  watch(im,watch_clean,1230-190*p,210-160*p,760+170*p,p)\n  q=ease(u/2.2);m=ease((u-1.15)/1.05)\n  # Match the original Watch cue width and baseline without ever showing a second label.\n  gw=bbox[2]-bbox[0];endw=156*(930/880)*1176/gw\n  ex=1040+72*(930/880)+208*(930/880)-(bbox[0]+gw/2)*endw/1176\n  ey=50+(192+213.5)*(930/880)-(bbox[1]+(bbox[3]-bbox[1])/2)*endw/1176\n  travelling_cue(im,790+(ex-790)*q,475+(ey-475)*q,870+(endw-870)*q,1,m)")
s=s.replace("times=[.4,1.3,2.2,4.3,7.4,8.8,11.3,13.8,16,19,23.7,27.6,29.7,33.7,40.8,47,52.5,57.7]","times=[13.8,28.7,30.2,30.7,31.4,32.2,37.8,38.5,39.2,39.8,40.3,43]")
Path('/tmp/finn_film_v7.py').write_text(s)
# Slide 6: the single external card first occupies the exact former in-phone position.
s=Path('/tmp/finn_revision5.py').read_text().replace(";p['children'][0]['overlay_cue']=True",'')
s=s.replace("'opacity':show(5.8,6)","'opacity':show(4,4.7)")
# scaling is centred by renderer: x=810-823+267.75=254.75; y=625-378+52.36=299.36.
# Exact native screen inset yields x255.57 y295.41; adjust for that geometry.
s=s.replace('[0,-823],[5.8,-823]','[0,-822.18],[5.8,-822.18]').replace('[0,-378],[5.8,-378]','[0,-381.95],[5.8,-381.95]')
Path('/tmp/finn_revision7.py').write_text(s)
with (K/'REVISION-TODO.md').open('a') as f:f.write('\n## Notification and cue continuity\n\n- [ ] Export Apple’s actual notification component with Finn identity.\n- [ ] One tip travels from phone → presentation → Watch in film and deck.\n- [ ] Rebuild and verify native Keynote and five-minute backup.\n')
print('Archived V6 and prepared single-owner cue animation')
