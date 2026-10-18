"""Share still-preview materials without reducing the original cell resolution.

Eight 512x1024 portraits or 1024x512 prop renders per 2048-square atlas.
The menu chooses a cell through a constant vertex red channel; the shader
preserves normal tint/alpha and the UI's normal visibility/fade lifecycle.
"""
import csv
import json
from pathlib import Path
from PIL import Image
from generate_progression import write_iwi,write_material

ROOT=Path(__file__).resolve().parents[1]


def selected_names():
    names={'tall':[],'wide':[]};hands=set()
    for kind,table in [('character','characterTable'),('weapon','itemTable'),('knife','knifeTable')]:
        for row in csv.reader((ROOT/'src/mp'/(table+'.csv')).read_text().splitlines()):
            if not row or row[8]=='0': continue
            group='tall' if kind=='character' else 'wide'
            names[group].append('apx_preview_'+kind+'_'+row[1])
            if kind=='character':
                names[group].append('apx_preview_character_'+row[1]+'_back');hands.add(row[5])
    gloves=json.loads((ROOT/'ui/glove_catalog.json').read_text())
    names['wide'] += ['apx_preview_gloves_'+str(gloves[hand]) for hand in sorted(hands)]
    return names


def main():
    output=ROOT/'art/ui/models/still-atlases';output.mkdir(parents=True,exist_ok=True)
    lookup={}
    for group,names in selected_names().items():
        width,height,columns=(512,1024,4) if group=='tall' else (1024,512,2)
        for start in range(0,len(names),8):
            name='apx_still_'+group+'_'+str(start//8)
            atlas=Image.new('RGBA',(2048,2048))
            for cell,source in enumerate(names[start:start+8]):
                with Image.open(ROOT/'art/ui/models'/(source+'.png')) as image:
                    if image.size!=(width,height): raise ValueError('Unexpected source preview dimensions: '+source)
                    atlas.paste(image,(cell%columns*width,cell//columns*height))
                lookup[source]={'material':name,'cell':cell,'size':[width,height]}
            atlas.save(output/(name+'.png'))
            write_iwi(atlas,ROOT/'assets/images'/(name+'.iwi'))
            write_material(name,2048,2048,techset='apx_preview_'+group)
    (ROOT/'ui/preview_atlas.json').write_text(json.dumps(lookup,indent=2)+'\n')
    from apply_content_profile import filter_previews
    filter_previews()
    print('Packed',len(lookup),'full-resolution stills into',len({v['material'] for v in lookup.values()}),'shared materials')


if __name__=='__main__': main()
