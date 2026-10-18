"""Regress catalog-sized network bursts using real GSC and large registries."""
from pathlib import Path
import unittest
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]


class MenuTraffic(unittest.TestCase):
    def test_opening_huge_catalog_does_not_broadcast_every_unlock(self):
        sent=[];level={'mapName':'mp_dr_lithium','numItems':1000,'numCharacters':1000,
                       'numAbilities':8,'numSprays':16,'itemInfo':{0:{'name':'Beretta'}},
                       'abilityInfo':[{'stat':3200+i} for i in range(8)]}
        runtime=Runtime({'level':level,'game':{'state':'readyup'}},
                        {'setClientDvar':lambda player,name,value:sent.append((name,value)),
                         'setClientDvars':lambda player,*pairs:sent.extend(zip(pairs[::2],pairs[1::2])),
                         'braxi\\_rank::isItemUnlocked':lambda *args:False,
                         'braxi\\_rank::isCharacterUnlocked':lambda *args:False,
                         'braxi\\_rank::isAbilityUnlocked':lambda *args:False,
                         'braxi\\_rank::isSprayUnlocked':lambda *args:False})
        runtime.load(ROOT/'src/braxi/_menu_catalog.gsc',{'refresh'})
        player={'pers':{'rank':0,'prestige':0}}
        runtime.call('refresh',receiver=player)
        self.assertEqual(sent,[('apx_menu_map','mp_dr_lithium')])
        # Reopening, promoting and changing perks need no all-catalog snapshot.
        player['pers'].update(rank=69,prestige=10)
        for _ in range(20): runtime.call('refresh',receiver=player)
        self.assertEqual(len(sent),1)
        level['mapName']='mp_deathrun_long'
        runtime.call('refresh',receiver=player)
        self.assertEqual(sent[-1],('apx_menu_map','mp_deathrun_long'))

    def test_refresh_before_rank_load_does_not_send_partial_state(self):
        runtime=Runtime({'level':{'mapName':'mp_dr_lithium'}})
        runtime.load(ROOT/'src/braxi/_menu_catalog.gsc',{'refresh'})
        runtime.call('refresh',receiver={'pers':{}})

    def test_browser_publishes_one_page_even_with_ten_thousand_choices(self):
        commands=[]
        def lookup(table,keycol,key,col):
            return {3:'Example '+str(key),4:'Example description',5:'white',6:'1',7:'white',8:'0'}.get(col,'')
        runtime=Runtime(natives={'tableLookup':lookup,'max':max,'min':min,
            'isUnlocked':lambda *args:True,'braxi\\_content_unlocks::requirement':lambda *args:'Level 1',
            'setClientDvars':lambda player,*pairs:commands.append(pairs)})
        runtime.load(ROOT/'src/braxi/_menu_browser.gsc',{'pageSize','publish'})
        player={'stats':{981:0},'apxBrowser':{'ids':list(range(10000)),'category':'weapon',
                 'page':0,'selected':0,'owned':False}}
        runtime.call('publish',receiver=player)
        self.assertEqual(len(commands),11) # header, eight rows, two selection batches
        self.assertLess(runtime.steps,3000)
        self.assertTrue(all(sum(len(str(v))+4 for v in pairs)<1024 for pairs in commands))


if __name__=='__main__': unittest.main()
