"""Resolve SDK-reported community dependencies, quarantine incomplete entries.

Never substitute arbitrary models/materials to hide errors. Unavailable IDs stay
reserved with safe base references; their original provenance remains in JSON.
"""
import argparse
import csv
import json
from pathlib import Path
import re
import shutil
from import_content import Pack,ROOT,ASSETS,STAGE,existing

def rows(name): return [r for r in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if r]
def fields(path):
    values=path.read_text(encoding='latin1').split('\\')
    return dict(zip(values[1::2],values[2::2]))
def save_weapon(path,d): path.write_text('WEAPONFILE'+''.join('\\'+k+'\\'+v for k,v in d.items()),encoding='latin1')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('log'); args=parser.parse_args()
    log=Path(args.log).read_text(); specpath=ROOT/'ui/content_catalog.json'; spec=json.loads(specpath.read_text())
    entries=spec['entries']; records=[json.loads(p.read_text()) for p in sorted(STAGE.glob('*/stage.json'),reverse=True)]
    owners={r['id']:r for r in records}; missing=set()
    missing.update('materials/'+n for n in re.findall(r"Couldn't find material '([^']+)'",log))
    missing.update(n for n in re.findall(r"image '([^']+)' is missing",log))
    missing.update('fx/'+n for n in re.findall(r'(?:^|\n)fx/(\S+\.efx) not found',log))
    unresolved=[]
    for key in sorted(missing):
        if existing(key): continue
        candidates=[r for r in records if key.lower() in {k.lower() for k in r['files']}]
        found=False
        for record in candidates:
            try:
                pack=Pack(record); pack.add(key); pack.copy()
                print('Recovered dependency',key,'from',record['name'],flush=True)
                spec.setdefault('shared_dependencies',[]).append({'asset':key,'pack':record['id'],'page':record['page'],'author':record['author']})
                found=True; break
            except ValueError: continue
        if not found: unresolved.append(key)
    # Repair data-only portability problems shared by otherwise valid packs.
    for entry in entries:
        if entry['category']!='weapon': continue
        path=ROOT/'src/weapons/mp'/entry['weapon']; d=fields(path)
        d['displayName']=entry['name'].replace('"','').replace('\\','')
        for key in d:
            if 'rumble' in key.lower(): d[key]=''
        save_weapon(path,d)
    seen=set()
    for path in sorted((ASSETS/'soundaliases').glob('apxc_*.csv')):
        data=list(csv.reader(path.read_text(encoding='utf8',errors='replace').splitlines()))
        if not data: continue
        output=[data[0]]
        for row in data[1:]:
            if not row or not row[0]: continue
            identity=(row[0].lower(),row[1] if len(row)>1 else '')
            if identity in seen: continue
            seen.add(identity); output.append(row)
        with path.open('w',newline='',encoding='utf8') as handle: csv.writer(handle,lineterminator='\n').writerows(output)
    weapons=rows('itemTable.csv'); characters=rows('characterTable.csv')
    knives=rows('knifeTable.csv') if (ROOT/'src/mp/knifeTable.csv').exists() else []
    model_paths={p.name.lower():p for p in (ASSETS/'xmodel').glob('*') if p.is_file()}
    bad_models={name for name,path in model_paths.items() if any(key.startswith('materials/') and key.split('/',1)[1].encode()+b'\0' in path.read_bytes() for key in unresolved)}
    bad_materials={path.name.lower() for path in (ASSETS/'materials').glob('*') if path.is_file() and any(key.startswith('images/') and key.split('/',1)[1].removesuffix('.iwi').encode()+b'\0' in path.read_bytes() for key in unresolved)}
    bad_models.update(name for name,path in model_paths.items() if any(mat.encode()+b'\0' in path.read_bytes() for mat in bad_materials))
    for entry in entries:
        if entry.get('moved_to'): continue
        reason=entry.get('quarantined')
        if entry['category']=='character':
            if entry['model'].lower() in bad_models or entry['hands'].lower() in bad_models: reason='Incomplete model dependencies'
        else:
            d=fields(ROOT/'src/weapons/mp'/entry['weapon'])
            if any(value.lower() in bad_models for key,value in d.items() if key.endswith('Model')): reason='Incomplete weapon model dependencies'
            if any(key.startswith('fx/') and key[3:].removesuffix('.efx') in d.values() for key in unresolved): reason='Incomplete weapon effect dependencies'
            if any(key.startswith('materials/') and key.split('/',1)[1] in d.values() for key in unresolved): reason='Incomplete weapon material dependencies'
        if reason:
            entry['quarantined']=reason
            table={'character':characters,'weapon':weapons,'knife':knives}[entry['category']]
            row=table[entry['id']]
            if entry['category']=='character': row[4]=characters[0][4]; row[5]=characters[0][5]; row[8]='0'
            else:
                while len(row)<9: row.append('')
                row[4]=weapons[0][4]; row[3]=weapons[0][3]; row[8]='0'
            print('Quarantined',entry['category'],entry['id'],entry['name'],flush=True)
    for category,table in [('weapon',weapons),('character',characters)]:
        active=[e for e in entries if e['category']==category and not e.get('quarantined') and not e.get('moved_to')]
        for index,entry in enumerate(active):
            if 'prestige' in entry and 'level' in entry: continue
            if index<5: tier=0; rank=[30,40,50,60,70][index]
            else:
                milestone=index-5; tier=milestone%50+1; cycle=milestone//50
                rank=([15,45,65,30] if category=='weapon' else [30,60,70,50])[cycle%4]
            entry.update(prestige=tier,level=rank); table[entry['id']][2]=str(rank)
    for name,table in [('itemTable.csv',weapons),('characterTable.csv',characters),('knifeTable.csv',knives)]:
        if not table: continue
        with (ROOT/'src/mp'/name).open('w',newline='',encoding='ascii',errors='replace') as handle: csv.writer(handle,lineterminator='\n').writerows(table)
    manifest=ROOT/'manifests/16-community-content.csv'; lines=manifest.read_text().splitlines()
    required={r[4] for r in characters if r[8]!='0'}|{r[5] for r in characters if r[8]!='0'}
    removed={'weapon,mp/'+e['weapon'] for e in entries if e['category']=='weapon' and e.get('quarantined')}
    removed.update('xmodel,'+name for name in bad_models if name not in required)
    manifest.write_text('\n'.join(line for line in lines if line not in removed)+'\n')
    specpath.write_text(json.dumps(spec,indent=2),encoding='utf8')
    (ROOT/'src/mp/apx_content_unlocks.csv').write_text('\n'.join(e['category']+':'+str(e['id'])+','+str(e['prestige'])+','+str(e['level']) for e in entries if not e.get('quarantined') and not e.get('moved_to'))+'\n')
    print('Unresolved dependencies:',unresolved,flush=True)

if __name__=='__main__':
    main()
    if (ROOT/'ui/content_profile.json').exists():
        from apply_content_profile import main as apply_profile
        apply_profile()
