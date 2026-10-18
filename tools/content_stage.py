"""Safely inspect downloaded archives as data, retaining attribution unchanged."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'build/content-cache'
STAGE=ROOT/'build/content-staging'
TAR=Path(os.environ.get('SystemRoot','C:/Windows'))/'System32/tar.exe'
KINDS={'xmodel','xmodelparts','xmodelsurfs','xanim','images','materials','material_properties','techsets','techniques','shader_bin','sound','soundaliases','fx','weapons'}

def safe_name(name):
    path=PurePosixPath(name.replace('\\','/'))
    return not path.is_absolute() and '..' not in path.parts and not any(':' in p for p in path.parts)

def extract(archive,dest):
    dest.mkdir(parents=True,exist_ok=True)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z:
            if sum(i.file_size for i in z.infolist())>2*1024**3: raise ValueError('Pack expands beyond 2 GiB')
            for item in z.infolist():
                if not safe_name(item.filename) or (item.external_attr>>16)&0o170000==0o120000: raise ValueError('Unsafe archive member')
            z.extractall(dest)
    else:
        listing=subprocess.check_output([str(TAR),'-tvf',str(archive)],encoding='utf8',errors='replace')
        if any(line.startswith(('l','h')) for line in listing.splitlines()): raise ValueError('Archive contains links')
        names=subprocess.check_output([str(TAR),'-tf',str(archive)],encoding='utf8',errors='replace').splitlines()
        if not all(safe_name(n) for n in names): raise ValueError('Unsafe archive member')
        subprocess.run([str(TAR),'-xf',str(archive),'-C',str(dest),'--no-same-owner','--no-same-permissions'],check=True,capture_output=True)

def stage(record):
    id=record['id']
    archives=[p for p in CACHE.glob(id+'.*') if p.suffix.lower() in ('.zip','.rar','.7z')]
    if not archives: return None
    directory=STAGE/id
    try:
        if not (directory/'stage.json').exists():
            extract(archives[0],directory)
            for depth in range(3):
                nested=[p for p in directory.rglob('*') if p.is_file() and p.suffix.lower() in ('.zip','.rar','.7z','.iwd') and not (p.parent/(p.name+'.contents')).exists()]
                if not nested: break
                for archive in nested: extract(archive,archive.parent/(archive.name+'.contents'))
        files={}; conflicts=[]
        for path in directory.rglob('*'):
            if not path.is_file(): continue
            parts=path.relative_to(directory).parts
            for index,part in enumerate(parts):
                kind=part.lower()
                if kind not in KINDS or index==len(parts)-1: continue
                tail='/'.join(parts[index+1:])
                if any(p.lower().endswith('.contents') for p in parts[index+1:]): continue
                if kind=='weapons':
                    # Many releases call the MP folder "fixes", or offer several
                    # animation options in subfolders. Preserve these candidates
                    # for inspection; the importer namespaces only chosen files.
                    if not path.read_bytes().startswith(b'WEAPONFILE'): continue
                    tail='mp/'+path.name
                relative=kind+'/'+tail
                # Flat binary assets have no subdirectories; sounds/FX may.
                if kind not in ('weapons','sound','soundaliases','fx') and '/' in tail: continue
                if relative in files and files[relative].read_bytes()!=path.read_bytes(): conflicts.append(relative)
                else: files[relative]=path
                break
        result={**record,'archive':archives[0].name,'sha256':hashlib.sha256(archives[0].read_bytes()).hexdigest(),
                'files':{name:str(path.relative_to(directory)).replace('\\','/') for name,path in files.items()},'conflicts':conflicts}
        (directory/'stage.json').write_text(json.dumps(result,indent=2),encoding='utf8')
        print('Staged',record['name'],len(files),'assets',flush=True)
        return result
    except Exception as error:
        print('Rejected archive',record['name'],str(error)[:180],flush=True)
        return dict(record,error=str(error))

def main():
    records=json.loads((CACHE/'index.json').read_text())
    with ThreadPoolExecutor(max_workers=4) as pool:
        results=[result for result in pool.map(stage,records) if result]
    STAGE.mkdir(parents=True,exist_ok=True)
    (STAGE/'inventory.json').write_text(json.dumps(results,indent=2),encoding='utf8')
    print('Staged',len(results),'archives.',flush=True)

if __name__=='__main__': main()
