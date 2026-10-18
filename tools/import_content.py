"""Import compatible, dependency-checked raw CoD4 packs without replacing stock.

Source archives, descriptions and rejected candidates remain in build. Only
chosen asset dependencies enter assets; pack scripts/menus/configs never do.
Catalog IDs are append-only and import provenance is recorded in ui.
"""
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT.parent.parent
STAGE=ROOT/'build/content-staging'
ASSETS=ROOT/'assets'
MANIFEST=ROOT/'manifests/16-community-content.csv'
SPEC=ROOT/'ui/content_catalog.json'
OPTIMIZATION=ROOT/'ui/texture_optimization.json'

def strings(data):
    return [v.decode('ascii') for v in re.findall(rb'[\x20-\x7e]{3,}\x00',data) for v in [v[:-1]]]

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def existing(name):
    for base in (ASSETS,GAME/'raw'):
        if (base/name).is_file(): return base/name
    return None

class Pack:
    def __init__(self,record):
        self.record=record; self.base=STAGE/record['id']
        self.files={key.lower():self.base/path for key,path in record.get('files',{}).items()}
        self.actual={key.lower():key for key in record.get('files',{})}
        self.selected={}; self.visited=set()
        self.names={kind:{key.split('/',1)[1]:key for key in self.files if key.startswith(kind+'/')} for kind in ('xmodel','xmodelparts','xmodelsurfs','materials','images','xanim','techsets','techniques','fx')}

    def path(self,key): return self.files.get(key.lower()) or existing(key)

    def add(self,key):
        key=key.lower()
        if key in self.visited: return
        path=self.path(key)
        if not path: raise ValueError('Missing '+key)
        # Shared stock resources must retain their original bytes. A pack that
        # needs a conflicting global replacement is not safe to combine.
        prior=existing(key)
        if key in self.files and prior and digest(prior)!=digest(path):
            # Known mip reductions keep the original archive identity. Reusing
            # that exact source must not overwrite the optimized runtime image.
            if key.startswith('images/') and OPTIMIZATION.exists():
                record=json.loads(OPTIMIZATION.read_text()).get(prior.name)
                if record and digest(prior)==record['outputSHA256'] and digest(path)==record['originalSHA256']:
                    self.visited.add(key)
                    return
            raise ValueError('Conflicting asset '+key)
        self.visited.add(key)
        if key not in self.files: return
        self.selected[self.actual[key]]=path
        kind,name=key.split('/',1)
        data=path.read_bytes(); tokens=strings(data)
        if kind=='xmodel':
            parts=[value for value in tokens if value.lower() in self.names['xmodelparts'] or existing('xmodelparts/'+value)]
            if not parts: raise ValueError('Model lacks usable parts '+name)
            for value in set(parts): self.add('xmodelparts/'+value); self.add('xmodelsurfs/'+value)
            for value in tokens:
                if value.lower() in self.names['materials']: self.add('materials/'+value)
        elif kind=='materials':
            for value in tokens:
                if value.lower()+'.iwi' in self.names['images']: self.add('images/'+value+'.iwi')
                if value.lower() in self.names['techsets']: self.add('techsets/'+value)
        elif kind=='techsets':
            for value in tokens:
                if value.lower() in self.names['techniques']: self.add('techniques/'+value)
        elif kind=='techniques':
            raise ValueError('Custom renderer technique requires separate review: '+name)

    def models(self):
        bodies=[]; hands=[]
        for name,key in self.names['xmodel'].items():
            data=self.files[key].read_bytes()
            parts=[self.files[k].read_bytes() for n,k in self.names['xmodelparts'].items() if n.encode()+b'\0' in data.lower()]
            if re.search(r'viewhands|viewmodel.*hands|^vh_',name): hands.append(name); continue
            if any(b'j_head\0' in part and b'j_hip_le\0' in part for part in parts): bodies.append(name)
        return bodies,hands

    def weapon(self):
        choices=[]
        for key,path in self.files.items():
            if not key.startswith('weapons/'): continue
            source=path.read_text(encoding='latin1'); fields=source.split('\\')
            if fields[0]!='WEAPONFILE': continue
            definition=dict(zip(fields[1::2],fields[2::2]))
            if definition.get('weaponType') not in ('bullet','bullets'): continue
            if not definition.get('gunModel') or not definition.get('worldModel'): continue
            # Prefer the plain weapon over attachment/alternate versions.
            score=sum(word in path.name.lower() for word in ('acog','gl_','silencer','reflex','thermal','eotech','grip'))
            choices.append((score,key,definition))
        errors=[]
        for _,key,d in sorted(choices,key=lambda item:(item[0],len(item[1]),item[1])):
            self.selected={}; self.visited=set()
            try:
                for field,value in list(d.items()):
                    if not value: continue
                    if re.match(r'^(gunModel|worldModel)\d+$',field): d[field]=''; continue
                    if field.endswith('Model'):
                        self.add('xmodel/'+value)
                    elif field.endswith('Anim') and field!='playerAnimType':
                        if self.path('xanim/'+value): self.add('xanim/'+value)
                        elif field in ('idleAnim','fireAnim','reloadAnim'): raise ValueError('Missing essential animation '+value)
                        else: d[field]=''
                for field in ('hudIcon','killIcon','ammoCounterIcon','overlayMaterial','overlayMaterialLowRes'):
                    value=d.get(field,'')
                    if not value: continue
                    if self.path('materials/'+value): self.add('materials/'+value)
                    elif field in ('hudIcon','killIcon','ammoCounterIcon'): d[field]='hud_icon_colt_45'
                    else: d[field]=''
                # Explosive alt weapons are not part of the Deathrun loadout.
                d['altWeapon']=''; d['moveSpeedScale']='1'; d['adsMoveSpeedScale']='1'
                return key,d
            except ValueError as error: errors.append(str(error))
        raise ValueError('; '.join(dict.fromkeys(errors))[:300] or 'No complete bullet weapon definition')

    def copy(self):
        for key,path in self.selected.items():
            dest=ASSETS/key
            if dest.exists(): continue
            dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(path,dest)

