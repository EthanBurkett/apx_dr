"""Real GSC decisions for records, ballots, and large installed rotations."""
from pathlib import Path
import json
import re
import tempfile
import unittest
import zipfile
from gsc_runtime import Runtime
from sync_map_rotation import chunks,rotation,inspect_map

ROOT=Path(__file__).resolve().parents[1]


class Presentation(unittest.TestCase):
    def test_unfinished_run_is_never_a_record_or_match_leader(self):
        runtime=Runtime()
        runtime.load(ROOT/'src/braxi/_intermission.gsc',{'validResult','betterResult','valueLabel'})
        for value in (None,0,-1,99999999,100000000):
            self.assertFalse(runtime.call('validResult','time',value))
        self.assertTrue(runtime.call('betterResult','time',31.25,0))
        self.assertTrue(runtime.call('betterResult','time',31.25,99))
        self.assertFalse(runtime.call('betterResult','time',40,31.25))
        self.assertFalse(runtime.call('betterResult','time',99999999,0))
        self.assertEqual(runtime.call('valueLabel','time',99999999),'--')
        self.assertEqual(runtime.call('valueLabel','time',31.25),'31.25 s')
        self.assertTrue(runtime.call('betterResult','kills',2,1))
        self.assertFalse(runtime.call('betterResult','kills',1,2))

    def test_time_leader_ignores_uninitialized_and_sentinel_values(self):
        players=[{'pers':{'time':99999999}},{'pers':{}},{'pers':{'time':0}}]
        runtime=Runtime(natives={'getAllPlayers':lambda:players})
        runtime.load(ROOT/'src/braxi/_common.gsc',{'getBestPlayerFromTime'})
        self.assertIsNone(runtime.call('getBestPlayerFromTime'))
        players += [{'pers':{'time':41.125}},{'pers':{'time':39.875}}]
        self.assertEqual(runtime.call('getBestPlayerFromTime')['pers']['time'],39.875)

    def test_ballots_replace_and_clear_without_accumulation_and_expire(self):
        level={'apxPostPhase':1,'mapvote':1,'apxPostEnds':1000,'maps':[{'votes':0},{'votes':0}]}
        player={};other={'voteindex':1};players=[player,other]
        runtime=Runtime({'level':level},natives={'getAllPlayers':lambda:players,'getTime':lambda:100,
            'isSubStr':lambda s,part:part in s,
            'braxi\\_intermission::publishBallot':lambda *args:None})
        runtime.load(ROOT/'src/braxi/_vote_players.gsc',{'cast','recount'})
        for _ in range(100):self.assertTrue(runtime.call('cast','0',receiver=player))
        self.assertEqual([level['maps'][i]['votes'] for i in range(2)],[1,1])
        self.assertTrue(runtime.call('cast','1',receiver=player))
        self.assertEqual([level['maps'][i]['votes'] for i in range(2)],[0,2])
        self.assertTrue(runtime.call('cast','clear',receiver=player))
        players.remove(other);runtime.call('recount')
        self.assertEqual(level['apxVoteTotal'],0)
        for bad in ('-1','2','00','abc'):
            self.assertFalse(runtime.call('cast',bad,receiver=player))
        level['apxPostEnds']=99
        self.assertFalse(runtime.call('cast','0',receiver=player))

    def test_large_rotation_is_complete_deduplicated_and_command_bounded(self):
        names=['mp_dr_test_'+str(i) for i in range(1000)]
        source=rotation(names)
        self.assertTrue(all(len(line.encode('ascii'))<1024 for line in source.splitlines()))
        pages=chunks(names)
        self.assertEqual(re.findall(r'map (mp_\w+)',' '.join(pages)),names)
        dvars={'apx_rotation_page_count':str(len(pages)),**{'apx_rotation_'+str(i):p for i,p in enumerate(pages)}}
        # A duplicated entry on a later page is ignored by the actual GSC reader.
        dvars['apx_rotation_1']+=' map '+names[0]
        runtime=Runtime(natives={'toLower':str.lower,'getSubStr':lambda s,a,b:s[a:b],
                                'getDvar':lambda k:dvars.get(k,''),'getDvarInt':lambda k:int(dvars.get(k,0)),
                                'addMapItem':lambda name,gametype:{'mapname':name}})
        runtime.load(ROOT/'src/braxi/_vote_maps.gsc',{'getMaprotation'})
        result=runtime.call('getMaprotation')
        self.assertEqual([r['mapname'] for r in result.values()],names)

    def test_inventory_filters_regular_multiplayer_and_incomplete_maps(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder)
            for name in ('mp_dr_test','mp_deathrun_test','mp_nuketown','mp_mystery','mp_dr_missing'):
                path=base/name;path.mkdir()
                if name!='mp_dr_missing':(path/(name+'.ff')).write_bytes(b'fastfile fixture')
            with zipfile.ZipFile(base/'mp_mystery/map.iwd','w') as archive:
                archive.writestr('mp/map.arena','{ map "mp_mystery" type "dm deathrun" }')
            selected={p.name for p in base.iterdir() if inspect_map(p)['deathrun']}
            self.assertEqual(selected,{'mp_dr_test','mp_deathrun_test','mp_mystery'})

    def test_checked_in_rotation_matches_inventory_and_native_menu_routes(self):
        report=json.loads((ROOT/'ui/map_inventory.json').read_text())
        names={row['map'] for row in report['maps'] if row['deathrun']}
        source=(ROOT/'config/server/rotation.cfg').read_text()
        pages=re.findall(r'^set apx_rotation_\d+ "([^"]*)"',source,re.M)
        actual=re.findall(r'map (mp_\w+)',' '.join(pages))
        self.assertEqual(set(actual),names);self.assertEqual(len(actual),len(names))
        self.assertIn('menufile,ui_mp/scriptmenus/apx_intermission.menu',(ROOT/'manifests/07-menus.csv').read_text())
        self.assertIn('apx_intermission,public,',(ROOT/'src/mp/apx_menu_routes.csv').read_text())
        for path in ('src/braxi/_rounds.gsc','src/braxi/_assets.gsc','manifests/06-effects.csv'):
            self.assertNotIn('falling_teddys',(ROOT/path).read_text())


if __name__=='__main__':unittest.main()
