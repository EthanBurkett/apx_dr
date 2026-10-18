"""Bisect raw-asset linker failures in a disposable SDK view, without popups.

All SDK/source files are read-only hardlinks. Only diagnostic CSV/FF/log files
are written. The real SDK and release dist are never used as output locations.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]; GAME=ROOT.parent.parent
WORK=ROOT/'build/content-linker'; SDK=WORK/'sdk'; HOST=WORK/'LinkerHost.exe'

def prepare(refresh=False):
    WORK.mkdir(parents=True,exist_ok=True)
    csc=Path(os.environ['SystemRoot'])/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
    if not HOST.exists() or HOST.stat().st_mtime<(ROOT/'tools/ContentLinkerHost.cs').stat().st_mtime:
        subprocess.run([str(csc),'/nologo','/out:'+str(HOST),str(ROOT/'tools/ContentLinkerHost.cs')],check=True)
    if (SDK/'.prepared').exists() and not refresh: return
    for folder in ('bin','main'):
        (SDK/folder).mkdir(parents=True,exist_ok=True)
        for path in (GAME/folder).glob('*'):
            if path.is_file() and (path.suffix.lower() in ('.dll','.exe','.iwd')):
                dest=SDK/folder/path.name
                if not dest.exists(): os.link(path,dest)
    for base in (GAME/'raw',ROOT/'src',ROOT/'assets'):
        for path in base.rglob('*'):
            if not path.is_file(): continue
            dest=SDK/'raw'/path.relative_to(base); dest.parent.mkdir(parents=True,exist_ok=True)
            if dest.exists():
                if os.path.samefile(dest,path): continue
                dest.unlink()
            os.link(path,dest)
    for folder in ('zone_source','zone/english','zone_source/english/assetlist'): (SDK/folder).mkdir(parents=True,exist_ok=True)
    (SDK/'.prepared').write_text('Read-only diagnostic view; use --refresh after adding dependencies.')

counter=0
def test(lines,label):
    global counter; counter+=1
    zone='content_'+str(os.getpid())+'_'+str(counter); log=WORK/(zone+'.log')
    (SDK/'zone_source'/(zone+'.csv')).write_text('\n'.join(lines)+'\n')
    result=subprocess.run([str(HOST),str(SDK),zone,str(log),'180000'])
    text=log.read_text(errors='replace') if log.exists() else ''
    good=result.returncode==0 and (SDK/'zone/english'/(zone+'.ff')).exists() and 'ERROR:' not in text
    record={'label':label,'assets':len(lines),'exit':result.returncode,'good':good,'manifest':lines,'log':str(log)}
    with (WORK/'results.jsonl').open('a') as handle: handle.write(json.dumps(record)+'\n')
    print('PASS' if good else 'FAIL',label,len(lines),'assets','exit',result.returncode,flush=True)
    if not good: print(text[-900:],flush=True)
    return good

def bisect(lines,label):
    if test(lines,label): return []
    if len(lines)==1: return lines
    middle=len(lines)//2
    return bisect(lines[:middle],label+'a')+bisect(lines[middle:],label+'b')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--kind',choices=['weapon','xmodel','sound','all'],default='all'); parser.add_argument('--batch',type=int,default=24); parser.add_argument('--start',type=int,default=0); parser.add_argument('--refresh',action='store_true'); parser.add_argument('--combined',action='store_true')
    args=parser.parse_args(); prepare(args.refresh)
    lines=[l for l in (ROOT/'manifests/16-community-content.csv').read_text().splitlines() if l and not l.startswith('//') and (args.kind=='all' or l.startswith(args.kind+','))]
    bad=[]
    if args.combined:
        test(lines,'combined-'+args.kind)
        return
    for start in range(args.start,len(lines),args.batch): bad+=bisect(lines[start:start+args.batch],str(start))
    (WORK/('bad-'+args.kind+'.json')).write_text(json.dumps(bad,indent=2))
    print('Isolated bad assets:',bad,flush=True)

if __name__=='__main__': main()