def rows(name): return [row for row in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if row]

def sounds(pack,definition,manifest):
    aliases={}; tables=[]
    for asset,path in pack.files.items():
        if not asset.startswith('soundaliases/') or path.suffix.lower()!='.csv': continue
        data=list(csv.reader(path.read_text(encoding='utf-8-sig',errors='replace').splitlines()))
        if not data or 'name' not in [s.lower() for s in data[0]]: continue
        header=data[0]; filecol=next((i for i,v in enumerate(header) if v.lower()=='file'),None)
        valid=[]
        for row in data[1:]:
            if not row or not row[0] or row[0].startswith('#'): continue
            if filecol is not None and len(row)>filecol and row[filecol]:
                sample=row[filecol].replace('\\','/').removeprefix('sound/')
                if not pack.path('sound/'+sample): continue
            original=row[0]; aliases[original]='apxc_'+pack.record['id']+'_'+original
            row[0]=aliases[original]; valid.append(row)
        if valid: tables.append((path.name,header,valid))
    for name,header,data in tables:
        dest=ASSETS/'soundaliases'/('apxc_'+pack.record['id']+'_'+name)
        dest.parent.mkdir(parents=True,exist_ok=True)
        with dest.open('w',newline='',encoding='utf8') as handle: csv.writer(handle,lineterminator='\n').writerows([header]+data)
        manifest.add('sound,'+dest.stem+',,all_mp')
    for key,value in list(definition.items()):
        if value in aliases: definition[key]=aliases[value]
    mapping=definition.get('notetrackSoundMap','')
    for original,renamed in aliases.items(): mapping=re.sub(r'(?<![\w])'+re.escape(original)+r'(?![\w])',renamed,mapping)
    definition['notetrackSoundMap']=mapping
    for asset,path in pack.files.items():
        if not asset.startswith('sound/'): continue
        dest=ASSETS/asset
        if not dest.exists(): dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(path,dest)

