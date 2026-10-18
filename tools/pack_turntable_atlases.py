"""Share sixteen existing turntables per material, preserving runtime resolution.

Original 2048-square authoring art remains intact. Each 1024-square runtime
turntable occupies one cell of a 4096 atlas; red vertex color selects the cell.
Run after package_turntables.py and before generate_menus.py.
"""
import json
from pathlib import Path
from PIL import Image
from generate_progression import write_iwi, write_material
from package_preview_atlases import selected_names

ROOT=Path(__file__).resolve().parents[1]


def main(update_bindings=True):
    groups={'tall':[],'wide':[]}
    for group,names in selected_names().items():
        groups[group]=list(dict.fromkeys(name.replace('apx_preview_','apx_turn_').removesuffix('_back') for name in names))
    lookup={}
    size=json.loads((ROOT/'ui/texture_budget.json').read_text())['turntable_size']
    if size!=1024:raise ValueError('Shared turntables currently preserve 1024-square runtime tiles')
    output=ROOT/'art/ui/models/rotation-atlases';output.mkdir(parents=True,exist_ok=True)
    for group,names in groups.items():
        for start in range(0,len(names),16):
            material='apx_rotation_'+group+'_'+str(start//16)
            atlas=Image.new('RGBA',(4096,4096))
            for cell,name in enumerate(names[start:start+16]):
                with Image.open(ROOT/'art/ui/models/turntables'/(name+'.png')) as source:
                    tile=source.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
                    atlas.paste(tile,(cell%4*size,cell//4*size))
                lookup[name]={'material':material,'cell':cell}
            atlas.save(output/(material+'.png'))
            write_iwi(atlas,ROOT/'assets/images'/(material+'.iwi'))
            write_material(material,4096,4096,techset='apx_turntable_'+group)
    (ROOT/'ui/turntable_atlas.json').write_text(json.dumps(lookup,indent=2)+'\n')
    if update_bindings:
        from apply_content_profile import filter_previews
        filter_previews()
    print('Shared',len(lookup),'turntables across',len({v['material'] for v in lookup.values()}),'materials; runtime frame resolution unchanged.')


if __name__=='__main__':main()
