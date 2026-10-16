import sys,json
sys.path.insert(0,'/tmp/finn-font-tools')
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
f=TTFont('/Users/james/Library/Fonts/SF-Pro.ttf');print([(a.axisTag,a.minValue,a.defaultValue,a.maxValue) for a in f['fvar'].axes])
results=[]
for text,size,weight,w,h in [('Finn',15,590,235.6667,17.5),('It’s time for training.',15,400,309.6667,17.5)]:
 ff=TTFont('/Users/james/Library/Fonts/SF-Pro-Text-'+('Semibold' if weight>500 else 'Regular')+'.otf');gs=ff.getGlyphSet();cm=ff.getBestCmap();sc=size/ff['head'].unitsPerEm;pen=SVGPathPen(gs);xx=0;baseline=14
 for ch in text:
  gl=gs[cm[ord(ch)]];gl.draw(TransformPen(pen,(sc,0,0,-sc,xx,baseline)));xx+=gl.width*sc-.23
 results.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><path fill="white" d="{pen.getCommands()}"/></svg>')
open('/tmp/finn-notification-type.json','w').write(json.dumps(results))