def main():
    records=[json.loads(path.read_text(encoding='utf8')) for path in sorted(STAGE.glob('*/stage.json'),reverse=True)]
    spec=json.loads(SPEC.read_text()) if SPEC.exists() else {'schema':1,'entries':[],'rejected':[]}
    entries=spec['entries']; known={(entry['pack'],entry['category'],entry.get('model','')) for entry in entries}
    weapons=rows('itemTable.csv'); characters=rows('characterTable.csv')
    weapon_models={entry['model'] for entry in entries if entry['category']=='weapon'}
    body_models={row[4].lower() for row in characters}|{entry['model'].lower() for entry in entries if entry['category']=='character'}
    manifest=set(MANIFEST.read_text().splitlines()) if MANIFEST.exists() else set()
    rejected=[]
    for record in records:
        pack=Pack(record); bodies,hands=pack.models()
        for model in bodies:
            if model in body_models or len(characters)>=112: continue
            pack.selected={}; pack.visited=set()
            try:
                pack.add('xmodel/'+model)
                hand=hands[0] if hands else 'viewmodel_base_viewhands'
                pack.add('xmodel/'+hand)
                pack.copy(); id=len(characters)
                name=record['name'] if len(bodies)==1 else model.replace('playermodel_','').replace('_',' ').title()
                name=re.sub(r'(?i)\s*(player\s*model|\+\s*viewhands|\+\s*vh)','',name).strip()
                entry={'category':'character','id':id,'name':name,'model':model,'hands':hand,'pack':record['id'],'page':record['page'],'author':record['author'],'sha256':record['sha256']}
                entries.append(entry); body_models.add(model)
                characters.append([str(id+1),str(id),'1','character_sas',model,hand,name,'Community model / '+record['author'], '1'])
                manifest.update(('xmodel,'+model,'xmodel,'+hand))
                print('Imported character',id,name,flush=True)
            except ValueError as error: rejected.append({'pack':record['id'],'name':record['name'],'candidate':model,'reason':str(error)})
        if len(weapons)>=100 or any(entry['pack']==record['id'] and entry['category']=='weapon' for entry in entries): continue
        try:
            key,definition=pack.weapon(); model=definition['worldModel'].lower()
            if model in weapon_models: continue
            id=len(weapons); name='apxc_'+record['id']+'_mp'
            definition['displayName']=record['name']
            # Preserve pack animations/models but use unique weapon IDs. The
            # pack's replacement names can never overwrite the base weapons.
            pack.copy()
            sounds(pack,definition,manifest)
            weapon_path=ROOT/'src/weapons/mp'/name
            weapon_path.write_text('WEAPONFILE'+''.join('\\'+k+'\\'+v for k,v in definition.items()),encoding='latin1')
            icon=definition.get('hudIcon') or 'hud_icon_colt_45'
            weapons.append([str(id+1),str(id),'1',icon,name[:-3],record['name'],'Community weapon / '+record['author'],'0','1'])
            entry={'category':'weapon','id':id,'name':record['name'],'model':model,'weapon':name,'pack':record['id'],'page':record['page'],'author':record['author'],'sha256':record['sha256']}
            entries.append(entry); weapon_models.add(model); manifest.add('weapon,mp/'+name)
            print('Imported weapon',id,record['name'],flush=True)
        except ValueError as error:
            if any(key.startswith('weapons/') for key in pack.files): rejected.append({'pack':record['id'],'name':record['name'],'reason':str(error)})
    # Stable IDs, deterministic staggered milestones. Every prestige gets several
    # level-gated rewards; the final reward in a tier is not given at level one.
    for category,table in [('weapon',weapons),('character',characters)]:
        content=[e for e in entries if e['category']==category and not e.get('quarantined') and not e.get('moved_to')]
        for index,entry in enumerate(content):
            if 'prestige' in entry and 'level' in entry: continue
            if index<5:
                tier=0; rank=[30,40,50,60,70][index]
            else:
                milestone=index-5; tier=milestone%50+1; cycle=milestone//50
                rank=([15,45,65,30] if category=='weapon' else [30,60,70,50])[cycle%4]
            entry.update(prestige=tier,level=rank)
            table[entry['id']][2]=str(rank)
    for name,table in [('itemTable.csv',weapons),('characterTable.csv',characters)]:
        with (ROOT/'src/mp'/name).open('w',newline='',encoding='ascii',errors='replace') as handle: csv.writer(handle,lineterminator='\n').writerows(table)
    spec.update(entries=entries,rejected=rejected)
    SPEC.write_text(json.dumps(spec,indent=2),encoding='utf8')
    declared={line.strip().lower() for path in (ROOT/'manifests').glob('*.csv') if path!=MANIFEST for line in path.read_text().splitlines() if line.strip() and not line.startswith('//')}
    MANIFEST.write_text('// Imported community raw assets; provenance in ui/content_catalog.json\n'+'\n'.join(sorted(line for line in manifest if line and not line.startswith('//') and line.lower() not in declared))+'\n')
    (ROOT/'src/mp/apx_content_unlocks.csv').write_text('\n'.join(e['category']+':'+str(e['id'])+','+str(e['prestige'])+','+str(e['level']) for e in entries if not e.get('quarantined') and not e.get('moved_to'))+'\n')
    nav=ROOT/'ui/menu_catalog.json'; registry=json.loads(nav.read_text()); registry['weapon_families']['primary']=[int(row[1]) for row in weapons if len(row)<9 or row[8]!='0']; nav.write_text(json.dumps(registry,indent=2)+'\n')
    print('Catalog:',len(weapons),'weapons;',len(characters)-4,'enabled characters;',len(rejected),'rejected candidates.',flush=True)

if __name__=='__main__':
    main()
    if (ROOT/'ui/content_profile.json').exists():
        from apply_content_profile import main as apply_profile
        apply_profile()
