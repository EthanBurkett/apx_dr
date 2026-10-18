"""Weapon-shader isolation, stock gameplay and binary material contracts."""
from pathlib import Path
import json
import struct
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from generate_weapon_shaders import fields,weapon_bytes,scoped_model,MATERIAL,STOCK_MATERIAL


class WeaponShaders(unittest.TestCase):
    def test_scoped_weapon_changes_only_view_and_world_model_fields(self):
        source=(b'WEAPONFILE\\gunModel\\viewmodel_beretta_mp\\worldModel\\weapon_beretta'
                b'\\handModel\\original_hands\\knifeModel\\original_knife'
                b'\\damage\\40\\fireAnim\\stock_fire\\clipSize\\15\\')
        def parse(data):
            parts=data.decode('latin1').split('\\')
            return dict(zip(parts[1::2],parts[2::2]))
        before=parse(source);after=parse(weapon_bytes(source))
        changed={key for key in before if before[key]!=after[key]}
        self.assertEqual(changed,{'gunModel','worldModel'})
        self.assertEqual(after['gunModel'],'apx_m9_rift_view')
        self.assertEqual(after['worldModel'],'apx_m9_rift_world')

    def test_source_weapon_preserves_stock_m9_gameplay_and_animation(self):
        parts=(ROOT/'src/weapons/mp/beretta_mp').read_text(encoding='latin1').split('\\')
        definition=dict(zip(parts[1::2],parts[2::2]))
        expected={'damage':'40','minDamage':'20','fireTime':'0.05','clipSize':'15',
                  'startAmmo':'45','maxAmmo':'90','reloadTime':'1.63','reloadEmptyTime':'1.917',
                  'handModel':'viewmodel_base_viewhands','knifeModel':'viewmodel_knife',
                  'idleAnim':'viewmodel_beretta_idle','fireAnim':'viewmodel_beretta_fire',
                  'reloadAnim':'viewmodel_beretta_reload','adsZoomFov':'65'}
        for key,value in expected.items():self.assertEqual(definition[key],value,key)

    def test_camo_fields_are_deterministic_and_have_independent_channels(self):
        first=fields(64);second=fields(64)
        self.assertEqual(first.tobytes(),second.tobytes())
        self.assertEqual(first.mode,'RGBA')
        channels=first.split()
        self.assertEqual(len({channel.tobytes() for channel in channels}),4)
        for channel in channels:self.assertGreater(channel.getextrema()[1]-channel.getextrema()[0],80)

    def test_scoping_replaces_material_names_without_moving_binary_data(self):
        source=b'\x19\0prefix'+STOCK_MATERIAL.encode()+b'\0rigid-bone-data'+STOCK_MATERIAL.encode()+b'\0tail'
        result=scoped_model(source)
        self.assertEqual(len(result),len(source))
        self.assertEqual(result.replace(MATERIAL.encode(),STOCK_MATERIAL.encode()),source)

    def test_material_models_and_all_lighting_paths_are_packaged(self):
        def cstring(data,offset):
            self.assertLess(offset,len(data))
            return data[offset:].split(b'\0',1)[0].decode('ascii')
        data=(ROOT/'assets/materials'/MATERIAL).read_bytes()
        self.assertEqual(cstring(data,struct.unpack_from('<I',data,0)[0]),MATERIAL)
        self.assertEqual(cstring(data,struct.unpack_from('<I',data,52)[0]),'l_sm_apxrift')
        self.assertEqual(data[48],4)
        self.assertEqual(data[50],2)
        table=struct.unpack_from('<I',data,56)[0]
        textures={}
        for i in range(data[48]):
            semantic,flags,image=struct.unpack_from('<III',data,table+i*12)
            textures[cstring(data,semantic)]=cstring(data,image)
        self.assertEqual(textures['colorMap'],'weapon_beretta_c')
        self.assertEqual(textures['camoMap'],'apx_m9_rift_fields')
        self.assertEqual(textures['specularMap'],'~weapon_beretta_s-r-17g-17b-1~41155d1b')
        for model in ('apx_m9_rift_view','apx_m9_rift_world'):
            raw=(ROOT/'assets/xmodel'/model).read_bytes()
            self.assertIn(MATERIAL.encode()+b'\0',raw)
            self.assertNotIn(STOCK_MATERIAL.encode()+b'\0',raw)
        for prefix in ('l_sm_','l_hsm_','mc_l_sm_','mc_l_hsm_'):
            name=prefix+'apxrift.techset'
            source=(ROOT/'assets/techsets'/name).read_text()
            for state in ('unlit','lit','lit sun','lit sun shadow','lit spot','lit spot shadow','lit omni','lit omni shadow'):
                # Base (non-model) stock techsets have fewer states; every state
                # that exists must use the custom full-color technique.
                import re
                match=re.search('"'+state+r'"\s*:\s*([\w_]+);',source)
                if match:self.assertEqual(match[1],'apx_m9_rift')
            fallback=(ROOT/'assets/techsets/sm2'/name).read_text()
            self.assertNotIn('apx_m9_rift',fallback)
        header=(ROOT/'assets/images/apx_m9_rift_fields.iwi').read_bytes()[:28]
        self.assertEqual(header[:6],b'IWi\x06\x01\x01')
        self.assertEqual(struct.unpack_from('<3H',header,6),(512,512,1))


if __name__=='__main__':unittest.main()
