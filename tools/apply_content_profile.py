"""Select an official-client collection without deleting imports or reusing IDs.

Regenerates the active manifests, preview fallbacks and prestige milestones.
Raw imports, original unlock metadata and rendered artwork remain available.
Run generate_menus.py and content_report.py afterward, then rebuild and measure
the complete map's asset usage with test-runtime.ps1 -ClientBudget.
"""
import csv
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
TABLES={'weapon':'itemTable.csv','character':'characterTable.csv','knife':'knifeTable.csv'}


def rows(name): return [r for r in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if r]


def filter_previews():
    tables={kind:rows(name) for kind,name in TABLES.items()}
    active={kind:{r[1] for r in table if r[8]!='0'} for kind,table in tables.items()}
    gloves=json.loads((ROOT/'ui/glove_catalog.json').read_text())
    hands={r[5] for r in tables['character'] if r[8]!='0'}
    still=[];turn=[]
    for kind in ('character','weapon','knife'):
        for id in sorted(active[kind],key=int):
            still.append('apx_preview_'+kind+'_'+id)
            if kind=='character': still.append('apx_preview_character_'+id+'_back')
            turn.append('apx_turn_'+kind+'_'+id)
    for hand in sorted(hands):
        still.append('apx_preview_gloves_'+str(gloves[hand]))
        turn.append('apx_turn_gloves_'+str(gloves[hand]))
    atlas=json.loads((ROOT/'ui/preview_atlas.json').read_text())
    rotation_path=ROOT/'ui/turntable_atlas.json'
    rotations=json.loads(rotation_path.read_text()) if rotation_path.exists() else {}
    if rotations and set(turn)-set(rotations):
        raise ValueError('Repack shared turntables for the updated profile before finalizing preview bindings')
    def rotation(name):return rotations.get(name,{'material':name,'cell':0})['material']
    for name in still:
        if name not in atlas: raise ValueError('Repackage still atlases for the new profile: '+name)
    packed=sorted({atlas[name]['material'] for name in still})
    turn_materials=sorted({rotation(name) for name in turn})
    for name in packed+turn_materials:
        if not (ROOT/'assets/images'/(name+'.iwi')).is_file(): raise FileNotFoundError(name)
    for filename,names in [('14-model-previews.csv',packed),('15-turntables.csv',turn_materials)]:
        (ROOT/'manifests'/filename).write_text('// Active content profile; inactive source art is retained.\n'+'\n'.join('material,'+name for name in names)+'\n')
    previews=[]
    base_hand=tables['character'][0][5]
    for row in tables['character']:
        id=row[1] if row[1] in active['character'] else '0'
        hand=row[5] if row[1] in active['character'] else base_hand
        glove=str(gloves[hand])
        front=atlas['apx_preview_character_'+id];back=atlas['apx_preview_character_'+id+'_back'];arms=atlas['apx_preview_gloves_'+glove]
        previews.append([row[1],front['material'],back['material'],arms['material'],
                         rotation('apx_turn_gloves_'+glove),rotation('apx_turn_character_'+id),front['cell'],back['cell'],arms['cell'],
                         rotations.get('apx_turn_gloves_'+glove,{}).get('cell',0)])
    with (ROOT/'src/mp/apx_character_previews.csv').open('w',newline='') as handle:
        csv.writer(handle,lineterminator='\n').writerows(previews)
    for kind in ('weapon','knife'):
        lookup=[]
        for row in tables[kind]:
            id=row[1] if row[1] in active[kind] else '0';slot=atlas['apx_preview_'+kind+'_'+id]
            lookup.append([row[1],slot['material'],slot['cell']])
        with (ROOT/'src/mp'/('apx_'+kind+'_previews.csv')).open('w',newline='') as handle:
            csv.writer(handle,lineterminator='\n').writerows(lookup)
    table_manifest=ROOT/'manifests/04-tables.csv';lines=table_manifest.read_text().splitlines()
    if 'stringtable,mp/apx_knife_previews.csv' not in lines: lines.append('stringtable,mp/apx_knife_previews.csv')
    table_manifest.write_text('\n'.join(lines)+'\n')
    from pack_turntable_atlases import page_names
    keep={name+'.iwi' for name in packed}
    keep.update(image+'.iwi' for name in turn_materials for image in page_names(name))
    inactive=[p.name for p in (ROOT/'assets/images').glob('*.iwi')
              if (p.name.startswith(('apx_preview_','apx_still_','apx_turn_','apx_rotation_')) and p.name not in keep)
              or (p.name.startswith('apx_prestige_') and int(p.stem.rsplit('_',1)[1])>json.loads((ROOT/'ui/content_profile.json').read_text())['prestiges'])]
    (ROOT/'ui/inactive_images.json').write_text(json.dumps(sorted(inactive),indent=2)+'\n')


