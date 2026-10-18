from pathlib import Path
import unittest
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]


class EfrHud(unittest.TestCase):
    def test_participants_include_dead_players_but_exclude_spectators(self):
        players=[{'is_player':True,'sessionstate':state,'pers':{'team':team}}
                 for state,team in [('playing','allies'),('dead','allies'),('playing','axis'),('spectator','spectator')]]
        runtime=Runtime(natives={'getAllPlayers':lambda:players})
        runtime.load(ROOT/'src/plugins/_efr.gsc',{'participantCount'})
        self.assertEqual(runtime.call('participantCount'),3)
        players[1]['pers']['team']='spectator'
        self.assertEqual(runtime.call('participantCount'),2)

    def test_countdown_requires_continuous_population(self):
        runtime=Runtime()
        runtime.load(ROOT/'src/plugins/_efr.gsc',{'nextDeadline','secondsLeft'})
        deadline=runtime.call('nextDeadline',3,3,1000,-1,5)
        self.assertEqual(deadline,6000)
        self.assertEqual(runtime.call('nextDeadline',4,3,3000,deadline,5),6000)
        self.assertEqual(runtime.call('secondsLeft',3001,deadline),3)
        deadline=runtime.call('nextDeadline',2,3,4000,deadline,5)
        self.assertEqual(deadline,-1)
        self.assertEqual(runtime.call('nextDeadline',3,3,4500,deadline,5),9500)
        self.assertEqual(runtime.call('secondsLeft',9500,9500),0)

    def test_bar_fraction_handles_empty_clamped_and_reset_profiles(self):
        runtime=Runtime(natives={'braxi\\_prestige::clamp':lambda value,low,high:max(low,min(value,high))})
        runtime.load(ROOT/'src/braxi/_hud_state.gsc',{'fraction'})
        for value,low,high,expected in [(0,0,0,0),(-10,0,100,0),(300,0,100,1),(25,0,100,.25),(994000,966000,994000,1)]:
            self.assertEqual(runtime.call('fraction',value,low,high),expected)


if __name__=='__main__': unittest.main()
