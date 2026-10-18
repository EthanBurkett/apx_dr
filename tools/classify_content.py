"""Separate zero-ammo melee ports from firearms without reusing saved IDs."""
import csv
import json
import os
from pathlib import Path
import shutil
from import_content import ROOT

def rows(name): return [r for r in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if r]
def definition(name):
    parts=(ROOT/'src/weapons/mp'/name).read_text(encoding='latin1').split('\\')
    return dict(zip(parts[1::2],parts[2::2]))

def main():
    path=ROOT/'ui/content_catalog.json'; spec=json.loads(path.read_text()); weapons=rows('itemTable.csv')
    table=rows('knifeTable.csv') if (ROOT/'src/mp/knifeTable.csv').exists() else [['1','0','1','killiconmelee','knife','Standard knife','Carried alongside your primary. Use your melee attack while held.','0','1']]
    new=[]
    for entry in spec['entries']:
        if entry['category']!='weapon' or entry.get('quarantined') or entry.get('moved_to'): continue
        d=definition(entry['weapon'])
        if float(d.get('clipSize','0') or 0)!=0 or float(d.get('damage','0') or 0)!=0 or float(d.get('meleeDamage','0') or 0)<=0: continue
        id=len(table); original=entry['id']
        new.append({**entry,'category':'knife','id':id,'source_weapon_id':original})
        entry['moved_to']='knife:'+str(id)
        row=weapons[original]
        while len(row)<9: row.append('')
        row[8]='0'; row[4]=weapons[0][4]; row[3]=weapons[0][3]
        table.append([str(id+1),str(id),str(entry['level']),d.get('hudIcon') or 'killiconmelee',entry['weapon'][:-3],entry['name'],'Carried alongside your primary. Use your melee attack while held.',str(entry['prestige']),'1'])
        # Reuse the exact rendered mesh views; only the catalog namespace changes.
        for prefix,folder in [('apx_preview_','art/ui/models'),('apx_turn_','art/ui/models/turntables')]:
            source=ROOT/folder/(prefix+'weapon_'+str(original)+'.png'); target=ROOT/folder/(prefix+'knife_'+str(id)+'.png')
            if source.exists() and not target.exists(): shutil.copyfile(source,target)
        source=ROOT/'build/model-render/frames'/('apx_turn_weapon_'+str(original))
        target=ROOT/'build/model-render/frames'/('apx_turn_knife_'+str(id)); target.mkdir(parents=True,exist_ok=True)
        if source.exists():
            for frame in source.glob('*.png'):
                if not (target/frame.name).exists(): os.link(frame,target/frame.name)
        print('Moved primary',original,'to knife',id,entry['name'],flush=True)
    spec['entries'].extend(new)
    # The native table loader uses the first row's column count. Pad every row,
    # including legacy firearms, so disabled column 8 is actually visible to GSC.
    for row in weapons:
        while len(row)<9: row.append('')
        if not row[7]: row[7]='0'
        if row[8]!='0': row[8]='1'
    for name,data in [('itemTable.csv',weapons),('knifeTable.csv',table)]:
        with (ROOT/'src/mp'/name).open('w',newline='',encoding='ascii',errors='replace') as handle: csv.writer(handle,lineterminator='\n').writerows(data)
    path.write_text(json.dumps(spec,indent=2),encoding='utf8')
    nav=ROOT/'ui/menu_catalog.json'; registry=json.loads(nav.read_text())
    registry['weapon_families']['primary']=[int(row[1]) for row in weapons if len(row)<9 or row[8]!='0']
    nav.write_text(json.dumps(registry,indent=2)+'\n')
    active=[e for e in spec['entries'] if not e.get('quarantined') and not e.get('moved_to')]
    (ROOT/'src/mp/apx_content_unlocks.csv').write_text('\n'.join(e['category']+':'+str(e['id'])+','+str(e['prestige'])+','+str(e['level']) for e in active)+'\n')

if __name__=='__main__':
    main()
    if (ROOT/'ui/content_profile.json').exists():
        from apply_content_profile import main as apply_profile
        apply_profile()
