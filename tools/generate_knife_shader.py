"""Create a visible stock knife with a native animated PHASEWIRE material.

Retains the original geometry, adds per-triangle barycentrics in texture UVs,
and retargets the viewmodel's root to the existing BO2 knife animation grip.
Reads the installed SDK; never changes it. Normal builds use checked-in outputs.
"""
import argparse
from pathlib import Path
import struct
from generate_weapon_shaders import ROOT, STATES, save_treatment

STOCK_MATERIAL='mtl_weapon_parabolic_knife'
MATERIAL='apx_phasewire_knife_mat_01'
VIEW='apx_phasewire_knife_view'
WORLD='apx_phasewire_knife_world'
VIEW_PART='apx_phasewire_knife_view_01'


def wire_surface(data):
    """Expand a single rigid v25 surface, preserving normals and positions.

    Triangle UVs encode (0,0), (1,0), (0,1). Do not use vertex colors: the game's
    skinned viewmodel path can replace them with entity lighting/tint colors.
    This is a real triangle wireframe, rather than a texture grid on the blade.
    Reject other layouts instead of guessing at weighted/skinned surface data.
    """
    if len(data)<17 or struct.unpack_from('<2H',data)!=(25,1):
        raise ValueError('Expected one CoD4 v25 knife surface')
    vertices,triangles,rigid=struct.unpack_from('<3H',data,7)
    if vertices!=rigid or len(data)!=17+vertices*60+triangles*6:
        raise ValueError('Expected the stock rigid knife vertex layout')
    indices=struct.unpack_from('<'+str(triangles*3)+'H',data,17+vertices*60)
    if max(indices)>=vertices or triangles*3>65535: raise ValueError('Invalid knife indices')
    header=bytearray(data[:17])
    struct.pack_into('<3H',header,7,triangles*3,triangles,triangles*3)
    output=bytearray(header)
    bary_uv=((0.0,0.0),(1.0,0.0),(0.0,1.0))
    for corner,index in enumerate(indices):
        vertex=bytearray(data[17+index*60:17+(index+1)*60])
        struct.pack_into('<2f',vertex,16,*bary_uv[corner%3])
        output.extend(vertex)
    output.extend(struct.pack('<'+str(len(indices))+'H',*range(len(indices))))
    return bytes(output)


def retarget_parts(data):
    if data.count(b'tag_knife\0')!=1: raise ValueError('Unexpected stock knife root')
    # Raw parts are sequential, NUL-terminated bone names, not pointer tables.
    return data.replace(b'tag_knife\0',b'j_gun\0',1)


def model_bytes(data,replacements):
    if struct.unpack_from('<H',data)[0]!=25: raise ValueError('Expected v25 model')
    for before,after in replacements.items():
        old=before.encode()+b'\0'
        if old not in data: raise ValueError('Missing knife model reference '+before)
        data=data.replace(old,after.encode()+b'\0')
    data=bytearray(data)
    # Expand culling bounds for the shader's maximum visual growth.
    struct.pack_into('<6f',data,3,-36,-36,-36,36,36,36)
    return bytes(data)


