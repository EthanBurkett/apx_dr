"""Run with Blender --background --factory-startup --python tools/render_models.py.

Imports actual compiled CoD4 assets using Soma Radoczi's GPL-3.0 importer, then
renders transparent studio previews in an isolated scene. Never uses a live
Blender project. The upstream importer is a development dependency under build.
"""
import json
import math
import os
from pathlib import Path
import sys
import bpy
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/model-render'
sys.path.insert(0,str(WORK/'vendor'))
from cod_asset_importer.importer import Importer
from cod_asset_importer.cod_asset_importer import Loader,GAME_VERSION,TEXTURE_TYPE

def configure_cycles(scene,samples):
    if os.environ.get('APX_MODEL_RENDER_ENGINE')=='EEVEE':
        scene.render.engine='BLENDER_EEVEE'
        scene.eevee.taa_render_samples=samples
        return
    scene.render.engine='CYCLES'; scene.cycles.samples=samples
    scene.cycles.use_denoising=True
    preferences=bpy.context.preferences.addons['cycles'].preferences
    try:
        preferences.compute_device_type='OPTIX'; preferences.get_devices()
        devices=[device for device in preferences.devices if device.type=='OPTIX']
        if devices:
            for device in preferences.devices: device.use=device.type=='OPTIX'
            scene.cycles.device='GPU'
    except (TypeError,RuntimeError): pass # CPU remains a supported authoring path.


class StudioImporter(Importer):
    def material(self,loaded_material,**kwargs):
        name=loaded_material.name()
        if bpy.data.materials.get(name): return
        mat=bpy.data.materials.new(name); mat.use_nodes=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Roughness'].default_value=.63
        shader.inputs['Specular IOR Level'].default_value=.3
        for texture in loaded_material.textures():
            if texture.texture_type()!=TEXTURE_TYPE.Color: continue
            image=self._import_texture(texture)
            node=mat.node_tree.nodes.new('ShaderNodeTexImage'); node.image=image
            mat.node_tree.links.new(node.outputs['Color'],shader.inputs['Base Color'])
            # Diffuse alpha sometimes stores gloss; body/weapon meshes stay opaque.


def light(name,location,power,size,color):
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); bpy.context.scene.collection.objects.link(obj); obj.location=location
    obj.rotation_euler=(Vector((0,0,.8))-obj.location).to_track_quat('-Z','Y').to_euler()


def posed_corners(objects):
    corners=[]
    depsgraph=bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        evaluated=obj.evaluated_get(depsgraph)
        mesh=evaluated.to_mesh()
        try:
            points=[evaluated.matrix_world@v.co for v in mesh.vertices]
            lo=Vector(tuple(min(p[a] for p in points) for a in range(3)))
            hi=Vector(tuple(max(p[a] for p in points) for a in range(3)))
            corners.extend(Vector((x,y,z)) for x in (lo.x,hi.x) for y in (lo.y,hi.y) for z in (lo.z,hi.z))
        finally: evaluated.to_mesh_clear()
    return corners


