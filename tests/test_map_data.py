import csv
from pathlib import Path
import unittest

from gsc_runtime import Runtime

ROOT = Path(__file__).resolve().parents[1]


class MapDataBehavior(unittest.TestCase):
    def setUp(self):
        self.tables = {}
        for path in (ROOT / 'src/mp').glob('apx_*.csv'):
            self.tables['mp/' + path.name] = list(csv.reader(path.read_text().splitlines()))

    def lookup(self, table, search_column, key, result_column):
        for row in self.tables[table]:
            if row[search_column] == str(key): return row[result_column]
        return ''

    def test_finish_triggers_retain_coordinates_and_have_a_target_name(self):
        for row in self.tables['mp/apx_time_triggers.csv']:
            created = []
            def spawn(*args):
                entity = {'arguments': args}; created.append(entity); return entity
            runtime = Runtime({'level': {'mapName': row[0]}},
                              {'tableLookup': self.lookup, 'spawn': spawn, 'getEntArray': lambda *args: []})
            runtime.load(ROOT / 'src/braxi/_map_data.gsc', {'createTimeTrigger'})
            runtime.call('createTimeTrigger')
            self.assertEqual(len(created), 1, row[0])
            self.assertEqual(created[0]['targetname'], 'endmap_trig')
            self.assertEqual(created[0]['arguments'][1], tuple(map(float, row[1:4])))
            self.assertGreater(float(row[4]), 0)
            self.assertGreater(float(row[5]), 0)

    def test_map_supplied_finish_trigger_is_not_duplicated(self):
        runtime = Runtime({'level': {'mapName': 'mp_deathrun_long'}},
                          {'getEntArray': lambda *args: [{}]})
        runtime.load(ROOT / 'src/braxi/_map_data.gsc', {'createTimeTrigger'})
        runtime.call('createTimeTrigger')  # No spawn/table natives: either call would fail this test.

    def test_missing_trap_entities_are_filtered(self):
        runtime = Runtime({'level': {'mapName': 'mp_deathrun_long'}},
                          {'tableLookup': self.lookup,
                           'getEnt': lambda name, field: {'name': name} if name == 'trigger1' else None})
        runtime.load(ROOT / 'src/braxi/_map_data.gsc', {'findTrapTriggers'})
        triggers = runtime.call('findTrapTriggers')
        self.assertEqual(list(triggers.values()), [{'name': 'trigger1'}])

    def test_only_current_map_collisions_are_created(self):
        created = []
        runtime = Runtime({'level': {'mapName': 'mp_deathrun_long'}},
                          {'tableLookup': self.lookup, 'spawnCollision': lambda *args: created.append(args)})
        runtime.load(ROOT / 'src/braxi/_map_data.gsc', {'createCollisions'})
        runtime.call('createCollisions')
        expected = [row for row in self.tables['mp/apx_collisions.csv'] if row[1] == 'mp_deathrun_long']
        self.assertEqual(len(created), len(expected))
        self.assertEqual(len(set(created)), len(created))


if __name__ == '__main__': unittest.main()
