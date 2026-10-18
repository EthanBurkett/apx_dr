import csv
import hashlib
import json
from pathlib import Path
import struct
import unittest
from PIL import Image

from gsc_runtime import Runtime

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'src/braxi'
RANKS = [r for r in csv.reader((ROOT/'src/mp/rankTable.csv').read_text().splitlines()) if r[0].isdigit()]
CAP = int(RANKS[-1][7])
MAX_PRESTIGE = json.loads((ROOT/"ui/content_profile.json").read_text())["prestiges"]


class Progression(unittest.TestCase):
    def runtime(self):
        runtime = Runtime({'level': {'maxRank': 69, 'maxPrestige': MAX_PRESTIGE}}, {
            'braxi\\_rank_tables::getRankInfoMaxXP': lambda r: int(RANKS[r][7]),
            'braxi\\_rank_tables::getRankInfoMinXP': lambda r: int(RANKS[r][2]),
            'setStat': lambda player, stat, value: player['stats'].__setitem__(stat, value),
            'setRank': lambda player, rank, prestige: player.update(native_rank=(rank,prestige)),
            'setClientDvars': lambda *args: None,
            'braxi\\_profile::sanitizeCustomization': lambda player: None,
            'braxi\\_rank_integrity::updateAntiHackValues': lambda player: None,
            'iPrintlnBold': lambda *args: None, 'playLocalSound': lambda *args: None,
            'getTime': lambda: 1000})
        runtime.load(SOURCE/'_rank_progression.gsc', {'getRankForXp'})
        runtime.definitions['braxi\\_rank_progression::getRankForXp'] = runtime.definitions['getRankForXp']
        runtime.load(SOURCE/'_prestige.gsc', {'clamp','canEnter','request','enter','syncProfile','updateMenu'})
        return runtime

    def player(self, prestige=0, xp=CAP, rank=69):
        return {'pers': {'prestige': prestige, 'rankxp': xp, 'rank': rank},
                'stats': {2303: 456, 2302: 789, 3200: 1, 3000: 23, 2314: 12345}}

    def test_all_seventy_level_boundaries_and_oversized_xp(self):
        for rank,row in enumerate(RANKS):
            runtime=self.runtime()
            self.assertEqual(runtime.call('getRankForXp',int(row[2])),rank)
            self.assertEqual(runtime.call('getRankForXp',int(row[7])-1),rank)
        self.assertEqual(self.runtime().call('getRankForXp',-999),0)
        self.assertEqual(self.runtime().call('getRankForXp',2**31-1),69)

    def test_prestige_requires_full_final_level_and_stops_at_ten(self):
        for rank,xp,prestige,expected in [(68,CAP,0,False),(69,CAP-1,0,False),(69,CAP,0,True),(69,CAP,MAX_PRESTIGE-1,True),(69,CAP,MAX_PRESTIGE,False)]:
            self.assertEqual(self.runtime().call('canEnter',receiver=self.player(prestige,xp,rank)),expected)

    def test_every_prestige_preserves_lifetime_stats_and_cannot_apply_twice(self):
        for prestige in range(MAX_PRESTIGE):
            runtime=self.runtime(); player=self.player(prestige)
            lifetime=dict(player['stats'])
            self.assertTrue(runtime.call('request',receiver=player))
            self.assertTrue(runtime.call('enter',receiver=player))
            self.assertEqual(player['pers'],{'rank':0,'rankxp':0,'prestige':prestige+1})
            self.assertEqual(player['native_rank'],(0,prestige+1))
            self.assertEqual(player['stats'][2326],prestige+1)
            for stat,value in lifetime.items(): self.assertEqual(player['stats'][stat],value)
            self.assertFalse(runtime.call('enter',receiver=player))

    def test_unconfirmed_expired_and_stale_requests_do_not_reset(self):
        for confirmation in (None,0):
            player=self.player();player['prestigeConfirmationUntil']=confirmation
            self.assertFalse(self.runtime().call('enter',receiver=player))
            self.assertEqual(player['pers']['rankxp'],CAP)
        runtime=self.runtime();player=self.player()
        runtime.call('request',receiver=player);player['pers']['prestige']=MAX_PRESTIGE
        self.assertFalse(runtime.call('enter',receiver=player))

    def test_profile_sync_clamps_and_retains_prestige(self):
        runtime=self.runtime();player=self.player(50,2**31-1,0)
        runtime.call('syncProfile',receiver=player)
        self.assertEqual(player['native_rank'],(69,MAX_PRESTIGE))
        self.assertEqual(player['stats'][2301],CAP)
        self.assertEqual(player['stats'][2350],69)
        self.assertEqual(player['stats'][252],69)

    def test_tables_and_all_custom_assets_are_complete(self):
        icons=list(csv.reader((ROOT/'src/mp/rankIconTable.csv').read_text().splitlines()))
        self.assertEqual(len(RANKS),70)
        self.assertEqual(icons[-1],['maxprestige',str(MAX_PRESTIGE)])
        prestiges=list(csv.reader((ROOT/'src/mp/apx_prestiges.csv').read_text().splitlines()))
        self.assertEqual(prestiges[0],['0','white','No prestige'])
        for prestige in range(1,MAX_PRESTIGE+1): self.assertEqual(prestiges[prestige][1],f'apx_prestige_{prestige:02}')
        self.assertEqual([int(r[13]) for r in RANKS],list(range(1,71)))
        names=[f'apx_rank_{n:02}' for n in range(1,71)]+[f'apx_prestige_{n:02}' for n in range(1,MAX_PRESTIGE+1)]
        hashes=set()
        for name in names:
            raw=(ROOT/'assets/images'/f'{name}.iwi').read_bytes()
            self.assertEqual(raw[:6],b'IWi\x06\x01\x01')
            self.assertEqual(struct.unpack_from('<3H',raw,6),(512,512,1))
            self.assertEqual(struct.unpack_from('<I',raw,12)[0],len(raw))
            sizes=[4*max(1,512>>i)**2 for i in range(10)]
            self.assertEqual(len(raw),28+sum(sizes))
            self.assertEqual(struct.unpack_from('<4I',raw,12),tuple(28+sum(sizes[i:]) for i in range(4)))
            family='ranks' if name.startswith('apx_rank_') else 'prestiges'
            image=Image.open(ROOT/'art/progression'/family/f'{name}.png').convert('RGBA')
            decoded=Image.frombytes('RGBA',(512,512),raw[-sizes[0]:],'raw','BGRA')
            self.assertEqual(decoded.tobytes(),image.tobytes())
            hashes.add(hashlib.sha256(raw).digest())
            material=(ROOT/'assets/materials'/name).read_bytes()
            self.assertEqual(struct.unpack_from('<2H',material,24),(512,512))
            name_offset=struct.unpack_from('<I',material,0)[0]
            self.assertEqual(material[name_offset:].split(b'\0')[0],name.encode())
        self.assertEqual(len(hashes),70+MAX_PRESTIGE)
        for rank,row in enumerate(icons[:70]):
            self.assertEqual(row,[str(rank)]+[f'apx_rank_{rank+1:02}']*(MAX_PRESTIGE+1))


