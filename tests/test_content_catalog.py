"""Validate the real catalog migration, playable classifications and milestones."""
import csv
import json
from pathlib import Path
import unittest
from copy import deepcopy
from apply_content_profile import reward_assignments
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]

def rows(name):
    return [r for r in csv.reader((ROOT/'src/mp'/name).read_text().splitlines()) if r]

class ContentCatalog(unittest.TestCase):
    def setUp(self):
        self.spec=json.loads((ROOT/'ui/content_catalog.json').read_text())
        self.catalog={r[0]:r for r in rows('apx_catalog.csv')}

    def test_moved_melee_is_exclusive_to_knife_and_ids_remain_reserved(self):
        weapons={int(r[1]):r for r in rows('itemTable.csv')}
        self.assertTrue(all(len(row)==9 for row in weapons.values()))
        knives={int(r[1]):r for r in rows('knifeTable.csv')}
        primary=json.loads((ROOT/'ui/menu_catalog.json').read_text())['weapon_families']['primary']
        moved=[e for e in self.spec['entries'] if e.get('moved_to')]
        self.assertEqual(len(moved),8)
        for e in moved:
            self.assertEqual(weapons[e['id']][8],'0')
            self.assertNotIn(e['id'],primary)
            self.assertNotIn('weapon:'+str(e['id']),self.catalog)
            self.assertIn(e['moved_to'],self.catalog)
            knife=knives[int(e['moved_to'].split(':')[1])]
            self.assertEqual(knife[4]+'_mp',e['weapon'])
            slot=json.loads((ROOT/'ui/turntable_atlas.json').read_text())['apx_turn_knife_'+knife[1]]
            self.assertEqual(self.catalog[e['moved_to']][7],slot['material'])
            self.assertEqual(int(self.catalog[e['moved_to']][9]),slot['cell'])
        for e in self.spec['entries']:
            if e['category']!='weapon' or e.get('moved_to') or e.get('quarantined'): continue
            parts=(ROOT/'src/weapons/mp'/e['weapon']).read_text(encoding='latin1').split('\\')
            d=dict(zip(parts[1::2],parts[2::2]))
            self.assertFalse(float(d.get('clipSize') or 0)==0 and float(d.get('damage') or 0)==0 and float(d.get('meleeDamage') or 0)>0,e['name'])

    def test_every_prestige_has_rank_gated_rewards_and_provenance(self):
        active=[e for e in self.spec['entries'] if not e.get('moved_to') and not e.get('quarantined') and not e.get('inactive_profile')]
        unlocks={r[0]:(int(r[1]),int(r[2])) for r in rows('apx_content_unlocks.csv')}
        for e in active:
            key=e['category']+':'+str(e['id'])
            self.assertIn(key,self.catalog)
            self.assertEqual(unlocks[key],(e['prestige'],e['level']))
            self.assertTrue(e['page'].startswith('https://cfgfactory.com/skins/show/'))
            self.assertIn('author',e) # Some archive records leave credit blank.
            self.assertEqual(len(e['sha256']),64)
        for tier in range(1,6):
            rewards=[e for e in active if e['prestige']==tier]
            self.assertEqual(len(rewards),10,tier)
            self.assertEqual(sorted(e['level'] for e in rewards),list(range(7,71,7)),tier)

    def test_inactive_content_is_excluded_from_catalog_and_linked_manifests(self):
        manifest=(ROOT/'manifests/16-community-content.csv').read_text().splitlines()
        for e in self.spec['entries']:
            if not e.get('inactive_profile'): continue
            self.assertNotIn(e['category']+':'+str(e['id']),self.catalog)
            if e['category']=='weapon': self.assertNotIn('weapon,mp/'+e['weapon'],manifest)
        profile=json.loads((ROOT/'ui/content_profile.json').read_text())
        self.assertEqual(profile['prestiges'],5)
        for category,ids in profile['active'].items():
            self.assertEqual({int(row[2]) for row in self.catalog.values() if row[1]==category},set(ids))

    def test_inactive_characters_are_not_precached(self):
        tables={'mp/characterTable.csv':rows('characterTable.csv'),'mp/apx_catalog.csv':rows('apx_catalog.csv')}
        def lookup(name,keycol,key,valuecol):
            return next((r[valuecol] for r in tables[name] if str(r[keycol])==str(key) and len(r)>valuecol),'')
        models=[];level={}
        runtime=Runtime({'level':level},{'tableLookup':lookup,'precacheModel':models.append,
                         'precacheShader':lambda name:None,'braxi\\_content_unlocks::prestige':lambda *args:0})
        runtime.load(ROOT/'src/braxi/_assets.gsc',{'buildCharacterInfo'})
        runtime.call('buildCharacterInfo')
        expected={r[col] for r in tables['mp/characterTable.csv'] if r[8]!='0' for col in (4,5)}
        self.assertEqual(set(models),expected)
        for row in tables['mp/characterTable.csv']:
            self.assertEqual(level['characterInfo'][int(row[1])]['enabled'],row[8]!='0')

    def test_curated_roster_uses_handguns_and_keeps_exact_authored_rewards(self):
        profile=json.loads((ROOT/'ui/content_profile.json').read_text())
        labels=json.loads((ROOT/'ui/catalog_labels.json').read_text())
        weapons={int(r[1]):r for r in rows('itemTable.csv') if r[8]=='1'}
        self.assertEqual(len(weapons),24)
        self.assertEqual(sum(labels['weapon:'+str(id)]['role']=='pistol' for id in weapons),22)
        self.assertEqual({id for id in weapons if labels['weapon:'+str(id)]['role']=='sniper'},{4,6})
        for id,row in weapons.items():
            path=ROOT/'src/weapons/mp'/(row[4]+'_mp')
            if id<8:continue # Stock definitions are retained by the shader preservation tests.
            parts=path.read_text(encoding='latin1').split('\\');fields=dict(zip(parts[1::2],parts[2::2]))
            self.assertEqual(fields['weaponClass'],'pistol',row[5])
            self.assertEqual(fields['displayName'],row[5])
        unlocks={r[0]:(int(r[1]),int(r[2])) for r in rows('apx_content_unlocks.csv')}
        for tier,keys in enumerate(profile['prestige_rewards'],1):
            for level,key in zip(profile['reward_levels'],keys):self.assertEqual(unlocks[key],(tier,level))

    def test_bad_reward_tracks_are_rejected_without_mutating_catalog(self):
        profile=json.loads((ROOT/'ui/content_profile.json').read_text())
        active=[e for e in self.spec['entries'] if not any(e.get(k) for k in ('moved_to','quarantined','inactive_profile'))]
        original=deepcopy(active)
        for failure in ('duplicate','unknown','missing_tier','short_tier','inactive_base'):
            broken=deepcopy(profile)
            if failure=='duplicate':broken['prestige_rewards'][0][0]=broken['prestige_rewards'][1][0]
            if failure=='unknown':broken['prestige_rewards'][0][0]='weapon:99999'
            if failure=='missing_tier':broken['prestige_rewards'].pop()
            if failure=='short_tier':broken['prestige_rewards'][0].pop()
            if failure=='inactive_base':broken['base_rewards']['weapon:99999']=1
            with self.subTest(failure=failure),self.assertRaises(ValueError):reward_assignments(active,broken)
            self.assertEqual(active,original)

    def test_browser_lists_pistols_first_without_changing_selection_or_filters(self):
        def lookup(table,keycol,key,col):
            row=self.catalog.get(str(key),[])
            return row[col] if col<len(row) else ''
        for search,owned in [('',False),('',True),('remington',False),('usp',True)]:
            with self.subTest(search=search,owned=owned):
                runtime=Runtime({'level':{'numItems':100}},{'tableLookup':lookup,'toLower':str.lower,
                    'getSubStr':lambda s,a,b:s[a:b],'min':min,'isUnlocked':lambda player,cat,id:id<8,
                    'publish':lambda player:None,'spawnStruct':lambda:{},'isSubStr':lambda s,q:q in s})
                runtime.load(ROOT/'src/braxi/_menu_browser.gsc',{'query','validCategory','pageSize'})
                player={'stats':{981:6}}
                runtime.call('query','weapon',search,owned,receiver=player)
                result=list(player['apxBrowser']['ids'].values())
                expected=[int(r[2]) for r in self.catalog.values() if r[1]=='weapon' and
                          search in r[3].lower() and (not owned or int(r[2])<8)]
                expected.sort(key=lambda id:id in (4,6))
                self.assertEqual(result,expected)
                if 6 in expected:self.assertEqual(player['apxBrowser']['selected'],6)

    def test_display_labels_are_complete_and_archive_names_are_retained(self):
        labels=json.loads((ROOT/'ui/catalog_labels.json').read_text())
        for kind,table,nc,dc in [('weapon','itemTable.csv',5,6),('character','characterTable.csv',6,7),('knife','knifeTable.csv',5,6)]:
            for row in rows(table):
                if row[8]=='0':continue
                label=labels[kind+':'+row[1]]
                self.assertEqual((row[nc],row[dc]),(label['name'],label['description']))
        for e in self.spec['entries']:
            if e.get('inactive_profile') or e.get('moved_to') or e.get('quarantined'):continue
            self.assertTrue(e.get('archive_name'),e['name'])

if __name__=='__main__': unittest.main()
