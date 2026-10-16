from pathlib import Path
import shutil
root=Path('/Users/james/Developer/Hackathon')
source=Path('/tmp/finn-ui-dark-final')
design=root/'docs/design/screenshots/finn'
for old in design.glob('*.png'):
    image=source/old.name
    if not image.exists(): raise RuntimeError(f'Missing final capture: {image}')
    shutil.copy2(image,old)
review=design/'review'
review.mkdir(exist_ok=True)
for pattern in ('*-dark.png','*-largest-text*.png','*-demo-saved-set.png','privacy-camera-details.png'):
    for image in source.glob(pattern): shutil.copy2(image,review/image.name)
release=root/'docs/release/screenshots'
for number,name in [(1,'00-home'),(2,'06-choix-exercice-pompes'),(3,'07d-choix-exercice-tractions'),(4,'03-premier-lancement-avant-camera'),(5,'12-options'),(6,'13-confidentialite')]:
    target=list(release.glob(f'iphone-6.9-1320x2868-{number:02}-*.png'))
    assert len(target)==1
    shutil.copy2(source/(name+'.png'),target[0])
for target,name in [('accueil-apres-serie','15-accueil-apres-une-serie'),('resultat','10-resultat'),('resultat-bas','11-resultat-bas'),('serie-en-cours','09-serie-en-cours')]:
    shutil.copy2(source/(name+'.png'),release/'simulateur-demo'/f'iphone-6.9-1320x2868-{target}-DEMO.png')
print('Updated design and release screenshots with final simulator captures.')