def frame(objects,category,back=False):
    scene=bpy.context.scene
    bpy.context.view_layer.update()
    corners=posed_corners(objects)
    lo=Vector(tuple(min(c[a] for c in corners) for a in range(3)))
    hi=Vector(tuple(max(c[a] for c in corners) for a in range(3)))
    center=(lo+hi)/2; extent=hi-lo
    scale=1/max(extent)
    root=bpy.data.objects.new('studio_root',None); scene.collection.objects.link(root)
    for obj in list(scene.objects):
        if obj.type in {'MESH','ARMATURE','EMPTY'} and obj!=root and obj.parent is None: obj.parent=root
    root.location=-center*scale; root.scale=(scale,)*3
    bpy.context.view_layer.update()
    target=Vector((0,0,0))
    camera_data=bpy.data.cameras.new('camera'); camera=bpy.data.objects.new('camera',camera_data); scene.collection.objects.link(camera)
    scene.camera=camera; camera_data.type='ORTHO'; camera_data.lens=60
    if category=='character':
        camera.location=((-3 if back else 3),(1.6 if back else -1.6),.15)
        camera_data.ortho_scale=1.25
        scene.render.resolution_x=512; scene.render.resolution_y=1024
    else:
        camera.location=(.65,-3,1.1)
        camera_data.ortho_scale=1.2
        scene.render.resolution_x=1024; scene.render.resolution_y=512
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    inverse=camera.matrix_world.inverted()
    points=[inverse@point for point in posed_corners(objects)]
    width=max(p.x for p in points)-min(p.x for p in points)
    height=max(p.y for p in points)-min(p.y for p in points)
    camera_data.ortho_scale=max(height,width*2)*1.16 if category=='character' else max(width,height*2)*1.16
    light('soft key',(2,-2.2,2.8),110,3,(.96,.98,1))
    light('rear fill',(-2,2.2,2.8),100,3,(.96,.98,1))
    light('side fill',(2.5,1,.3),65,3,(.95,.97,1))
    light('opposite fill',(-2.5,-1,.3),55,3,(.95,.97,1))


def lower_arms():
    profiles=json.loads((ROOT/'ui/model_render_profiles.json').read_text())
    if any(name in bpy.data.objects for name in profiles['bind_pose_models']): return
    for rig in [obj for obj in bpy.context.scene.objects if obj.type=='ARMATURE']:
        for bone in rig.pose.bones:
            if bone.name not in ('j_shoulder_le','j_shoulder_ri'): continue
            elbow=rig.pose.bones.get('j_elbow_le' if bone.name.endswith('_le') else 'j_elbow_ri')
            if elbow is None: continue
            head=bone.matrix.translation.copy()
            direction=(elbow.matrix.translation-head).normalized()
            target=Vector((0,.18 if head.y>0 else -.18,-1)).normalized()
            rotation=direction.rotation_difference(target).to_matrix().to_4x4()
            bone.matrix=Matrix.Translation(head)@rotation@Matrix.Translation(-head)@bone.matrix
            bpy.context.view_layer.update()
        bpy.context.view_layer.update()


def main():
    jobs=json.loads((WORK/'jobs.json').read_text())
    if '--' in sys.argv:
        wanted=sys.argv[sys.argv.index('--')+1:]
        if wanted: jobs=[job for job in jobs if job['key'] in wanted]
    output=ROOT/'art/ui/models'; output.mkdir(parents=True,exist_ok=True)
    report=[]
    for job in jobs:
        views=['front','back'] if job['category']=='character' else ['front']
        for view in views:
            name='apx_preview_'+job['category']+'_'+str(job['id'])+('_back' if view=='back' else '')
            dest=output/(name+'.png')
            if dest.exists() and '--force' not in sys.argv:
                report.append({**job,'view':view,'name':name}); continue
            bpy.ops.wm.read_factory_settings(use_empty=True)
            scene=bpy.context.scene
            importer=StudioImporter(str(WORK/'assets')); loader=Loader(importer=importer)
            loader.import_xmodel(asset_path=str(WORK/'assets'),file_path=str(WORK/'assets/xmodel'/job['model']),selected_version=GAME_VERSION.CoD4,angles=(0.,0.,0.),origin=(0.,0.,0.),scale=(1.,1.,1.))
            meshes=[obj for obj in scene.objects if obj.type=='MESH']
            if not meshes: raise RuntimeError('No mesh imported: '+job['model'])
            if job['category']=='character': lower_arms()
            frame(meshes,job['category'],view=='back')
            configure_cycles(scene,16)
            scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
            scene.render.resolution_percentage=100; scene.render.filepath=str(dest)
            if scene.world is None: scene.world=bpy.data.worlds.new('Studio world')
            scene.world.color=(.12,.12,.12)
            scene.view_settings.view_transform='AgX'
            bpy.ops.render.render(write_still=True)
            print('APX_RENDERED',name,flush=True)
            report.append({**job,'view':view,'name':name})
        (WORK/'rendered.json').write_text(json.dumps(report,indent=2))


if __name__=='__main__': main()
