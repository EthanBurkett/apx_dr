import csv
from pathlib import Path
import re
import unittest

from gsc_runtime import Runtime

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT/'src/braxi'
STATS = {row[0]: row[1] for row in csv.reader((ROOT/'src/mp/playerStatsTable.csv').read_text().splitlines())}


class AdminProgression(unittest.TestCase):
    def setup_runtime(self):
        self.player = {'is_player': True, 'number': 2, 'name': '^3hype',
            'sessionstate': 'spectator', 'score': 17, 'kills': 2, 'deaths': 3, 'assists': 4,
            'pers': {'rankxp': 0, 'rank': 0, 'prestige': 3, 'admin': False, 'ability': 'specialty_null'},
            'stats': {2302: 1234, 2303: 456, 3201: 1, 501: 255, 2501: 88,
                      270: 2, 979: 3, 980: 2, 981: 5, 982: 1, 988: 1, 2365: 2},
            'prestigeConfirmationUntil': 100000,
        }
        self.players = [self.player]
        self.logs = []
        self.runtime = Runtime({'level': {'maxRank': 69, 'maxPrestige': 10,
            'numChallengeTiers': 2, 'freeRun': True,
            'challengeInfo': {'ch_test': {'stateid': 501, 'statid': 2501}}}}, {
            'toLower': lambda text: text.lower(), 'isSubStr': lambda text, part: part in text,
            'removeColorFromString': lambda text: re.sub(r'\^.', '', text),
            'getAllPlayers': lambda: self.players,
            'braxi\\_admin_commands::getPlayerByNum': lambda n: next((p for p in self.players if p['number']==n), None),
            'braxi\\_rank_tables::getRankInfoMaxXP': lambda rank: 200*(rank+1)*(rank+2),
            'braxi\\_rank_tables::getRankInfoMinXP': lambda rank: 200*rank*(rank+1),
            'braxi\\_prestige::clamp': lambda value, low, high: max(low,min(value,high)),
            'braxi\\_profile::sanitizeCustomization': lambda player: None,
            'braxi\\_rank_integrity::updateAntiHackValues': lambda player: player.update(mirrored=(player['pers']['rankxp'],player['pers']['rank'],player['pers']['prestige'])),
            'setStat': lambda player, stat, value: player['stats'].__setitem__(stat,value),
            'setRank': lambda player, rank, prestige: player.update(native_rank=(rank,prestige)),
            'setClientDvars': lambda *args: None,
            'iPrintlnBold': lambda *args: None, 'println': self.logs.append, 'logPrint': self.logs.append,
            'getGuid': lambda player: 'test-guid', 'notify': lambda *args: None,
            'tableLookup': lambda table, keycol, key, column: STATS.get(str(key), ''),
            'getArrayKeys': lambda array: list(array),
            'braxi\\_challenge_progress::unlockChallenge': lambda player, tier: player['stats'].__setitem__(501,1),
            'braxi\\_challenge_data::updateChallenges': lambda player: player.update(challengeData={'ch_test':player['stats'][501]}),
            'unsetPerk': lambda player, perk: player.update(removed_perk=perk),
            'showFeedback': lambda *args: None,
        })
        self.runtime.load(SOURCE/'_admin_progression.gsc', {'handle','parseInteger','getTarget','apply','resetProfile','usage'})
        self.runtime.load(SOURCE/'_rank_progression.gsc', {'getRankForXp'})
        self.runtime.definitions['braxi\\_rank_progression::getRankForXp'] = self.runtime.definitions['getRankForXp']
        self.runtime.load(SOURCE/'_prestige.gsc', {'clamp','syncProfile','updateMenu','canEnter'})
        self.runtime.definitions['braxi\\_prestige::syncProfile'] = self.runtime.definitions['syncProfile']
        self.runtime.load(SOURCE/'_admin_auth.gsc', {'hasPermission'})
        self.runtime.definitions['braxi\\_admin_auth::hasPermission'] = self.runtime.definitions['hasPermission']
        return self.runtime

    def command(self, *parts, mode='number', actor=None):
        return self.runtime.call('handle',list(parts),mode,receiver=actor)

    def test_xp_works_in_spectator_and_freerun_without_inflating_lifetime_score(self):
        self.setup_runtime()
        self.assertTrue(self.command('xp','2'))
        self.assertEqual(self.player['pers']['rankxp'],4000)
        self.command('xp','2','994000')
        self.assertEqual(self.player['pers']['rankxp'],994000)
        self.assertEqual(self.player['pers']['rank'],69)
        self.assertEqual(self.player['native_rank'],(69,3))
        self.assertEqual(self.player['mirrored'],(994000,69,3))
        self.assertEqual(self.player['stats'][2302],1234)
        self.assertEqual(self.player['score'],17)
        self.assertIsNone(self.player['prestigeConfirmationUntil'])

    def test_all_displayed_ranks_and_prestiges_update_saved_profile(self):
        self.setup_runtime()
        for rank in range(1,71):
            self.command('setrank','2',str(rank))
            self.assertEqual(self.player['pers']['rank'],rank-1)
            self.assertEqual(self.player['stats'][252],rank-1)
        self.assertTrue(self.runtime.call('canEnter',receiver=self.player))
        for prestige in range(11):
            self.command('setprestige','2',str(prestige))
            self.assertEqual(self.player['stats'][2326],prestige)
            self.assertEqual(self.player['native_rank'],(69,prestige))
            self.assertEqual(self.player['stats'][3201],1)
        self.command('setrank','2','1')
        self.assertEqual(self.player['stats'][2301],0)

    def test_invalid_values_and_targets_never_mutate_progression(self):
        self.setup_runtime()
        for command,value in [('setrank','0'),('setrank','71'),('setprestige','11'),('setprestige','-1'),
                              ('xp','0'),('xp','994001'),('xp','9999999999999'),('xp','1.5'),('xp','12x'),('xp','')]:
            self.command(command,'2',value)
        self.command('setrank','2')
        self.command('reset','2','unexpected')
        self.command('reset','not-a-client-number')
        self.command('reset','63')
        self.assertEqual(self.player['pers']['rankxp'],0)
        self.assertEqual(self.player['pers']['prestige'],3)
        self.assertEqual(self.player['stats'][2302],1234)
        self.assertFalse(self.command('heal','2'))

    def test_player_context_requires_admin_and_progression_permission(self):
        self.setup_runtime()
        self.command('xp','2','500',actor=self.player)
        self.assertEqual(self.player['pers']['rankxp'],0)
        self.player['pers']['admin']=True
        self.command('xp','2','500',actor=self.player)
        self.assertEqual(self.player['pers']['rankxp'],0)
        self.player['pers']['permissions']='p'
        self.command('xp','2','500',actor=self.player)
        self.assertEqual(self.player['pers']['rankxp'],500)

    def test_nickname_matches_ignore_colors_and_reject_ambiguity(self):
        self.setup_runtime()
        self.players.append({'name':'hype fan','number':3})
        self.command('xp','hyp','500',mode='nickname')
        self.assertEqual(self.player['pers']['rankxp'],0)
        self.command('xp','HYPE','500',mode='nickname')
        self.assertEqual(self.player['pers']['rankxp'],500)
        self.players.append({'name':'hype','number':4})
        self.command('reset','hype',mode='nickname')
        self.assertEqual(self.player['stats'][2302],1234)

    def test_full_reset_clears_progression_caches_and_active_ability(self):
        self.setup_runtime()
        self.player.update(maxhealth=110,health=108)
        self.player['pers']['ability']='specialty_armorvest'
        self.command('reset','2')
        for stat in (2301,2302,2303,2326,2350,3201,2501,979,980,981,982):
            self.assertEqual(self.player['stats'][stat],0,stat)
        self.assertEqual(self.player['stats'][501],1) # Freshly available, not completed.
        self.assertEqual(self.player['challengeData'],{'ch_test':1})
        self.assertEqual(self.player['native_rank'],(0,0))
        self.assertEqual(self.player['mirrored'],(0,0,0))
        self.assertEqual(self.player['pers']['lifes'],0)
        self.assertEqual(self.player['score'],0)
        self.assertEqual(self.player['removed_perk'],'specialty_armorvest')
        self.assertEqual((self.player['maxhealth'],self.player['health']),(100,100))
        self.assertEqual(self.player['stats'][2365],2) # Moderation history.
        self.assertEqual(self.player['stats'][988],1) # Camera preference.


if __name__ == '__main__':
    unittest.main()