def main():
    profile=json.loads((ROOT/'ui/content_profile.json').read_text())
    active={kind:set(ids) for kind,ids in profile['active'].items()}
    tables={kind:rows(name) for kind,name in TABLES.items()}
    path=ROOT/'ui/content_catalog.json';spec=json.loads(path.read_text())
    entries={(e['category'],e['id']):e for e in spec['entries']}
    for kind,table in tables.items():
        if not active[kind].issubset({int(r[1]) for r in table}): raise ValueError('Unknown '+kind+' ID in content profile')
        if 0 not in active[kind]: raise ValueError('The safe base selection must stay active: '+kind)
        for row in table:
            id=int(row[1]);entry=entries.get((kind,id))
            if id in active[kind] and entry and (entry.get('quarantined') or entry.get('moved_to')):
                raise ValueError('Profile enables an incomplete or moved entry: '+kind+':'+str(id))
            # Retired legacy characters are permanent reservations.
            if kind=='character' and id in (1,2,3,9) and id in active[kind]: raise ValueError('Retired character ID')
            row[8]='1' if id in active[kind] else '0'
    usable=[]
    for e in spec['entries']:
        if e.get('moved_to') or e.get('quarantined'): continue
        e.setdefault('original_unlock',{'prestige':e['prestige'],'level':e['level']})
        e.update(e['original_unlock'])
        e['inactive_profile']=e['id'] not in active[e['category']]
        if not e['inactive_profile']: usable.append(e)
    base=profile.get('base_rewards',{})
    rewards=sorted((e for e in usable if e['category']+':'+str(e['id']) not in base),
                   key=lambda e:(e['prestige'],e['level'],e['category'],e['id']))
    tiers=profile['prestiges'];levels=profile['reward_levels']
    if len(rewards)!=tiers*len(levels): raise ValueError('Active rewards must fill every configured prestige milestone')
    for i,e in enumerate(rewards):
        e.update(prestige=i%tiers+1,level=levels[i//tiers])
    for e in usable:
        key=e['category']+':'+str(e['id'])
        if key in base: e.update(prestige=0,level=base[key])
        row=tables[e['category']][e['id']];row[2]=str(e['level'])
        if e['category']=='knife': row[7]=str(e['prestige'])
    for kind,table in tables.items():
        with (ROOT/'src/mp'/TABLES[kind]).open('w',newline='',encoding='ascii',errors='replace') as handle:
            csv.writer(handle,lineterminator='\n').writerows(table)
    path.write_text(json.dumps(spec,indent=2)+'\n',encoding='utf8')
    (ROOT/'src/mp/apx_content_unlocks.csv').write_text('\n'.join(e['category']+':'+str(e['id'])+','+str(e['prestige'])+','+str(e['level']) for e in usable)+'\n')
    nav=ROOT/'ui/menu_catalog.json';registry=json.loads(nav.read_text())
    registry['weapon_families']['primary']=sorted(active['weapon']);nav.write_text(json.dumps(registry,indent=2)+'\n')
    declared={line.split('//',1)[0].strip().lower() for p in (ROOT/'manifests').glob('*.csv') if p.name!='16-community-content.csv' for line in p.read_text().splitlines()}
    manifest=set()
    for e in usable:
        if e['category']=='character': manifest.update(('xmodel,'+e['model'],'xmodel,'+e['hands']))
        else:
            manifest.add('weapon,mp/'+e['weapon'])
            manifest.update('sound,'+p.stem+',,all_mp' for p in (ROOT/'assets/soundaliases').glob('apxc_'+e['pack']+'_*.csv'))
    (ROOT/'manifests/16-community-content.csv').write_text('// Active profile; full import provenance and raw assets are retained.\n'+'\n'.join(sorted(line for line in manifest if line.lower() not in declared))+'\n')
    from generate_progression import tables as progression_tables
    progression_tables()
    badges=[f'apx_rank_{i:02}' for i in range(1,71)]+[f'apx_prestige_{i:02}' for i in range(1,tiers+1)]
    (ROOT/'manifests/12-progression.csv').write_text('// Active progression badge set; other original art is retained.\n'+'\n'.join('material,'+name for name in badges)+'\n')
    from pack_turntable_atlases import main as package_rotations
    package_rotations(update_bindings=False)
    from package_preview_atlases import selected_names,main as package_stills
    planned={name for group in selected_names().values() for name in group}
    lookup_path=ROOT/'ui/preview_atlas.json'
    if not lookup_path.exists() or set(json.loads(lookup_path.read_text()))!=planned: package_stills()
    else: filter_previews()
    print(profile['name'],{kind:len(ids) for kind,ids in active.items()},len(usable),'active community entries')


if __name__=='__main__': main()
