"""Blender-only batch export of registered weapon meshes for native D3D9 review.

Requires the pinned importer and read-only model assets from -PrepareOnly.
Exports separate material batches so protected lenses/attachments stay stock.
"""
import bpy,json,sys,argparse,struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from render_models import StudioImporter,Loader,GAME_VERSION
assets=root/'build/model-render/assets'
registry=json.loads((root/'ui/weapon_shaders.json').read_text())['weapons']
effects={('phasewire' if key=='knife_mp' else 'rift' if key=='beretta_mp' else record['pixel_shader'].replace('apx_base_','')):record for key,record in registry.items()}
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--effect',choices=tuple(effects),default='rift')
parser.add_argument('--all',action='store_true')
parser.add_argument('--viewmodel',action='store_true',help='Export the actual first-person gun mesh instead of its world model.')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])


def color_texture(name):
 data=(assets/'materials'/name).read_bytes()
 def string(offset):return data[offset:].split(b'\0',1)[0].decode('ascii')
 table=struct.unpack_from('<I',data,56)[0]
 for i in range(data[48]):
  semantic,flags,image=struct.unpack_from('<3I',data,table+i*12)
  if string(semantic)=='colorMap':return string(image)
 return '$white'


for effect in effects if args.all else (args.effect,):
 bpy.ops.wm.read_factory_settings(use_empty=True)
 record=effects[effect];model=record['view_model'] if effect=='phasewire' or args.viewmodel else record['world_model']
 custom=set(record.get('materials',[record['material']]))
 loader=Loader(importer=StudioImporter(str(assets)))
 loader.import_xmodel(asset_path=str(assets),file_path=str(assets/'xmodel'/model),selected_version=GAME_VERSION.CoD4,angles=(0.,0.,0.),origin=(0.,0.,0.),scale=(1.,1.,1.))
 triangles=[];batches=[]
 for obj in bpy.context.scene.objects:
  if obj.type!='MESH':continue
  mesh=obj.data;mesh.calc_loop_triangles()
  if not mesh.uv_layers:continue
  uv=mesh.uv_layers.active.data;first=len(triangles)
  material=mesh.materials[0].name
  for tri in mesh.loop_triangles:
   for loop_index in tri.loops:
    loop=mesh.loops[loop_index];v=mesh.vertices[loop.vertex_index]
    point=obj.matrix_world@v.co
    normal=(obj.matrix_world.to_3x3()@loop.normal).normalized();tex=uv[loop_index].uv
    triangles.append([*point,*normal,tex.x,1.0-tex.y if effect=='rift' else tex.y])
  batches.append(dict(first=first,count=len(triangles)-first,material=material,custom=material in custom,color_texture=color_texture(material)))
 target={'phasewire':'knife','rift':'m9'}.get(effect,effect)+('-view-mesh.json' if args.viewmodel else '-mesh.json')
 output=root/'build/shader-lab'/target;output.parent.mkdir(parents=True,exist_ok=True)
 output.write_text(json.dumps(dict(vertices=triangles,batches=batches)))
 print('Exported',effect,model,len(triangles)//3,'triangles,',len(batches),'material batches',flush=True)
