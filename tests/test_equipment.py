"""Exercise actual GSC loadout decisions, arms permissions and native menu routes."""
import csv
import json
from pathlib import Path
import re
import unittest
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]


class Equipment(unittest.TestCase):
    def setup_runtime(self):
        self.level={'trapsDisabled':False,'itemInfo':{0:{'item':'beretta_mp'}},
                    'knifeInfo':{0:{'item':'knife_mp','enabled':True,'prestige':0,'rank':0},
                                 1:{'item':'custom_knife_mp','enabled':True,'prestige':2,'rank':13}},
                    'numKnives':2,'numGloves':4,'numCharacters':3,
                    'gloveInfo':{0:{'model':'','enabled':True},1:{'model':'hands_a','enabled':True},
                                 2:{'model':'hands_b','enabled':True},3:{'model':'retired','enabled':False}},
                    'characterInfo':{0:{'handsModel':'hands_a','enabled':True,'rank':0,'prestige':0},
                                     1:{'handsModel':'hands_b','enabled':True,'rank':6,'prestige':2},
                                     2:{'handsModel':'hands_b','enabled':True,'rank':27,'prestige':1}}}
        self.player={'pers':{'team':'allies','rank':69,'prestige':2},'stats':{981:0,980:0,2405:1,2406:2},
                     'model':'human','inventory':['old_knife_mp'],'actions':{3:('weapon','claymore_mp')}}
        self.runtime=Runtime({'level':self.level},{
            'takeAllWeapons':lambda p:p['inventory'].clear(),
            'giveWeapon':lambda p,w:p['inventory'].append(w),
            'giveMaxAmmo':lambda p,w:None,
            'setSpawnWeapon':lambda p,w:p.update(spawn_weapon=w),
            'setActionSlot':lambda p,slot,*action:p['actions'].__setitem__(slot,action)})
        self.runtime.load(ROOT/'src/braxi/_equipment.gsc',{'spawnEquipment','equipWeapons'})
        self.runtime.load(ROOT/'src/braxi/_content_unlocks.gsc',{'meets','knifeUnlocked','selectedKnife','glovesUnlocked','selectedHands'})
        for name in ('selectedKnife','selectedHands'):
            self.runtime.definitions['braxi\\_content_unlocks::'+name]=self.runtime.definitions[name]
        self.runtime.load(ROOT/'src/braxi/_unlocks.gsc',{'isCharacterUnlocked'})
        self.runtime.definitions['braxi\\_rank::isCharacterUnlocked']=self.runtime.definitions['isCharacterUnlocked']
        self.runtime.definitions['braxi\\_content_unlocks::meets']=self.runtime.definitions['meets']
        return self.runtime

    def test_human_and_practice_spawns_carry_both_and_replace_old_inventory(self):
        rt=self.setup_runtime()
        for practice in (False,True):
            self.level.update(trapsDisabled=practice,efrActive=practice)
            rt.call('spawnEquipment',receiver=self.player)
            self.assertEqual(self.player['inventory'],['beretta_mp','custom_knife_mp'])
            self.assertEqual(self.player['spawn_weapon'],'beretta_mp')
            self.assertEqual(self.player['actions'][2],('weapon','custom_knife_mp'))
            self.assertEqual(self.player['actions'][3],('weapon','claymore_mp'))

    def test_activator_keeps_tomahawk_with_knife_secondary(self):
        rt=self.setup_runtime();self.player['pers']['team']='axis'
        rt.call('spawnEquipment',receiver=self.player)
        self.assertEqual(self.player['inventory'],['tomahawk_mp','custom_knife_mp'])

    def test_knife_only_and_dog_have_no_stale_secondary(self):
        rt=self.setup_runtime();self.level['trapsDisabled']=True
        rt.call('spawnEquipment',receiver=self.player)
        self.assertEqual(self.player['inventory'],['custom_knife_mp'])
        self.assertEqual(self.player['actions'][2],('',))
        self.player['model']='german_sheperd_dog'
        rt.call('spawnEquipment',receiver=self.player)
        self.assertEqual(self.player['inventory'],['dog_mp'])
        self.assertEqual(self.player['actions'][2],('',))

    def test_locked_or_corrupt_knife_falls_back_without_duplicate_primary(self):
        rt=self.setup_runtime();self.player['pers'].update(rank=0,prestige=0)
        for id in (-1,1,99):
            self.player['stats'][2405]=id
            rt.call('spawnEquipment',receiver=self.player)
            self.assertEqual(self.player['inventory'],['beretta_mp','knife_mp'])
        rt.call('equipWeapons','knife_mp',True,receiver=self.player)
        self.assertEqual(self.player['inventory'],['knife_mp'])

    def test_arms_unlock_when_any_operator_with_them_is_available(self):
        rt=self.setup_runtime()
        for tier,rank,expected in ((0,69,False),(1,26,False),(1,27,True),(2,0,True),(2,6,True)):
            self.player['pers'].update(prestige=tier,rank=rank)
            self.assertEqual(rt.call('glovesUnlocked',2,receiver=self.player),expected)
        for id in (-1,3,99):self.assertFalse(rt.call('glovesUnlocked',id,receiver=self.player))
        self.assertTrue(rt.call('glovesUnlocked',0,receiver=self.player))

    def test_independent_arms_survive_operator_changes_and_auto_follows_operator(self):
        rt=self.setup_runtime()
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'hands_b')
        self.player['stats'][980]=1
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'hands_b')
        self.player['stats'][2406]=0
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'hands_b')
        self.player['stats'][980]=0
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'hands_a')
        self.player['pers']['team']='axis'
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'viewmodel_hands_zombie')
        self.player['stats'][2406]=2
        self.assertEqual(rt.call('selectedHands',receiver=self.player),'hands_b')

    def test_in_game_pages_are_registered_routable_and_request_authoritative_navigation(self):
        routes={row[0]:row for row in csv.reader((ROOT/'src/mp/apx_menu_routes.csv').read_text().splitlines())}
        precache=(ROOT/'src/braxi/_menus.gsc').read_text()
        for destination in ('apx_rewards','apx_knife','apx_gloves'):
            self.assertEqual(routes[destination][3],'1')
            self.assertIn('precacheMenu( "'+destination+'" );',precache)
            origin='apx_prestige' if destination=='apx_rewards' else 'character_stuff'
            source=(ROOT/f'src/ui_mp/scriptmenus/{origin}.menu').read_text()
            self.assertIn('ui:'+origin+':nav:'+destination,source)
        count=json.loads((ROOT/'ui/content_profile.json').read_text())['prestiges']
        progression=(ROOT/'src/ui_mp/scriptmenus/apx_prestige.menu').read_text()
        self.assertIn('+ " / '+str(count)+'"',progression)
        controls=(ROOT/'src/ui_mp/controls_multi.menu').read_text()
        self.assertIn('dvar "+actionslot 2"',controls)
        self.assertIn('text "Select knife"',controls)

    def test_all_catalogs_default_to_still_and_arms_reuse_loaded_assets(self):
        atlas_manifest=(ROOT/'manifests/14-model-previews.csv').read_text()
        turn_manifest=(ROOT/'manifests/15-turntables.csv').read_text()
        for row in csv.reader((ROOT/'src/mp/apx_glove_previews.csv').read_text().splitlines()):
            self.assertIn('material,'+row[1],atlas_manifest)
            self.assertIn('material,'+row[3],turn_manifest)
        for name in ('dr_characters','dr_weapons','apx_primary','apx_knife','apx_gloves','dr_abilities','dr_sprays'):
            source=(ROOT/f'src/ui_mp/scriptmenus/{name}.menu').read_text()
            onopen=re.search(r'onOpen\s*\{([^}]+)\}',source)[1]
            self.assertIn('setLocalVarInt apx_rotate 0;',onopen)
            self.assertNotIn('setLocalVarInt apx_rotate 1;',onopen)

    def test_arms_allowlist_does_not_depend_on_native_csv_trailing_column(self):
        tables={name:list(csv.reader((ROOT/'src/mp'/name).read_text().splitlines()))
                for name in ('gloveTable.csv','apx_catalog.csv')}
        self.assertTrue(all(tables['gloveTable.csv'][0]),'SDK table width needs a complete first row')
        def lookup(table,keycol,key,col):
            # Native legacy CSV loading can omit the final column. Enabled
            # selections must come from the shared catalog, as for primaries.
            if table.endswith('gloveTable.csv') and col==5:return ''
            row=next((r for r in tables[Path(table).name] if r[keycol]==str(key)),None)
            return row[col] if row and col<len(row) else ''
        level={};rt=Runtime({'level':level},{'tableLookup':lookup})
        rt.load(ROOT/'src/braxi/_assets.gsc',{'buildGloveInfo'})
        rt.call('buildGloveInfo')
        self.assertEqual(level['numGloves'],13)
        self.assertEqual(sum(v['enabled'] for v in level['gloveInfo'].values()),10)
        self.assertEqual(level['gloveInfo'][9]['model'],'viewhands_kermit')


if __name__=='__main__':unittest.main()
