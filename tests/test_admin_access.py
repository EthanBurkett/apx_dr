"""Whois runtime data and server-owned VIP identity matching."""
from pathlib import Path
import unittest
from gsc_runtime import Runtime

ROOT = Path(__file__).resolve().parents[1]


class AdminAccess(unittest.TestCase):
    def test_whois_uses_configured_warning_stat_and_preserves_guid(self):
        for stat in (2365, 2870):
            for warnings in (0, 4):
                with self.subTest(stat=stat, warnings=warnings):
                    reads = []
                    player = {'name': 'hype', 'health': 100, 'sessionstate': 'playing',
                              'pers': {'team': 'allies'}, 'stats': {stat: warnings}}
                    def read_stat(target, number):
                        self.assertIsInstance(number, int)
                        reads.append(number)
                        return target['stats'][number]
                    runtime = Runtime({'level': {'dvar': {'warns_stat': stat}}}, {
                        'getStat': read_stat, 'getGuid': lambda target: '0'})
                    runtime.load(ROOT/'src/braxi/_menus.gsc', {'describePlayer'})
                    result = runtime.call('describePlayer', player)
                    self.assertEqual(reads, [stat])
                    self.assertIn('Warnings: ^2'+str(warnings), result)
                    self.assertIn('Guid: ^20^7.', result)
                    self.assertIn('Health: ^2100', result)

    def test_vip_guid_matching_rejects_shared_zero_and_requires_complete_identity(self):
        for guid, whitelist, expected in (
            ('0', '0', False), ('', '', False), ('full-identity', 'identity', False),
            ('full-identity', 'other;FULL-IDENTITY', True),
            ('other-player', 'full-identity', False)):
            with self.subTest(guid=guid, whitelist=whitelist):
                player = {'pers': {'admin': False}, 'dvars': {}}
                def set_dvars(target, *pairs):
                    target['dvars'].update(zip(pairs[::2], pairs[1::2]))
                runtime = Runtime(natives={
                    'getGuid': lambda target: guid, 'getDvar': lambda name: whitelist,
                    'toLower': lambda value: value.lower(),
                    'isSubStr': lambda value, part: part in value,
                    'setClientDvars': set_dvars,
                    'setClientDvar': lambda target, name, value: target['dvars'].__setitem__(name, value)})
                runtime.load(ROOT/'src/braxi/_menu_service.gsc', {'load', 'syncAccess', 'allowed'})
                runtime.call('load', receiver=player)
                self.assertEqual(bool(player['pers']['vip']), expected)
                self.assertEqual(bool(player['dvars']['apx_access_vip']), expected)


if __name__ == '__main__':
    unittest.main()
