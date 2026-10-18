"""Base collection coverage, gameplay preservation and scoped material isolation."""
import json
from pathlib import Path
import struct
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from generate_base_weapon_shaders import SPECS,scoped_weapon,material_bytes


def fields(data):
    parts=data.decode('latin1').split('\\');return dict(zip(parts[1::2],parts[2::2]))


class BaseWeaponShaders(unittest.TestCase):
    def test_every_base_primary_has_its_own_registered_effect(self):
        registry=json.loads((ROOT/'ui/weapon_shaders.json').read_text())['weapons']
        primaries=[registry['beretta_mp']]+[registry[s['weapon']] for s in SPECS if s['id'] is not None]
        self.assertEqual({r['catalog_id'] for r in primaries},set(range(8)))
        records=[registry[s['weapon']] for s in SPECS]
        self.assertEqual(len({r['pixel_shader'] for r in records}),len(SPECS))
        self.assertEqual(len({r['effect'] for r in records}),len(SPECS))
        programs=[(ROOT/'src/shaders'/('ps_3_0_'+r['pixel_shader']+'.hlsl')).read_bytes() for r in records]
        self.assertEqual(len(set(programs)),len(SPECS))
        self.assertEqual(registry['beretta_mp']['effect'],'RIFTHEART')
        self.assertEqual(registry['knife_mp']['effect'],'PHASEWIRE')

    def test_all_original_weapon_fields_survive_except_the_two_models(self):
        for spec in SPECS:
            with self.subTest(weapon=spec['weapon']):
                original=(ROOT/'art/weapons/base-definitions'/spec['weapon']).read_bytes()
                current=(ROOT/'src/weapons/mp'/spec['weapon']).read_bytes()
                before=fields(original);after=fields(current)
                self.assertEqual(current,scoped_weapon(original,spec))
                self.assertEqual({k for k in before if before[k]!=after[k]},{'gunModel','worldModel'})
                self.assertEqual(before.keys(),after.keys())
                for key in ('handModel','knifeModel','fireAnim','meleeAnim','reloadAnim','damage','clipSize','adsZoomFov'):
                    self.assertEqual(before.get(key),after.get(key),key)

    def test_invalid_original_definition_is_rejected(self):
        with self.assertRaises(ValueError):scoped_weapon(b'WEAPONFILE\\gunModel\\something_else\\',SPECS[0])

    def test_material_relocation_preserves_texture_and_constant_tables(self):
        original=bytearray(180);struct.pack_into('<2I',original,56,64,100)
        result=material_bytes(original,'example','tech')
        self.assertEqual(result[56:180],original[56:180])
        for offset,expected in ((0,b'example'),(52,b'tech')):
            pointer=struct.unpack_from('<I',result,offset)[0]
            self.assertEqual(result[pointer:].split(b'\0',1)[0],expected)

    def test_hydrated_collection_has_scoped_models_and_protected_lenses(self):
        registry=json.loads((ROOT/'ui/weapon_shaders.json').read_text())['weapons']
        manifest=(ROOT/'manifests/18-weapon-shaders.csv').read_text()
        for spec in SPECS:
            record=registry[spec['weapon']]
            for name in record['materials']:
                self.assertTrue(record['model_only'])
                self.assertNotIn('material,'+name+'\n',manifest,'weapon dependencies should not allocate unused standalone materials')
                data=(ROOT/'assets/materials'/name).read_bytes()
                pointer=struct.unpack_from('<I',data,0)[0]
                self.assertEqual(data[pointer:].split(b'\0',1)[0].decode(),name)
                self.assertEqual(data[9]==43,spec['key']=='holo')
            for key in ('view_model','world_model'):
                data=(ROOT/'assets/xmodel'/record[key]).read_bytes()
                for material in record['materials']:self.assertIn(material.encode()+b'\0',data)
                for original in spec['materials']:self.assertNotIn(original.encode()+b'\0',data)
        protected={'holo':['mtl_weapon_trinium_sight','mtl_weapon_trinium_sight_glow'],
                   'frost':['mtl_weapon_m14_scope_lens','mtl_weapon_acog_reticle','mtl_weapon_bullet'],
                   'void':['mtl_weapon_m14_scope_lens','mtl_weapon_acog_reticle','mtl_weapon_bullet']}
        for effect,names in protected.items():
            data=(ROOT/'assets/xmodel'/('apx_'+effect+'_view')).read_bytes()
            for name in names:self.assertIn(name.encode()+b'\0',data)


if __name__=='__main__':unittest.main()
