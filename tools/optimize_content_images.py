"""Trim oversized 2D IWI images to existing mips, preserving channel packing.

No image decoding, recompression or normal-map conversion. Originals are retained
by SHA-256 under art/source-images (Git LFS); repeated runs are idempotent.
"""
import hashlib
import json
import os
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]

def sha(data): return hashlib.sha256(data).hexdigest()

def trim(data,maximum=1024):
    if len(data)<28 or data[:4]!=b'IWi\x06': return data
    fmt,flags=data[4:6];w,h,depth=struct.unpack_from('<3H',data,6)
    if fmt not in (1,2,11,12,13) or depth!=1 or flags&6: return data
    sizes=struct.unpack_from('<4I',data,12)
    drop=0
    while max(w>>drop,h>>drop)>maximum: drop+=1
    if not drop: return data
    if drop>3 or sizes[0]!=len(data) or not 28<sizes[drop]<len(data):
        raise ValueError('Unexpected IWI mip offsets; refusing to alter this image')
    # Validate all mip lengths before reusing compressed blocks verbatim.
    lengths=[];width,height=w,h
    while True:
        length=max(1,(width+3)//4)*max(1,(height+3)//4)*(8 if fmt==11 else 16) if fmt in (11,12,13) else width*height*(4 if fmt==1 else 3)
        lengths.append(length)
        if width==height==1: break
        width,height=max(1,width//2),max(1,height//2)
    if 28+sum(lengths)!=len(data) or 28+sum(lengths[drop:])!=sizes[drop]:
        raise ValueError('Inconsistent IWI mip payload; refusing to alter this image')
    result=bytearray(data[:sizes[drop]])
    struct.pack_into('<2H',result,6,max(1,w>>drop),max(1,h>>drop))
    remaining=lengths[drop:]
    struct.pack_into('<4I',result,12,*(28+sum(remaining[p:]) for p in range(4)))
    return bytes(result)

def main():
    maximum=json.loads((ROOT/'ui/texture_budget.json').read_text())['world_max_dimension']
    registry=ROOT/'ui/texture_optimization.json'
    records=json.loads(registry.read_text()) if registry.exists() else {}
    originals=ROOT/'art/source-images';originals.mkdir(parents=True,exist_ok=True)
    changed=0;saved=0
    for path in sorted((ROOT/'assets/images').glob('*.iwi')):
        if path.name.startswith(('apx_','rank_','prestige_')): continue
        current=path.read_bytes();record=records.get(path.name)
        if record and sha(current)==record['outputSHA256']: continue
        try: output=trim(current,maximum)
        except ValueError as error:
            print('SKIP',path.name,error,flush=True);continue
        if output==current: continue
        original_hash=sha(current);backup=originals/(original_hash+'.iwi')
        if not backup.exists(): backup.write_bytes(current)
        records[path.name]={'originalSHA256':original_hash,'outputSHA256':sha(output),
                            'sourceDimensions':list(struct.unpack_from('<2H',current,6)),
                            'runtimeDimensions':list(struct.unpack_from('<2H',output,6)),
                            'savedBytes':len(current)-len(output)}
        temporary=path.with_suffix('.iwi.tmp');temporary.write_bytes(output);os.replace(temporary,path)
        changed+=1;saved+=len(current)-len(output)
    registry.write_text(json.dumps(records,indent=2)+'\n')
    print(f'Mip-trimmed {changed} textures; saved {saved/1024**2:.1f} MiB. Originals preserved.')

if __name__=='__main__': main()
