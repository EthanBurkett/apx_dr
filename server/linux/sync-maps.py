#!/usr/bin/env python3
"""Sync SHA-pinned approved maps and repair missing public CDN objects.

Run as root inside the game VM. Only paths in map-files.json are touched.
Credentials stay in /etc/apx-dr/bunny.env, never arguments or output.
"""
from concurrent.futures import ThreadPoolExecutor,as_completed
import hashlib
import grp
import json
import os
from pathlib import Path,PurePosixPath
import time
from urllib.parse import quote,urlsplit
from urllib.request import Request,urlopen

BASE=Path('/srv/apx-dr')
ROOT=BASE/'game/usermaps'
CDN='http://cdn.apx.ethanburkett.dev/usermaps/'
STORAGE='https://storage.bunnycdn.com/apxcod4assets/usermaps/'


def checksum(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()


def key():
    values={}
    for line in Path('/etc/apx-dr/bunny.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            k,v=line.split('=',1);values[k.strip().lower()]=v.strip().strip('"\'')
    return values['access_key']


def public_matches(row):
    request=Request(CDN+quote(row['path'],safe='/')+'?apx_verify='+str(time.time_ns()))
    try:
        with urlopen(request,timeout=45) as response:
            length=response.headers.get('Content-Length')
            if length is not None and int(length)!=row['bytes']:return False
            return hashlib.file_digest(response,'sha256').hexdigest()==row['sha256']
    except Exception:return False


def sync(row,storage_key):
    relative=PurePosixPath(row['path'])
    if relative.is_absolute() or '..' in relative.parts or len(relative.parts)!=2 or relative.suffix.lower() not in ('.ff','.iwd','.arena'):
        raise ValueError('Forbidden map path')
    path=ROOT/relative;path.parent.mkdir(parents=True,exist_ok=True)
    os.chown(path.parent,0,grp.getgrnam('apxdr').gr_gid);path.parent.chmod(0o750)
    valid=path.is_file() and path.stat().st_size==row['bytes'] and checksum(path)==row['sha256']
    if valid and public_matches(row):return row['path'],'verified'
    from_cdn=False
    if not valid:
        urls=[CDN+quote(row['path'],safe='/')+'?apx_install='+str(time.time_ns())]
        if row.get('url'):urls.append(row['url'])
        failure=None
        for url in urls:
            parsed=urlsplit(url)
            if parsed.scheme not in ('http','https') or parsed.username or parsed.password:continue
            try:
                pending=path.with_name(path.name+'.download');digest=hashlib.sha256();size=0
                with urlopen(url,timeout=60) as source,pending.open('wb') as output:
                    while data:=source.read(1024*1024):
                        output.write(data);digest.update(data);size+=len(data)
                        if size>row['bytes']:raise ValueError('Map response exceeds its pinned size')
                if size!=row['bytes'] or digest.hexdigest()!=row['sha256']:raise ValueError('Map checksum mismatch')
                os.chown(pending,0,grp.getgrnam('apxdr').gr_gid)
                pending.chmod(0o640);os.replace(pending,path)
                from_cdn=url.startswith(CDN);valid=True;break
            except Exception as error:failure=type(error).__name__
        if not valid:raise RuntimeError('Needs local source: '+str(failure))
    if not from_cdn:
        with path.open('rb') as stream:
            request=Request(STORAGE+quote(relative.as_posix(),safe='/'),data=stream,method='PUT',headers={
                'AccessKey':storage_key,'Checksum':row['sha256'].upper(),'Content-Length':str(row['bytes']),
                'Content-Type':'application/octet-stream'})
            with urlopen(request,timeout=600) as reply:
                if reply.status not in (200,201):raise RuntimeError('Storage upload failed')
        for attempt in range(3):
            if public_matches(row):break
            time.sleep(2)
        else:raise RuntimeError('Uploaded map did not verify from the CDN')
    return row['path'],'downloaded' if from_cdn else 'uploaded'


def main():
    rows=json.loads((BASE/'map-files.json').read_text());storage_key=key()
    ROOT.mkdir(parents=True,exist_ok=True)
    os.chown(ROOT,0,grp.getgrnam('apxdr').gr_gid);ROOT.chmod(0o750)
    results=[];errors=[];started=time.monotonic()
    with ThreadPoolExecutor(max_workers=8) as pool:
        futures={pool.submit(sync,row,storage_key):row['path'] for row in rows}
        for index,future in enumerate(as_completed(futures),1):
            name=futures[future]
            try:
                name,result=future.result();results.append({'path':name,'status':result})
            except Exception as error:
                errors.append({'path':name,'error':str(error) if isinstance(error,(ValueError,RuntimeError)) else type(error).__name__})
                print('Map needs attention: '+name+' ('+errors[-1]['error']+')',flush=True)
            if index%25==0 or index==len(rows):
                print(str(index)+'/'+str(len(rows))+' maps files checked; '+str(len(errors))+' unresolved.',flush=True)
                (BASE/'map-sync.json').write_text(json.dumps({'verified':results,'errors':errors},indent=2)+'\n')
    print('Map sync finished in '+str(round(time.monotonic()-started))+' seconds.',flush=True)
    raise SystemExit(bool(errors))


if __name__=='__main__':main()
