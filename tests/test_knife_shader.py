"""Held default knife and real transparent triangle-wire asset contracts."""
from pathlib import Path
import struct
import re
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from generate_knife_shader import wire_surface,retarget_parts,held_weapon,VIEW,WORLD,VIEW_PART
from generate_weapon_shaders import save_treatment


class KnifeShader(unittest.TestCase):
    def test_both_knife_vertex_profiles_use_the_confirmed_uv_input_contract(self):
        for profile in ('2_0','3_0'):
            shader=(ROOT/'src/shaders'/('vs_'+profile+'_apx_phasewire.hlsl')).read_text()
            inputs=re.search(r'struct Input\s*\{([^}]+)\}',shader)[1]
            semantics=set(re.findall(r':\s*(\w+)',inputs))
            self.assertEqual(semantics,{'POSITION','TEXCOORD0'},'skinned knife must use UV data, not replacement vertex colors')

    def test_regenerating_a_treatment_preserves_the_other_weapon(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'ui').mkdir();(root/'manifests').mkdir()
            with patch('generate_weapon_shaders.ROOT',root):
                def entry(label):return {'material':label,'view_model':label+'_view','world_model':label+'_world'}
                save_treatment('beretta_mp',entry('rift'))
                save_treatment('knife_mp',entry('wire'))
                save_treatment('beretta_mp',entry('updated_rift'))
            manifest=(root/'manifests/18-weapon-shaders.csv').read_text()
            self.assertIn('material,wire\n',manifest)
            self.assertIn('material,updated_rift\n',manifest)
            self.assertNotIn('material,rift\n',manifest)

    def surface(self):
        header=struct.pack('<2H3s3H4s',25,1,b'\0'*3,4,2,4,b'\0'*4)
        vertices=b''.join(struct.pack('<3f4B11f',0,0,1,255,255,255,255,
                     i*.1,i*.2,1,0,0,0,1,0,i,0,0) for i in range(4))
        return header+vertices+struct.pack('<6H',0,1,2,2,1,3)

    def test_barycentric_expansion_preserves_every_triangle_attribute(self):
        original=self.surface();expanded=wire_surface(original)
        self.assertEqual(struct.unpack_from('<3H',expanded,7),(6,2,6))
        self.assertEqual(struct.unpack_from('<6H',expanded,17+6*60),tuple(range(6)))
        for corner,index in enumerate((0,1,2,2,1,3)):
            before=original[17+index*60:17+(index+1)*60]
            after=expanded[17+corner*60:17+(corner+1)*60]
            self.assertEqual(before[:16]+before[24:],after[:16]+after[24:])
            self.assertEqual(struct.unpack_from('<2f',after,16),((0,0),(1,0),(0,1))[corner%3])
            self.assertEqual(after[12:16],bytes((255,255,255,255)))

    def test_unsupported_or_invalid_surface_is_rejected(self):
        for offset,value in ((0,20),(2,2),(11,0),(17+4*60,99)):
            data=bytearray(self.surface());struct.pack_into('<H',data,offset,value)
            with self.assertRaises(ValueError):wire_surface(data)

    def test_grip_retarget_does_not_move_bone_transforms(self):
        source=b'rigid-transform-data\0tag_knife\0tag_knife_fx\0trailer'
        result=retarget_parts(source)
        self.assertEqual(result.replace(b'j_gun\0',b'tag_knife\0'),source)
        self.assertIn(b'tag_knife_fx\0',result)

    def test_default_knife_has_visible_model_matching_idle_and_melee(self):
        source=(ROOT/'src/weapons/mp/knife_mp').read_bytes()
        self.assertEqual(held_weapon(source),source,'generator must be idempotent')
        parts=source.decode('latin1').split('\\');fields=dict(zip(parts[1::2],parts[2::2]))
        self.assertEqual(fields['gunModel'],VIEW)
        self.assertEqual(fields['worldModel'],WORLD)
        self.assertEqual(fields['playerAnimType'],'pistol')
        self.assertEqual(fields['idleAnim'],'viewmodel_bo2_knife_idle')
        self.assertEqual(fields['emptyIdleAnim'],fields['idleAnim'])
        self.assertEqual(fields['meleeAnim'],'viewmodel_bo2_knife_swipe')
        self.assertEqual(fields['meleeChargeAnim'],'viewmodel_bo2_knife_stab')
        self.assertEqual(fields['isHandModelOverridable'],'1')
        self.assertEqual(fields['meleeDamage'],'135')
        self.assertEqual(fields['meleeTime'],'0.7')
        self.assertEqual(fields['maxAmmo'],'0')
        self.assertEqual(fields['clipSize'],'0')
        self.assertFalse(any(value.startswith('viewmodel_claymore_') for value in fields.values()))
        self.assertEqual(fields['viewFlashEffect'],'')

    def test_hydrated_knife_assets_match_grip_and_transparent_paths(self):
        parts=(ROOT/'assets/xmodelparts'/VIEW_PART).read_bytes()
        self.assertIn(b'j_gun\0',parts)
        self.assertNotIn(b'tag_knife\0',parts)
        for animation in ('idle','pullout','putaway','swipe','stab','sprint_in','sprint_loop','sprint_out'):
            self.assertIn(b'j_gun\0',(ROOT/'assets/xanim'/('viewmodel_bo2_knife_'+animation)).read_bytes())
        for name in (VIEW_PART,*('apx_phasewire_world_lod'+str(lod)+'1' for lod in range(3))):
            data=(ROOT/'assets/xmodelsurfs'/name).read_bytes()
            count,faces,rigid=struct.unpack_from('<3H',data,7)
            self.assertEqual(count,faces*3)
            self.assertEqual(count,rigid)
            self.assertEqual(len(data),17+count*60+faces*6)
            uvs={struct.unpack_from('<2f',data,17+i*60+16) for i in range(count)}
            self.assertEqual(uvs,{(0,0),(1,0),(0,1)})
        material=(ROOT/'assets/materials/apx_phasewire_knife_mat_01').read_bytes()
        self.assertEqual(material[9],43,'use transparent sorting rather than opaque weapon sorting')
        for prefix in ('l_sm_','l_hsm_','m_l_sm_','m_l_hsm_','mc_l_sm_','mc_l_hsm_'):
            for folder in ('techsets','techsets/sm2'):
                source=(ROOT/'assets'/folder/(prefix+'apxphasewire.techset')).read_text()
                self.assertNotIn('depth prepass',source)
                self.assertNotIn('build shadowmap',source)
                self.assertNotIn('lp_add_',source)


if __name__=='__main__':unittest.main()
