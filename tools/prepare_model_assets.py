"""Prepare a read-only asset view and actual-model render jobs from the SDK.

Model data uses hardlinks; renderers must never write into this view. Only
textures referenced by the selected models are extracted from installed IWDs.
"""
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import zipfile

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parent.parent
WORK=ROOT/'build/model-render'
ASSET=WORK/'assets'


def rows(name):
    return [r for r in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if r]


def strings(path):
    return [s.decode('ascii') for s in re.findall(rb'[\x20-\x7e]{3,}',path.read_bytes())]


def main():
    ASSET.mkdir(parents=True,exist_ok=True)
    files={}
    for base in (GAME/'raw',ROOT/'assets'):
        for folder in ('xmodel','xmodelparts','xmodelsurfs','materials','images'):
            for path in (base/folder).glob('*'):
                if path.is_file(): files[folder+'/'+path.name]=path
    linked=0
    optimization=ROOT/'ui/texture_optimization.json'
    originals=json.loads(optimization.read_text()) if optimization.exists() else {}
    for relative,path in files.items():
        record=originals.get(path.name) if relative.startswith('images/') else None
        if record and hashlib.sha256(path.read_bytes()).hexdigest()==record['outputSHA256']:
            original=ROOT/'art/source-images'/(record['originalSHA256']+'.iwi')
            if not original.is_file():
                original=ROOT/'build/content-original-images'/(record['originalSHA256']+'.iwi')
            if not original.is_file() or hashlib.sha256(original.read_bytes()).hexdigest()!=record['originalSHA256']:
                raise ValueError('Missing or damaged original authoring texture: '+path.name)
            path=original
        dest=ASSET/relative
        dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():
            if os.path.samefile(dest,path): continue
            dest.unlink()
        os.link(path,dest); linked+=1
    jobs=[]
    for row in rows('characterTable.csv'):
        if row[8]=='0': continue
        jobs.append({'key':'character:'+row[1],'model':row[4],'category':'character','id':int(row[1]),'label':row[6]})
    equipment=[('weapon',row) for row in rows('itemTable.csv')]+[('knife',row) for row in rows('knifeTable.csv')]
    for category,row in equipment:
        if len(row)>8 and row[8]=='0': continue
        name=row[4]+'_mp'
        path=ROOT/'src/weapons/mp'/name
        if not path.exists(): path=GAME/'raw/weapons/mp'/name
        if path.exists(): weapon_source=path.read_text()
        else:
            weapon_source=None
            for archive_path in sorted((GAME/'main').glob('*.iwd')):
                with zipfile.ZipFile(archive_path) as archive:
                    entry='weapons/mp/'+name
                    if entry in archive.namelist(): weapon_source=archive.read(entry).decode('latin1')
            if weapon_source is None: raise FileNotFoundError(name)
        parts=weapon_source.split('\\')
        definition=dict(zip(parts[1::2],parts[2::2]))
        model=definition.get('worldModel') or definition.get('worldModel0')
        if category=='knife' and row[1]=='0' and not model: model='weapon_parabolic_knife'
        if not model: raise ValueError('Missing world model: '+name)
        jobs.append({'key':category+':'+row[1],'model':model,'category':category,'id':int(row[1]),'label':row[5]})
    registry_path=ROOT/'ui/glove_catalog.json'
    if registry_path.exists(): registry=json.loads(registry_path.read_text())
    else:
        original=json.loads((ROOT/'art/ui/models/catalog.json').read_text())
        registry={job['model']:job['id'] for job in original if job['category']=='gloves'}
    for name in sorted({r[5] for r in rows('characterTable.csv') if r[8]!='0'}):
        if name not in registry: registry[name]=max(registry.values(),default=-1)+1
        jobs.append({'key':'gloves:'+name,'model':name,'category':'gloves','id':registry[name],'label':name})
    registry_path.write_text(json.dumps(registry,indent=2)+'\n')
    textures=set()
    for job in jobs:
        model=ASSET/'xmodel'/job['model']
        if not model.exists(): raise FileNotFoundError(model)
        materials=[ASSET/'materials'/s for s in strings(model) if (ASSET/'materials'/s).is_file()]
        for material in materials:
            for string in strings(material):
                textures.add('images/'+string+'.iwi')
    archives=[zipfile.ZipFile(p) for p in sorted((GAME/'main').glob('*.iwd'))]
    extracted=0
    try:
        entries={name.lower():(archive,name) for archive in archives for name in archive.namelist()}
        for texture in sorted(textures):
            target=ASSET/texture
            if target.exists(): continue
            entry=entries.get(texture.lower())
            if entry:
                target.write_bytes(entry[0].read(entry[1])); extracted+=1
    finally:
        for archive in archives: archive.close()
    (WORK/'jobs.json').write_text(json.dumps(jobs,indent=2))
    print(f'Prepared {len(jobs)} actual models; {linked} read-only source links; {extracted} required IWD textures.')


if __name__=='__main__': main()
