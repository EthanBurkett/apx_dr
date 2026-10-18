from pathlib import Path
import unittest
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]

class ContentUnlocks(unittest.TestCase):
    def test_prestige_and_level_boundaries_across_all_tiers(self):
        runtime=Runtime()
        runtime.load(ROOT/'src/braxi/_content_unlocks.gsc',{'meets'})
        for tier in range(51):
            for rank in (0,14,29,44,59,69):
                for player_tier in range(51):
                    for player_rank in (0,max(0,rank-1),rank,69):
                        player={'pers':{'prestige':player_tier,'rank':player_rank}}
                        expected=(player_tier,player_rank)>=(tier,rank)
                        runtime.steps=0
                        self.assertEqual(runtime.call('meets',tier,rank,receiver=player),expected,
                                         (tier,rank,player_tier,player_rank))

    def test_legacy_profile_without_prestige_uses_base_tier(self):
        runtime=Runtime(); runtime.load(ROOT/'src/braxi/_content_unlocks.gsc',{'meets'})
        player={'pers':{'rank':69}}
        self.assertTrue(runtime.call('meets',0,69,receiver=player))
        self.assertFalse(runtime.call('meets',1,0,receiver=player))

    def test_connect_before_rank_load_uses_starting_level(self):
        runtime=Runtime(); runtime.load(ROOT/'src/braxi/_content_unlocks.gsc',{'meets'})
        player={'pers':{}}
        self.assertTrue(runtime.call('meets',0,0,receiver=player))
        self.assertFalse(runtime.call('meets',0,1,receiver=player))
        self.assertFalse(runtime.call('meets',1,0,receiver=player))

    def test_knife_and_arms_saves_are_preserved_until_rank_is_loaded(self):
        player={'pers':{},'stats':{2405:8,2406:9}}
        calls=[]
        runtime=Runtime({'level':{'numCharacters':1,'characterInfo':{0:{'enabled':True}},
                                  'numItems':1,'itemInfo':{0:{'enabled':True}},'numSprays':1,'numAbilities':1,'numKnives':9,'numGloves':13}},
                        {'getStat':lambda p,id:p['stats'].get(id,0),
                         'setStat':lambda p,id,value:p['stats'].__setitem__(id,value),
                         'setClientDvars':lambda *a:None,
                         'braxi\\_rank::isCharacterUnlocked':lambda *a:True,
                         'braxi\\_rank::isItemUnlocked':lambda *a:True,
                         'braxi\\_rank::isSprayUnlocked':lambda *a:True,
                         'braxi\\_content_unlocks::knifeUnlocked':lambda p,id:calls.append(id) or False,
                         'braxi\\_content_unlocks::glovesUnlocked':lambda p,id:False})
        runtime.load(ROOT/'src/braxi/_profile.gsc',{'sanitizeCustomization'})
        runtime.call('sanitizeCustomization',receiver=player)
        self.assertEqual(player['stats'][2405],8)
        self.assertEqual(player['stats'][2406],9)
        self.assertEqual(calls,[])
        player['pers'].update(rank=0,prestige=0)
        runtime.call('sanitizeCustomization',receiver=player)
        self.assertEqual(player['stats'][2405],0)
        self.assertEqual(player['stats'][2406],0)
        self.assertEqual(calls,[8])

if __name__=='__main__': unittest.main()
