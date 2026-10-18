from pathlib import Path
import unittest
from gsc_runtime import Runtime

ROOT=Path(__file__).resolve().parents[1]


class Preferences(unittest.TestCase):
    def setUp(self):
        self.player={'stats':{988:1},'pers':{},'cvars':{}}
        def set_dvars(player,*items):
            player['cvars'].update(zip(items[::2],items[1::2]))
        self.runtime=Runtime(natives={
            'setStat':lambda player,key,value:player['stats'].__setitem__(key,value),
            'setClientDvars':set_dvars,
            'isSubStr':lambda text,part:part in text,
        })
        self.runtime.load(ROOT/'src/braxi/_preferences.gsc',{'defaults','load','apply','set'})
        self.runtime.load(ROOT/'src/braxi/_admin_progression.gsc',{'parseInteger'})
        self.runtime.definitions['braxi\\_admin_progression::parseInteger']=self.runtime.definitions['parseInteger']

    def test_defaults_and_corrupt_saved_values(self):
        self.runtime.call('load',receiver=self.player)
        self.assertEqual(self.player['stats'][2401],90)
        self.assertEqual(self.player['cvars']['cg_fovScale'],1.125)
        self.player['stats'].update({2401:999,2402:6,2403:-1,2404:2})
        self.runtime.call('load',receiver=self.player)
        self.assertEqual([self.player['stats'][i] for i in range(2401,2405)],[90,0,0,0])

    def test_settings_validate_and_survive_load(self):
        self.runtime.call('load',receiver=self.player)
        self.assertTrue(self.runtime.call('set','fov','110',receiver=self.player))
        self.assertTrue(self.runtime.call('set','fullbright','1',receiver=self.player))
        for key,value in [('fov','121'),('fullbright','2'),('fov','90;quit'),('rank','70')]:
            self.assertFalse(self.runtime.call('set',key,value,receiver=self.player))
        self.runtime.call('load',receiver=self.player)
        self.assertEqual(self.player['stats'][2401],110)
        self.assertEqual(self.player['cvars']['r_fullbright'],1)
        self.assertEqual(self.player['cvars']['cg_fovScale'],1.375)

    def test_privileged_routes_require_entitlement(self):
        self.runtime.load(ROOT/'src/braxi/_menu_service.gsc',{'allowed'})
        for access in ('admin','vip','unknown'):
            self.assertFalse(self.runtime.call('allowed',access,receiver=self.player))
        self.assertTrue(self.runtime.call('allowed','public',receiver=self.player))
        self.player['pers'].update(admin=True,vip=True)
        for access in ('admin','vip'):
            self.assertTrue(self.runtime.call('allowed',access,receiver=self.player))


if __name__=='__main__': unittest.main()
