"""Blender-only export of the M9 or default knife for native D3D9 shader review.

Requires the pinned importer and asset view prepared by render-previews.ps1
-PrepareOnly. Does not modify source meshes or the live Blender scene.
"""

import bpy,json,sys,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from render_models import StudioImporter,Loader,GAME_VERSION
bpy.ops.wm.read_factory_settings(use_empty=True)
assets=root/'build/model-render/assets'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--effect',choices=('rift','phasewire'),default='rift')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
model='apx_phasewire_knife_view' if args.effect=='phasewire' else 'weapon_beretta'
importer=StudioImporter(str(assets));loader=Loader(importer=importer)
loader.import_xmodel(asset_path=str(assets),file_path=str(assets/'xmodel'/model),selected_version=GAME_VERSION.CoD4,angles=(0.,0.,0.),origin=(0.,0.,0.),scale=(1.,1.,1.))
triangles=[]
for obj in bpy.context.scene.objects:
 if obj.type!='MESH':continue
 mesh=obj.data;mesh.calc_loop_triangles()
 if not mesh.uv_layers:continue
 uv=mesh.uv_layers.active.data
 for tri in mesh.loop_triangles:
  for loop_index in tri.loops:
   loop=mesh.loops[loop_index];v=mesh.vertices[loop.vertex_index]
   point=obj.matrix_world@v.co
   normal=(obj.matrix_world.to_3x3()@loop.normal).normalized()
   tex=uv[loop_index].uv
   # PHASEWIRE UVs are shader data, not an image: preserve their exact basis.
   row=[*point,*normal,tex.x,tex.y if args.effect=='phasewire' else 1.0-tex.y]
   triangles.append(row)
target='knife-mesh.json' if args.effect=='phasewire' else 'm9-mesh.json'
output=root/'build/shader-lab'/target;output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(triangles))
print('Exported real',model,'mesh:',len(triangles)//3,'triangles')
