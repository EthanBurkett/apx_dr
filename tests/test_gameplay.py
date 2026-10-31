from itertools import product
from pathlib import Path
import unittest

from gsc_runtime import Runtime

SOURCE = Path(__file__).resolve().parents[1] / 'src/braxi'


class GameplayDecisions(unittest.TestCase):
    def test_spectator_public_chat_is_enabled_on_initialization_and_restart(self):
        settings={}
        runtime=Runtime({'level':{}},{'isSplitScreen':lambda:False,
                         'getDvarInt':lambda name:1,'setDvar':lambda key,value:settings.update({key:value})})
        runtime.load(SOURCE/'_cod4stuff.gsc',{'main'})
        for _ in range(2):
            settings['g_deadChat']=0
            runtime.call('main')
            self.assertEqual(settings['g_deadChat'],1)

    def selection(self, previous=-1, random_last=False):
        runtime = Runtime({'level': {'dvar': {'dont_make_peoples_angry': True}}},
                          {'getDvarInt': lambda name: previous,
                           'randomInt': lambda size: size - 1 if random_last else 0})
        runtime.load(SOURCE / '_selection.gsc', {'chooseCandidate'})
        return runtime

    def test_empty_activator_pool_returns_without_retrying(self):
        runtime = self.selection()
        self.assertIsNone(runtime.call('chooseCandidate', [], True))
        self.assertLess(runtime.steps, 20)

    def test_spectators_and_non_players_are_not_candidates(self):
        players = [{'is_player': True, 'number': 0, 'sessionstate': 'spectator', 'pers': {'team': 'spectator'}},
                   {'is_player': True, 'number': 1, 'sessionstate': 'playing', 'pers': {'team': 'allies'}}, None]
        runtime = Runtime({'level': {'dvar': {'dont_pick_spec': True}}},
                          {'getAllPlayers': lambda: players,
                           'isReallyAlive': lambda player: player['sessionstate'] == 'playing'})
        runtime.load(SOURCE / '_selection.gsc', {'getCandidates'})
        candidates = runtime.call('getCandidates')
        self.assertEqual([player['number'] for player in candidates.values()], [1])
        self.assertEqual(players[1]['pers']['activator'], 0)

    def test_activator_role_is_claimed_before_spawn_and_not_claimed_twice(self):
        level = {'dvar': {'dont_pick_spec': True, 'dont_make_peoples_angry': True}, 'activators': 0, 'activatorKilled': False}
        player = {'is_player': True, 'number': 3, 'sessionstate': 'playing',
                  'pers': {'team': 'allies', 'activator': 0}, 'name': 'Test player', 'guid': 'test-guid'}
        spawned = []
        def spawn(receiver):
            self.assertEqual(level['activators'], 1)
            self.assertIs(level['activ'], receiver)
            self.assertEqual(receiver['pers']['team'], 'axis')
            spawned.append(receiver)
        runtime = Runtime({'level': level, 'game': {'state': 'playing'}},
                          {'getAllPlayers': lambda: [player], 'isReallyAlive': lambda player: True,
                           'getDvarInt': lambda name: -1, 'setDvar': lambda *args: None,
                           'braxi\\_teams::setTeam': lambda player, team: player['pers'].update(team=team),
                           'braxi\\_player::spawnPlayer': spawn,
                           'braxi\\_rank::giveRankXP': lambda *args: None,
                           'notify': lambda *args: None, 'bxLogPrint': lambda text: None,
                           'iPrintlnBold': lambda text: None,'iPrintln':lambda text:None})
        runtime.load(SOURCE / '_selection.gsc', {'getCandidates', 'chooseCandidate', 'pick'})
        runtime.call('pick', False)
        runtime.call('pick', False)
        self.assertEqual(len(spawned), 1)
        self.assertEqual(player['pers']['activator'], 1)

    def test_fair_selection_uses_lowest_count_for_every_candidate(self):
        for counts in product(range(3), repeat=4):
            candidates = [{'number': i, 'pers': {'activator': count}} for i, count in enumerate(counts)]
            for random_last in (False, True):
                runtime = self.selection(random_last=random_last)
                player = runtime.call('chooseCandidate', candidates, True)
                self.assertEqual(player['pers']['activator'], min(counts), counts)
                self.assertLess(runtime.steps, 300)

    def test_previous_activator_is_avoided_only_when_an_alternative_exists(self):
        candidates = [{'number': i, 'pers': {'activator': 0}} for i in range(3)]
        self.assertNotEqual(self.selection(previous=0).call('chooseCandidate', candidates, False)['number'], 0)
        self.assertEqual(self.selection(previous=0).call('chooseCandidate', candidates[:1], False)['number'], 0)

    def test_item_and_ability_bounds_reject_count_and_negative_ids(self):
        level = {'numItems': 2, 'numAbilities': 2, 'itemInfo': [{'rank': 0,'prestige':0}, {'rank': 1,'prestige':0}],
                 'abilityInfo': [{'stat': 100}, {'stat': 101}]}
        player = {'pers': {'rank': 5}, 'stats': {100: 1, 101: 1}}
        for name in ('isItemUnlocked', 'isAbilityUnlocked'):
            runtime = Runtime({'level': level})
            runtime.load(SOURCE / '_unlocks.gsc', {name})
            runtime.load(SOURCE / '_content_unlocks.gsc', {'meets'})
            runtime.definitions['braxi\\_content_unlocks::meets']=runtime.definitions['meets']
            for index in (-1, 2, 999999):
                self.assertFalse(runtime.call(name, index, receiver=player), (name, index))
            self.assertTrue(runtime.call(name, 1, receiver=player))

    def test_vote_wrap_handles_arbitrarily_large_offsets_and_empty_lists(self):
        for size in range(6):
            runtime = Runtime({'level': {'maps': list(range(size))}})
            runtime.load(SOURCE / '_vote_hud.gsc', {'getIndex'})
            for index in (-100, -8, -1, 0, 3, 7, 100):
                self.assertEqual(runtime.call('getIndex', index), index % size if size else 0)

    def test_current_map_is_filtered_even_when_rotation_is_small(self):
        runtime = Runtime()
        runtime.load(SOURCE / '_vote_maps.gsc', {'getRandomSelection', 'isLegal'})
        maps = [{'mapname': name} for name in ('current', 'alternate', 'third')]
        selection = runtime.call('getRandomSelection', maps, 5, 'current')
        self.assertEqual({item['mapname'] for item in selection.values()}, {'alternate', 'third'})
        self.assertEqual(runtime.call('getRandomSelection', [], 5, 'current'), {})

    def test_map_labels_handle_short_and_multiword_names(self):
        runtime = Runtime(natives={'toLower': str.lower})
        runtime.load(SOURCE / '_maps.gsc', {'getMapNameString'})
        for name, expected in [('mp_backlot', 'backlot'), ('mp_dr_sm_world', 'sm world'),
                               ('mp_deathrun_short_v3', 'short v3'), ('oddname', 'oddname')]:
            self.assertEqual(runtime.call('getMapNameString', name), expected)

    def test_rotation_parser_ignores_duplicates_malformed_entries_and_trailing_map(self):
        rotation = 'gametype war map mp_dr_one map mp_dr_one map invalid map mp_dr_two map'
        runtime = Runtime(natives={'getDvar': lambda name: rotation, 'getDvarInt': lambda name:0, 'toLower': str.lower,
                                   'getSubStr': lambda text, start, end: text[start:end],
                                   'spawnstruct': lambda: {}, 'getdvar': lambda name: 'deathrun'})
        runtime.load(SOURCE / '_vote_maps.gsc', {'getMaprotation', 'addMapItem'})
        runtime.load(SOURCE / '_maps.gsc', {'getMapNameString'})
        runtime.definitions['braxi\\_maps::getMapNameString'] = runtime.definitions['getMapNameString']
        maps = runtime.call('getMaprotation')
        self.assertEqual([item['mapname'] for item in maps.values()], ['mp_dr_one', 'mp_dr_two'])

    def test_life_cannot_be_spent_outside_a_live_jumper_round(self):
        for state, team, session in [('endmap', 'allies', 'spectator'),
                                     ('round ended', 'allies', 'spectator'),
                                     ('playing', 'axis', 'spectator'),
                                     ('playing', 'allies', 'playing')]:
            runtime = Runtime({'game': {'state': state}, 'level': {'dvar': {'allowLifes': True}}})
            runtime.load(SOURCE / '_lives.gsc', {'useLife'})
            player = {'pers': {'team': team, 'lifes': 2}, 'sessionstate': session}
            runtime.call('useLife', receiver=player)
            self.assertEqual(player['pers']['lifes'], 2)


if __name__ == '__main__':
    unittest.main()