class Scoreboard(unittest.TestCase):
    def test_header_uses_current_server_map_after_map_changes(self):
        server = {'mapname': 'mp_dr_lithium', 'ui_mapname': 'mp_backlot'}
        client = {}

        def set_dvars(player, *pairs):
            client.update(zip(pairs[::2], pairs[1::2]))

        runtime = Runtime(natives={
            'getDvar': lambda name: server[name],
            'setClientDvars': set_dvars,
            'setClientDvar': lambda *args: None,
            'braxi\\_prestige::clamp': lambda value, low, high: max(low,min(value,high)),
        })
        runtime.load(SOURCE/'_scoreboard_panel.gsc', {'update','pageCount'})
        player = {'apxScorePage': 0, 'apxScoreCache': {}}
        runtime.call('update', [], receiver=player)
        self.assertEqual(client['apx_sb_map'], 'mp_dr_lithium')
        server['mapname'] = 'mp_deathrun_long'
        runtime.call('update', [], receiver=player)
        self.assertEqual(client['apx_sb_map'], 'mp_deathrun_long')

    def test_native_menu_contract_and_macro_rectangles(self):
        menu=(ROOT/'src/ui_mp/scriptmenus/scoreboard.menu').read_text()
        manifest=(ROOT/'manifests/07-menus.csv').read_text()
        self.assertIn('menufile,ui_mp/scriptmenus/scoreboard.menu',manifest)
        self.assertIn('name "scoreboard"',menu)
        self.assertIn('onOpen { scriptMenuResponse "open"; }',menu)
        self.assertIn('onClose { scriptMenuResponse "close"; }',menu)
        self.assertIn('dvarString("apx_sb_map")',menu)
        self.assertNotIn('dvarString("ui_mapname")',menu)
        self.assertEqual(menu.count('APX_SCORE_ROW('),14)
        for name in ['apx_panel.inc','apx_scoreboard_row.inc']:
            for line in (ROOT/'src/ui_mp/components'/name).read_text().splitlines():
                if line.strip().startswith('rect '):
                    self.assertEqual(len(line.strip().removesuffix('\\').split()),7,line)

    def test_sorting_teams_scores_and_stable_ties(self):
        players=[{'is_player':True,'number':n,'score':score,'pers':{'rank':0,'team':team}}
                 for n,score,team in [(0,40,'spectator'),(1,1,'axis'),(2,100,'allies'),(3,100,'allies'),(4,0,'allies')]]
        runtime=Runtime(natives={'getAllPlayers':lambda:players})
        runtime.load(SOURCE/'_scoreboard_panel.gsc',{'comesBefore','teamOrder','getRows','pageCount'})
        rows=runtime.call('getRows')
        self.assertEqual([p['number'] for p in rows.values()],[2,3,4,1,0])
        for count,pages in [(0,1),(1,1),(14,1),(15,2),(64,5)]:
            self.assertEqual(runtime.call('pageCount',count),pages)


if __name__ == '__main__':
    unittest.main()
