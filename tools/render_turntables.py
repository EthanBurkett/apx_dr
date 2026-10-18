"""Offline 360-degree frames of the real meshes; consumed by the atlas packer."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_models import *

jobs=json.loads((WORK/'jobs.json').read_text())
selected=[arg for arg in sys.argv[sys.argv.index('--')+1:] if not arg.startswith('--')] if '--' in sys.argv else []
if selected: jobs=[job for job in jobs if job['key'] in selected]
for job in jobs:
    output=WORK/'frames'/('apx_turn_'+job['category']+'_'+str(job['id'])); output.mkdir(parents=True,exist_ok=True)
    if '--force' not in sys.argv and all((output/(str(i)+'.png')).exists() for i in range(32)): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    importer=StudioImporter(str(WORK/'assets')); loader=Loader(importer=importer)
    loader.import_xmodel(asset_path=str(WORK/'assets'),file_path=str(WORK/'assets/xmodel'/job['model']),selected_version=GAME_VERSION.CoD4,angles=(0.,0.,0.),origin=(0.,0.,0.),scale=(1.,1.,1.))
    if job['category']=='character': lower_arms()
    scene=bpy.context.scene
    meshes=[obj for obj in scene.objects if obj.type=='MESH']; frame(meshes,job['category'])
    orbit=bpy.data.objects.new('turntable',None); scene.collection.objects.link(orbit)
    root=bpy.data.objects['studio_root']; world=root.matrix_world.copy(); root.parent=orbit; root.matrix_world=world
    tall=job['category']=='character'
    scene.render.resolution_x=256 if tall else 512; scene.render.resolution_y=512 if tall else 256
    bpy.context.view_layer.update()
    inverse=scene.camera.matrix_world.inverted().to_3x3()
    corners=posed_corners(meshes)
    width=height=0
    for angle in range(32):
        rotate=Matrix.Rotation(math.tau*angle/32,3,'Z')
        projected=[inverse@(rotate@point) for point in corners]
        width=max(width,2*max(abs(p.x) for p in projected))
        height=max(height,2*max(abs(p.y) for p in projected))
    scene.camera.data.ortho_scale=(max(height,width*2) if tall else max(width,height*2))*1.16
    configure_cycles(scene,8)
    scene.render.use_persistent_data=True
    scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Studio world'); scene.world.color=(.12,.12,.12)
    scene.view_settings.view_transform='AgX'
    for i in range(32):
        dest=output/(str(i)+'.png')
        if dest.exists() and '--force' not in sys.argv: continue
        orbit.rotation_euler.z=math.tau*i/32
        scene.render.filepath=str(dest); bpy.ops.render.render(write_still=True)
    print('APX_TURNTABLE_DONE',job['key'],flush=True)