def held_weapon(data):
    parts=data.decode('latin1').split('\\');fields=dict(zip(parts[1::2],parts[2::2]))
    fields.update(gunModel=VIEW,worldModel=WORLD,knifeModel='',worldKnifeModel='',playerAnimType='pistol',
                  isHandModelOverridable='1',hudIcon='killiconmelee',killIcon='killiconmelee',
                  ammoCounterIcon='killiconmelee',hudIconRatio='1:1',killIconRatio='1:1',
                  aimDownSight='0',viewFlashEffect='',worldFlashEffect='',
                  viewShellEjectEffect='',worldShellEjectEffect='')
    for field in list(fields):
        if field.endswith('Anim') and field!='playerAnimType': fields[field]=''
    for field in ('idleAnim','emptyIdleAnim','fireAnim','lastShotAnim','reloadAnim','reloadEmptyAnim'):
        fields[field]='viewmodel_bo2_knife_idle'
    for field in ('raiseAnim','firstRaiseAnim','altRaiseAnim','quickRaiseAnim','emptyRaiseAnim'):
        fields[field]='viewmodel_bo2_knife_pullout'
    for field in ('dropAnim','altDropAnim','quickDropAnim','emptyDropAnim'):
        fields[field]='viewmodel_bo2_knife_putaway'
    for field,suffix in (('meleeAnim','swipe'),('meleeChargeAnim','stab'),('sprintInAnim','sprint_in'),
                         ('sprintLoopAnim','sprint_loop'),('sprintOutAnim','sprint_out')):
        fields[field]='viewmodel_bo2_knife_'+suffix
    # Keep existing zero-ammo melee gameplay. Only representation/animations change.
    return ('WEAPONFILE'+''.join('\\'+key+'\\'+value for key,value in fields.items())).encode('latin1')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game-root',type=Path,default=ROOT.parent.parent)
    args=parser.parse_args();raw=args.game_root.resolve()/'raw';assets=ROOT/'assets'
    def write(kind,name,data):
        path=assets/kind/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    stock_part='viewmodel_parabolic_knife1'
    write('xmodelparts',VIEW_PART,retarget_parts((raw/'xmodelparts'/stock_part).read_bytes()))
    write('xmodelsurfs',VIEW_PART,wire_surface((raw/'xmodelsurfs'/stock_part).read_bytes()))
    write('xmodel',VIEW,model_bytes((raw/'xmodel/viewmodel_knife').read_bytes(),
          {stock_part:VIEW_PART,STOCK_MATERIAL:MATERIAL}))
    swaps={STOCK_MATERIAL:MATERIAL}
    for lod in range(3):
        stock='weapon_parabolic_knife_lod'+str(lod)+'1'
        target='apx_phasewire_world_lod'+str(lod)+'1'
        swaps[stock]=target
        parts=raw/'xmodelparts'/stock
        if not parts.exists(): parts=raw/'xmodelparts/weapon_parabolic_knife_lod01'
        write('xmodelparts',target,parts.read_bytes())
        write('xmodelsurfs',target,wire_surface((raw/'xmodelsurfs'/stock).read_bytes()))
    write('xmodel',WORLD,model_bytes((raw/'xmodel/weapon_parabolic_knife').read_bytes(),swaps))
    material=bytearray((raw/'materials'/STOCK_MATERIAL).read_bytes())
    transparent=(raw/'materials/ap_glass_material').read_bytes()
    # Use the installed glass material's transparent sorting/default-state
    # metadata. The technique further forces additive blending and no depth write.
    material[9]=transparent[9]
    material[12:20]=transparent[12:20]
    material[32:48]=transparent[32:48]
    def append(value):
        offset=len(material);material.extend(value.encode()+b'\0');return offset
    struct.pack_into('<I',material,0,append(MATERIAL))
    struct.pack_into('<I',material,52,append('l_sm_apxphasewire'))
    write('materials',MATERIAL,material)
    write('material_properties',MATERIAL,(raw/'material_properties'/STOCK_MATERIAL).read_bytes())
    for prefix in ('l_sm_','l_hsm_','m_l_sm_','m_l_hsm_','mc_l_sm_','mc_l_hsm_'):
        # No opaque depth prepass, shadow silhouette or stock extra-light pass:
        # the areas between the wires must remain actually transparent.
        text='// Transparent triangle wires; no solid depth/shadow pass.\n'
        for state in sorted(STATES): text+='"'+state+'": apx_phasewire;\n'
        write('techsets',prefix+'apxphasewire.techset',text.encode())
        write('techsets/sm2',prefix+'apxphasewire.techset',text.replace('apx_phasewire;','apx_phasewire_sm2;').encode())
    weapon=ROOT/'src/weapons/mp/knife_mp';weapon.write_bytes(held_weapon(weapon.read_bytes()))
    save_treatment('knife_mp',{'effect':'PHASEWIRE','category':'knife','catalog_id':0,
        'material':MATERIAL,'techset':'l_sm_apxphasewire','view_model':VIEW,'world_model':WORLD,
        'sm2':'transparent wireframe with fixed relative line width',
        'gameplay':'existing melee damage, ammo, reach and secondary slot; visual growth only'})
    print('Generated held stock knife: j_gun grip, triangle wireframe, three world LODs, no new weapon ID.')


if __name__=='__main__':main()
