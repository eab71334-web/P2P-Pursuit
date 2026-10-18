import sys
from PIL import Image
ids=sys.argv[1:]
W=Image.new('RGB',(1440,270*len(ids)))
for r,i in enumerate(ids):
    for k in (1,2,3):
        im=Image.open('/tmp/shots/car_%s_%d.png'%(i,k)).resize((480,270))
        W.paste(im,((k-1)*480,r*270))
W.save('/tmp/shots/cars_m.png')
