"""Blender-only export of the stock M9 mesh for native D3D9 shader review.

Requires the pinned importer and asset view prepared by render-previews.ps1
-PrepareOnly. Does not modify source meshes or the live Blender scene.
"""

import bpy,json,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from render_models import StudioImporter,Loader,GAME_VERSION
bpy.ops.wm.read_factory_settings(use_empty=True)
assets=root/'build/model-render/assets'
importer=StudioImporter(str(assets));loader=Loader(importer=importer)
loader.import_xmodel(asset_path=str(assets),file_path=str(assets/'xmodel/weapon_beretta'),selected_version=GAME_VERSION.CoD4,angles=(0.,0.,0.),origin=(0.,0.,0.),scale=(1.,1.,1.))
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
   triangles.append([*point,*normal,tex.x,1.0-tex.y])
(root/'build/shader-lab/m9-mesh.json').write_text(json.dumps(triangles))
print('Exported real M9 mesh:',len(triangles)//3,'triangles')
