"""Package original studio PNGs as GPU-compressed previews and lookup tables."""
import csv
import json
from pathlib import Path
from PIL import Image
from generate_progression import write_iwi, write_material

ROOT=Path(__file__).resolve().parents[1]

def main():
    budget=json.loads((ROOT/'ui/texture_budget.json').read_text())
    report=ROOT/'art/ui/models/catalog.json'
    current=ROOT/'build/model-render/rendered.json'
    if current.exists():
        rendered=json.loads(current.read_text())
        planned=json.loads((ROOT/'build/model-render/jobs.json').read_text())
        keys={job['key'] for job in planned}
        rendered=[job for job in rendered if job['key'] in keys]
        expected=sum(2 if job['category']=='character' else 1 for job in planned)
        if len(rendered)!=expected: raise ValueError('Render report is partial; run the full catalog before packaging.')
        report.write_bytes(current.read_bytes())
    jobs=json.loads(report.read_text())
    expected=[]
    for row in jobs:
        name=row['name']; png=ROOT/'art/ui/models'/(name+'.png')
        if not png.exists(): raise FileNotFoundError(png)
        with Image.open(png) as image:
            image=image.convert('RGBA')
            write_iwi(image,ROOT/'assets/images'/(name+'.iwi'),encoding=budget['preview_encoding'])
            write_material(name,*image.size)
        expected.append('material,'+name)
    (ROOT/'manifests/14-model-previews.csv').write_text('// Actual meshes rendered offline; DXT5 runtime copies, original PNGs retained.\n'+'\n'.join(expected)+'\n')
    gloves={job['model']:job['name'] for job in jobs if job['category']=='gloves'}
    rows=list(csv.reader((ROOT/'src/mp/characterTable.csv').read_text().splitlines()))
    lines=[]
    for row in rows:
        if not row: continue
        id=row[1] if row[8]!='0' else '0'
        lines.append(','.join([row[1],'apx_preview_character_'+id,'apx_preview_character_'+id+'_back',gloves[row[5]],gloves[row[5]].replace('apx_preview_','apx_turn_'),'apx_turn_character_'+id]))
    (ROOT/'src/mp/apx_character_previews.csv').write_text('\n'.join(lines)+'\n')
    weapons={str(job['id']):job['name'] for job in jobs if job['category']=='weapon'}
    (ROOT/'src/mp/apx_weapon_previews.csv').write_text('\n'.join(row[1]+','+weapons.get(row[1],'apx_preview_weapon_0') for row in csv.reader((ROOT/'src/mp/itemTable.csv').read_text().splitlines()) if row)+'\n')
    path=ROOT/'manifests/04-tables.csv'; lines=path.read_text().splitlines()
    for name in ['apx_character_previews','apx_weapon_previews']:
        entry='stringtable,mp/'+name+'.csv'
        if entry not in lines: lines.append(entry)
    path.write_text('\n'.join(lines)+'\n')
    if (ROOT/'ui/content_profile.json').exists():
        from package_preview_atlases import main as package_atlases
        package_atlases()
    print(f'Packaged {len(jobs)} real model previews and two lookup tables.')

if __name__=='__main__': main()
