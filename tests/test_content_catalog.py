"""Validate the real catalog migration, playable classifications and milestones."""
import csv
import json
from pathlib import Path
import unittest
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

if __name__=='__main__': unittest.main()
