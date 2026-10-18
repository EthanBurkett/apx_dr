"""Share sixteen existing turntables per material, preserving runtime resolution.

Original 2048-square authoring art remains intact. Each 1024-square runtime
turntable occupies one cell of a logical 4096 atlas; red selects the cell.
Four 2048-square texture pages share one material so each IWI fits the official
client's 6 MiB image-loader scratch buffer, without losing frame resolution.
Run after package_turntables.py and before generate_menus.py.
"""
import json
import struct
from pathlib import Path
from PIL import Image
from generate_progression import write_iwi, write_material
from package_preview_atlases import selected_names

ROOT=Path(__file__).resolve().parents[1]


def page_names(material):
    return [material]+[material+'_page'+str(page) for page in range(1,4)]


def write_paged_material(material,group):
    write_material(material,2048,2048,techset='apx_turntable_'+group)
    path=ROOT/'assets/materials'/material
    data=bytearray(path.read_bytes())
    old_table=struct.unpack_from('<I',data,56)[0]
    flags=struct.unpack_from('<I',data,old_table+4)[0]
    descriptors=[]
    for index,image in enumerate(page_names(material)):
        semantic='colorMap' if index==0 else 'page'+str(index)+'Map'
        semantic_offset=len(data);data.extend(semantic.encode()+b'\0')
        image_offset=len(data);data.extend(image.encode()+b'\0')
        descriptors.append((semantic_offset,flags,image_offset))
    struct.pack_into('<I',data,56,len(data));data[48]=len(descriptors)
    for descriptor in descriptors:data.extend(struct.pack('<III',*descriptor))
    path.write_bytes(data)


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
            for page,name in enumerate(page_names(material)):
                x=page%2*2048;y=page//2*2048
                write_iwi(atlas.crop((x,y,x+2048,y+2048)),ROOT/'assets/images'/(name+'.iwi'))
            write_paged_material(material,group)
    (ROOT/'ui/turntable_atlas.json').write_text(json.dumps(lookup,indent=2)+'\n')
    if update_bindings:
        from apply_content_profile import filter_previews
        filter_previews()
    print('Shared',len(lookup),'turntables across',len({v['material'] for v in lookup.values()}),'four-page materials; runtime frame resolution unchanged.')


if __name__=='__main__':main()
