"""Replace screenshot image blobs and their SHA-1 refs; preserve the editable Kiwi document."""
import datetime, hashlib, json, pathlib, struct, zipfile
from compression import zstd
root=pathlib.Path('/Users/james/Developer/Hackathon')
source=pathlib.Path('/tmp/finn-ui-dark-final')
old_source=source
mapping={
 '6a2131647c74eced2d57111c9e575db1d42a4e10':old_source/'01-premier-lancement-accueil.png',
 '6f73068e90ccdd5415001b025ab000303a39139d':old_source/'06-choix-exercice-pompes.png',
 '97cfe98d8e89d2cf2122d5e7f4f1a09642a122d7':old_source/'07d-choix-exercice-tractions.png',
 '0f09b7dd9d59f91415d62af643d04478dff773e0':source/'13-confidentialite.png',
 '91da982f5b347ceb1183f4a93998ec4c7f5d4d78':source/'coach-demo-saved-set.png',
 '1fd0dd0973b317a615bfde9f897442315f4569c2':source/'history-demo-saved-set.png',
 '2b1770568ae279284af62cd42f7aea79b1d634ed':source/'10-resultat.png',
 'fd30a22be4579ecc20eb6f98b7a6aff3a58f3552':source/'09-serie-en-cours.png',
}
path=root/'Design/Finn — Brand Theme.fig'
with zipfile.ZipFile(path) as z: files={n:z.read(n) for n in z.namelist()}
canvas=files['canvas.fig'];offset=12;chunks=[]
while offset<len(canvas):
 size=struct.unpack_from('<I',canvas,offset)[0];offset+=4
 chunks.append(canvas[offset:offset+size]);offset+=size
assert len(chunks)==2
raw=zstd.decompress(chunks[1])
for old,png in mapping.items():
 image=png.read_bytes();new=hashlib.sha1(image).hexdigest()
 oldref=bytes.fromhex(old);assert oldref in raw,old
 raw=raw.replace(oldref,bytes.fromhex(new))
 del files['images/'+old];files['images/'+new]=image
chunks[1]=zstd.compress(raw)
files['canvas.fig']=canvas[:12]+b''.join(struct.pack('<I',len(c))+c for c in chunks)
meta=json.loads(files['meta.json']);meta['exported_at']=datetime.datetime.now(datetime.timezone.utc).isoformat()
files['meta.json']=json.dumps(meta,separators=(',',':')).encode()
assert b'plumb' not in raw.lower()
for name,data in files.items():
 if name.startswith('images/') and len(name)>7:
  assert hashlib.sha1(data).hexdigest()==name[7:]
  assert bytes.fromhex(name[7:]) in raw
backup=pathlib.Path('/tmp/finn-figma-before-ui-refresh.fig');backup.write_bytes(path.read_bytes())
with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
 for name,data in files.items():z.writestr(name,data)
with zipfile.ZipFile(path) as z:assert z.testzip() is None
print('Refreshed 8 screenshot assets; validated archive and every image reference.')
