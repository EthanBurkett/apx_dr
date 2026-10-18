"""Measure client-zone asset pools for installed maps in isolated native servers.

Requires the diagnostic executable from build-client-audit.ps1. No live server,
private config or human player profile is read or modified. JSON contains each
map's counters and the SHA-256 of the measured mod fastfile.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid
from windows_process import IsolatedProcess

ROOT=Path(__file__).resolve().parents[1]
SESSIONS={}


def stop_session(port):
    session=SESSIONS.pop(port,None)
    if not session:return
    process=session['process']
    if process.poll() is None:process.terminate()
    try:
        try:process.wait(timeout=5)
        except subprocess.TimeoutExpired:process.kill();process.wait()
    finally:process.close()


def command(port,key,text):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as control:
        control.settimeout(.3)
        control.sendto(b'\xff\xff\xff\xff'+('rcon '+key+' '+text).encode(),('127.0.0.1',port))
        chunks=[];deadline=time.monotonic()+3
        while time.monotonic()<deadline:
            try:chunks.append(control.recv(65536)[4:].decode(errors='replace'))
            except (socket.timeout,ConnectionResetError):break
        return ''.join(chunks)


def status(port):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as query:
        query.settimeout(.2)
        query.sendto(b'\xff\xff\xff\xffgetstatus apx-assets',('127.0.0.1',port))
        try:return query.recv(65536).decode(errors='replace')
        except (socket.timeout,ConnectionResetError):return ''


def measure(game,mod,exe,name,port,output,timeout=35):
    fs=mod.relative_to(game).as_posix()
    session=SESSIONS.get(port)
    if session and session['process'].poll() is not None:stop_session(port);session=None
    reused=bool(session);requested=True
    if session:
        process=session['process'];log=session['log']
        response=command(port,session['key'],'map '+name)
        with log.with_name('asset-rcon.log').open('a') as trace:
            trace.write('\nMAP REQUEST '+name+'\n'+response)
        requested=False
    else:
        home=output/(name+'-'+uuid.uuid4().hex[:6]);home.mkdir(parents=True)
        cfg=home/fs/'apx_asset_audit.cfg';cfg.parent.mkdir(parents=True)
        cfg.write_text('set g_bots 0\nset g_gametype deathrun\n')
        key=uuid.uuid4().hex
        args=[str(exe),'+set','dedicated','1','+set','fs_basepath',str(game),'+set','fs_homepath',str(home),'+set','fs_game',fs,
              '+set','developer','1','+set','developer_script','1','+set','logfile','2','+set','net_ip','127.0.0.1',
              '+set','net_port',str(port),'+set','rcon_password',key,'+exec','deathrun.cfg','+exec','dr_songs.cfg',
              '+exec','apx_asset_audit.cfg','+map',name,'+XAssetUsage']
        process=IsolatedProcess(args,cwd=game)
        log=home/fs/'qconsole.log'
        session={'process':process,'log':log,'key':key,'count':0}
        SESSIONS[port]=session
    keep=False
    try:
        deadline=time.monotonic()+timeout
        last_query=0
        while time.monotonic()<deadline:
            try:text=log.read_text(errors='replace') if log.exists() else ''
            except OSError:text=''
            if reused:
                # RCON redirects command output to UDP, bypassing qconsole.log.
                # A status response proves the new map's server loop is ready.
                text=''
                if time.monotonic()-last_query>=1:
                    last_query=time.monotonic()
                    if '\\mapname\\'+name+'\\' in status(port):
                        text=command(port,session['key'],'XAssetUsage')
                        with log.with_name('asset-rcon.log').open('a') as trace:
                            trace.write('\nMAP '+name+'\n'+text)
            usage={m[0]:int(m[1]) for m in re.findall(r'^([a-z_]+)\s+(\d+)\s+(\d+)\s*$',text,re.M)}
            if usage.get('material',0)>0 and 'stringtable' in usage and (reused or 'Calculate referenced files checksums' in text):
                session['count']+=1;keep=session['count']<16
                proof=log.with_name('asset-rcon.log') if reused else log
                return {'map':name,'usage':usage,'log':str(proof.relative_to(ROOT))}
            error=re.search(r"(?im)^.*(?:Exceeded limit|Server fatal|script (?:compile|runtime) error|terminal script error|Can't find map|Could not find zone).*$",text)
            if error or process.poll() is not None:
                return {'map':name,'error':error[0].strip() if error else 'Server exited ('+str(process.returncode)+')','log':str(log.relative_to(ROOT))}
            time.sleep(.1)
        return {'map':name,'error':'Timed out before asset counters','log':str(log.relative_to(ROOT))}
    finally:
        if not keep:stop_session(port)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mod',type=Path,default=ROOT/'dist/apx-presentation')
    parser.add_argument('--executable',type=Path,default=ROOT/'build/client-audit/apx_poolaudit.exe')
    parser.add_argument('--maps',nargs='*')
    parser.add_argument('--workers',type=int,default=3,choices=range(1,5))
    parser.add_argument('--fresh',action='store_true',help='Start a fresh owned server for every map; useful when rechecking failed loads')
    parser.add_argument('--output',type=Path,default=ROOT/'build/map-assets')
    args=parser.parse_args();game=ROOT.parent.parent
    mod=args.mod.resolve();exe=args.executable.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    if not exe.is_file():parser.error('Build the client-zone audit server first')
    names=args.maps or [r['map'] for r in json.loads((ROOT/'ui/map_inventory.json').read_text())['maps'] if r['deathrun']]
    if any(not re.fullmatch(r'mp_[a-zA-Z0-9_]+',n) for n in names):parser.error('Invalid map name')
    # Each worker owns a port; never interrogate an unrelated running server.
    ports=[]
    for i in range(args.workers):
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1',0));ports.append(probe.getsockname()[1])
    import queue
    pool=queue.Queue()
    for port in ports:pool.put(port)
    def run(name):
        port=pool.get()
        try:return measure(game,mod,exe,name,port,output)
        except Exception as error:
            stop_session(port)
            return {'map':name,'error':type(error).__name__+': '+str(error)}
        finally:
            if args.fresh:stop_session(port)
            pool.put(port)
    records=[];digest=hashlib.sha256((mod/'mod.ff').read_bytes()).hexdigest()
    saved=output/'report.json'
    if saved.exists():
        prior=json.loads(saved.read_text())
        if prior.get('mod_sha256')==digest:
            records=[r for r in prior['maps'] if r['map'] in names and r.get('usage',{}).get('material',0)>0 and 'stringtable' in r['usage']]
    complete={r['map'] for r in records};pending=[n for n in names if n not in complete]
    report={'mod_sha256':digest,
            'client_zones':['ui_mp','localized_common_mp'],'maps':records}
    try:
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            futures=[executor.submit(run,name) for name in pending]
            for future in as_completed(futures):
                record=future.result();records.append(record)
                records.sort(key=lambda r:r['map'])
                (output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
                print(len(records),'/',len(names),record['map'],record.get('usage',{}).get('material',record.get('error')),flush=True)
    finally:
        for port in list(SESSIONS):stop_session(port)
    return int(any('error' in r for r in records))


if __name__=='__main__':raise SystemExit(main())
