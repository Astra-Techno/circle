"""Component comparisons; photo/avatar content is explicitly masked, not scored."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageEnhance, ImageDraw, ImageOps

parser = argparse.ArgumentParser()
parser.add_argument('stage')
parser.add_argument('component', choices=['header', 'composer', 'quick', 'cards', 'actions', 'dock', 'final'])
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = root / 'docs/design-previews/home-refinement'
ref = Image.open(root / 'mobile/design_reference/home_feed.png').convert('RGB').resize((393, 852), Image.Resampling.LANCZOS)
actual = Image.open(out / f'{args.stage}.png').convert('RGB')
(out / 'stages').mkdir(parents=True, exist_ok=True)
if args.component == 'final':
    ref.save(out / 'reference-normalized.png')
    Image.blend(ref, actual, 0.5).save(out / 'overlay-unmasked.png')
geometry = json.loads((out / f'{args.stage}.json').read_text())
# Each mask is the union of actual and reference content bounds. Geometry is
# measured separately in JSON; masking does not establish geometric acceptance.
masks = [(0,0,393,24), (0,835,393,852), (16,80,58,139), (16,208,60,266), (0,456,393,776)]
media = geometry.get('media')
masks.append((20,270,374,396))
if media:
    masks.append((media['x'],media['y'],media['x']+media['width'],media['y']+media['height']))
regions = {'header':(8,24,389,82),'composer':(8,80,389,139),'quick':(8,136,389,198),'cards':(0,196,393,580),'actions':(8,400,385,580),'dock':(8,760,385,835),'final':(0,24,393,835)}
for im in (ref, actual):
    draw = ImageDraw.Draw(im)
    for box in masks: draw.rectangle(box, fill=(235,235,235))
box=regions[args.component]
r,a=ref.crop(box),actual.crop(box)
Image.blend(r,a,0.5).save(out/'stages'/f'{args.stage}-overlay.png')
ImageEnhance.Brightness(ImageChops.difference(r,a)).enhance(4).save(out/'stages'/f'{args.stage}-difference.png')
if args.component == 'final':
    difference = Image.open(out / 'stages' / f'{args.stage}-difference.png').convert('L')
    ImageOps.colorize(difference, black='#101020', mid='#dc3545', white='#fff4a3').save(out / 'heatmap.png')
print(f'{args.stage}: real normalized {args.component} crop; content masks applied; no layout acceptance inferred from pixel percentage')
