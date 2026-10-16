from pathlib import Path
import zipfile,json,xml.etree.ElementTree as E
R=Path('/Users/james/Developer/Hackathon/Design/Presentation/Finn-Keynote-2026-10-16');K=R/'keynote';S=json.loads((K/'five-minute-scenes.json').read_text())
P='http://schemas.openxmlformats.org/presentationml/2006/main';A='http://schemas.openxmlformats.org/drawingml/2006/main';REL='http://schemas.openxmlformats.org/officeDocument/2006/relationships';PKG='http://schemas.openxmlformats.org/package/2006/relationships';P14='http://schemas.microsoft.com/office/powerpoint/2010/main'
for k,v in [('p',P),('a',A),('r',REL),('p14',P14)]:E.register_namespace(k,v)
def tag(ns,k):return '{'+ns+'}'+k
def add(p,ns,k,attrs={}):return E.SubElement(p,tag(ns,k),attrs)
with zipfile.ZipFile(K/'build/base.pptx') as z:files={n:z.read(n) for n in z.namelist()}
for s in S:
 i=s['number'];key=f'{i:02}';slide=E.fromstring(files[f'ppt/slides/slide{i}.xml']);rels=E.fromstring(files[f'ppt/slides/_rels/slide{i}.xml.rels']);pic=slide.find('.//'+tag(P,'pic'));nv=pic.find(tag(P,'nvPicPr'));prop=nv.find(tag(P,'cNvPr'));prop.set('name',s['title']+' — embedded motion movie');add(prop,A,'hlinkClick',{'action':'ppaction://media'})
 app=nv.find(tag(P,'nvPr'));add(app,A,'videoFile',{tag(REL,'link'):'rVideo'});ext=add(add(app,P,'extLst'),P,'ext',{'uri':'{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}'});add(ext,P14,'media',{tag(REL,'embed'):'rMedia'})
 for rid,kind in [('rVideo',REL+'/video'),('rMedia','http://schemas.microsoft.com/office/2007/relationships/media')]:add(rels,PKG,'Relationship',{'Id':rid,'Type':kind,'Target':f'../media/motion-{key}.mp4'})
 # The poster points at a genuine embedded PNG. Artifact export uses absolute package targets.
 image_rel=next(x for x in rels if x.attrib.get('Type')==REL+'/image');imgpath=image_rel.get('Target').lstrip('/');files[imgpath]=(K/f'preview/{key}.png').read_bytes()
 transition=E.Element(tag(P,'transition'),{'advClick':'1','advTm':str(s['seconds']*1000)});slide.append(transition)
 timing=add(slide,P,'timing');lst=add(timing,P,'tnLst');par=add(lst,P,'par');root=add(par,P,'cTn',{'id':'1','dur':'indefinite','restart':'never','nodeType':'tmRoot'});child=add(root,P,'childTnLst');video=add(child,P,'video');media=add(video,P,'cMediaNode',{'vol':'100000' if i==1 else '0'});ctn=add(media,P,'cTn',{'id':'2','fill':'hold','display':'0'});add(add(ctn,P,'stCondLst'),P,'cond',{'delay':'0'});target=add(media,P,'tgtEl');add(target,P,'spTgt',{'spid':prop.get('id')})
 files[f'ppt/slides/slide{i}.xml']=E.tostring(slide,encoding='utf-8',xml_declaration=True);files[f'ppt/slides/_rels/slide{i}.xml.rels']=E.tostring(rels,encoding='utf-8',xml_declaration=True)
files['[Content_Types].xml']=files['[Content_Types].xml'].replace(b'</Types>',b'<Default Extension="mp4" ContentType="video/mp4"/></Types>')

# SF Pro is installed locally and is also used for the outlined audience-facing text.
for name in files:
 if name.endswith('.xml'):files[name]=files[name].replace(b'typeface="Aptos"',b'typeface="SF Pro Display"')
out=K/'build/Finn-Five-Minutes-motion.pptx'
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
 for name,data in files.items():z.writestr(name,data)
 for s in S:
  key=f'{s["number"]:02}';src=R/'videos/finn-opening-film.mp4' if s['number']==1 else K/f'media/{key}.mp4';z.write(src,f'ppt/media/motion-{key}.mp4')
print(out)
