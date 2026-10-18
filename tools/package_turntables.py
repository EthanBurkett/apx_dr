"""Assemble actual-model angle frames into shader-driven 360-degree atlases."""
import json
import sys
from pathlib import Path
from PIL import Image
from generate_progression import write_iwi,write_material
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'build/model-render'

def main():
    budget=json.loads((ROOT/'ui/texture_budget.json').read_text())
    jobs=json.loads((WORK/'jobs.json').read_text())
    output=ROOT/'art/ui/models/turntables'; output.mkdir(parents=True,exist_ok=True)
    manifest=['// 32 rendered mesh views per atlas; native gameTime drives playback.']
    for job in jobs:
        name='apx_turn_'+job['category']+'_'+str(job['id'])
        manifest.append('material,'+name)
        if len(sys.argv)>1 and job['key'] not in sys.argv[1:]:
            if not (ROOT/'assets/images'/(name+'.iwi')).exists(): raise FileNotFoundError(name)
            continue
        tall=job['category']=='character'; w,h=(256,512) if tall else (512,256); cols=8 if tall else 4
        atlas=Image.new('RGBA',(2048,2048))
        for index in range(32):
            path=WORK/'frames'/name/(str(index)+'.png')
            with Image.open(path) as frame:
                frame.load()
                if frame.size!=(w,h): raise ValueError('Wrong frame dimensions: '+str(path))
                atlas.paste(frame,(index%cols*w,index//cols*h))
        atlas.save(output/(name+'.png'))
        size=budget['turntable_size']
        packed=atlas.resize((size,size),Image.Resampling.LANCZOS)
        write_iwi(packed,ROOT/'assets/images'/(name+'.iwi'))
        write_material(name,size,size,techset='apx_turntable_'+('tall' if tall else 'wide'))
    (ROOT/'manifests/15-turntables.csv').write_text('\n'.join(manifest)+'\n')
    if (ROOT/'ui/content_profile.json').exists():
        from apply_content_profile import filter_previews
        filter_previews()
    print(f'Packaged {len(jobs)} turntables, 32 real views each.')

if __name__=='__main__': main()
