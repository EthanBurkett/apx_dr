"""Export server-searchable metadata without renumbering saved catalog IDs."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GLOVE_NAMES = {
    'viewhands_black_kit': 'Black tactical gloves', 'viewmodel_hands_50cent': '50 Cent arms',
    'viewmodel_hands_zombie': 'Zombie arms', 'captainamericaviewhands': 'Captain America arms',
    'vh_iw4_udt': 'Seal UDT gloves', 'viewhands_bots_50cent': 'BOT 50 Cent arms',
    'viewhands_dnf_duke': 'Duke Nukem arms', 'viewhands_freeman': 'Gordon Freeman arms',
    'viewhands_kermit': 'Kermit arms', 'viewhands_lion': 'Lion arms',
    'viewhands_moh_ranger': 'Ranger gloves', 'viewmodel_base_viewhands': 'Classic combat gloves'
}
NAMES = {
    '@WEAPON_BERETTA': 'Beretta M9', '@WEAPON_COLT1911': 'Colt M1911',
    '@WEAPON_USP': 'USP .45', '@WEAPON_DESERTEAGLE': 'Desert Eagle',
    '@WEAPON_M40A3': 'M40A3', '@WEAPON_DESERTEAGLEGOLD': 'Gold Desert Eagle',
    '@WEAPON_REMINGTON700': 'Remington 700', '@PERKS_NONE': 'None',
    '@PERKS_EXTREME_CONDITIONING': 'Extreme Conditioning', '@PERKS_IRON_LUNGS': 'Iron Lungs',
    '@PERKS_STOPPING_POWER': 'Stopping Power', '@PERKS_STEADY_AIM': 'Steady Aim',
    '@PERKS_DOUBLE_TAP': 'Double Tap', '@PERKS_SLEIGHT_OF_HAND': 'Sleight of Hand',
    '@PERKS_JUGGERNAUT': 'Juggernaut',
    '@PERKS_SPRINT_FOR_LONGER_DISTANCES': 'Sprint for longer distances.',
    '@PERKS_LONGER_BREATH_FOR_STEADIER': 'Hold your breath longer for steadier aim.',
    '@PERKS_INCREASED_BULLET_DAMAGE': 'Increased bullet damage.',
    '@PERKS_INCREASED_HIPFIRE_ACCURACY': 'Improved hipfire accuracy.',
    '@PERKS_INCREASED_RATE_OF_FIRE': 'Increased rate of fire.',
    '@PERKS_FASTER_RELOADING': 'Faster reloads.', '@PERKS_INCREASED_HEALTH': 'Increased maximum health.'
}


def build():
    result = []
    atlas=json.loads((ROOT/'ui/preview_atlas.json').read_text())
    for category, table, nc, dc, ic in [
        ('weapon', 'itemTable', 5, 6, 3), ('character', 'characterTable', 6, 7, 3),
        ('knife', 'knifeTable', 5, 6, 3),
        ('ability', 'abilityTable', 5, 6, 4), ('spray', 'sprayTable', 5, 6, 3)
    ]:
        for row in csv.reader((ROOT/'src/mp'/(table+'.csv')).read_text().splitlines()):
            if not row or (category in ('character','weapon','knife') and len(row)>8 and row[8]=='0'):
                continue
            id = row[1]
            material = row[ic]
            cell=0
            if category in ('weapon', 'character','knife'):
                slot=atlas['apx_preview_'+category+'_'+id]
                material=slot['material'];cell=slot['cell']
            turn = 'apx_turn_'+category+'_'+id if category in ('weapon', 'character','knife') else material
            result.append([category+':'+id, category, id, NAMES.get(row[nc], row[nc]),
                           NAMES.get(row[dc], row[dc]), material, row[2] if category != 'ability' else '0', turn,cell])
    # Zero follows the operator. Explicit IDs are permanent registry IDs + 1.
    characters=list(csv.reader((ROOT/'src/mp/characterTable.csv').read_text().splitlines()))
    active_hands={r[5] for r in characters if r and r[8]!='0'}
    registry=json.loads((ROOT/'ui/glove_catalog.json').read_text())
    # The SDK infers the table width from the first row. A blank model token
    # there truncates native access to the later model/permission columns.
    glove_rows=[['1','0','auto','Operator arms','Follow your selected operator.','1']]
    previews=[]
    for model,index in sorted(registry.items(),key=lambda pair:pair[1]):
        id=index+1;enabled=model in active_hands
        name=GLOVE_NAMES.get(model,model)
        glove_rows.append([str(id+1),str(id),model,name,'Unlock an operator using these arms.',str(int(enabled))])
        if not enabled: continue
        slot=atlas['apx_preview_gloves_'+str(index)]
        previews.append([id,slot['material'],slot['cell'],'apx_turn_gloves_'+str(index)])
        result.append(['gloves:'+str(id),'gloves',id,name,'First-person arms / independent of your operator.',
                       slot['material'],1,'apx_turn_gloves_'+str(index),slot['cell']])
    base=next(r for r in previews if r[0]==registry[characters[0][5]]+1)
    previews.insert(0,[0]+base[1:])
    result.append(['gloves:0','gloves',0,'Operator arms','Follow your selected operator.',base[1],1,base[3],base[2]])
    for name,data in [('gloveTable.csv',glove_rows),('apx_glove_previews.csv',previews),('apx_catalog.csv',result)]:
        with (ROOT/'src/mp'/name).open('w',newline='') as handle:
            csv.writer(handle,lineterminator='\n').writerows(data)
    manifest = ROOT/'manifests/04-tables.csv'
    lines = manifest.read_text().splitlines()
    for table in ('apx_catalog','gloveTable','apx_glove_previews'):
        entry='stringtable,mp/'+table+'.csv'
        if entry not in lines: lines.append(entry)
    manifest.write_text('\n'.join(lines)+'\n')


if __name__ == '__main__':
    build()
