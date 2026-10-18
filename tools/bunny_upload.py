"""Upload explicit public files to Bunny Storage without logging credentials.

Uses a local ignored env file containing access_key=<storage-zone password>.
Never pass credentials as command-line arguments or upload deployment folders.
"""
import argparse
import hashlib
import json
from pathlib import Path,PurePosixPath
from urllib.request import Request,urlopen
from urllib.error import HTTPError
from urllib.parse import quote,urlsplit


def credentials(path):
    values={}
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#'):continue
        if '=' not in line:continue
        name,value=line.split('=',1)
        values[name.strip().removeprefix('export ').lower()]=value.strip().strip('\"\'')
    key=values.get('access_key') or values.get('bunny_storage_password')
    if not key:raise ValueError('Env file needs access_key or BUNNY_STORAGE_PASSWORD')
    return key


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file',type=Path,default=Path('bunny.env'))
    parser.add_argument('--zone',required=True)
    parser.add_argument('--endpoint',default='https://storage.bunnycdn.com')
    parser.add_argument('--file',type=Path)
    parser.add_argument('--remote')
    parser.add_argument('--list',action='store_true')
    args=parser.parse_args()
    endpoint=urlsplit(args.endpoint)
    if endpoint.scheme!='https' or not endpoint.hostname or endpoint.hostname not in ('storage.bunnycdn.com',) and not endpoint.hostname.endswith('.storage.bunnycdn.com'):
        parser.error('Use an HTTPS Bunny Storage endpoint')
    if not args.zone or '/' in args.zone or args.zone in ('.','..'):parser.error('Invalid zone name')
    key=credentials(args.env_file)
    base=args.endpoint.rstrip('/')+'/'+quote(args.zone,safe='')+'/'
    if args.list:
        with urlopen(Request(base,headers={'AccessKey':key}),timeout=30) as response:data=json.load(response)
        print(json.dumps([{'name':r['ObjectName'],'directory':r['IsDirectory'],'bytes':r['Length']} for r in data],indent=2))
        return
    if not args.file or not args.remote:parser.error('Upload needs --file and --remote')
    remote=PurePosixPath(args.remote)
    if remote.is_absolute() or '..' in remote.parts or '\\' in args.remote:parser.error('Remote path must stay within the zone')
    if args.file.name.lower().endswith('.env') or 'private' in args.file.name.lower():parser.error('Refusing a credential/private file')
    size=args.file.stat().st_size
    with args.file.open('rb') as source:
        request=Request(base+quote(remote.as_posix(),safe='/'),data=source,method='PUT',
                        headers={'AccessKey':key,'Content-Type':'application/octet-stream','Content-Length':str(size)})
        with urlopen(request,timeout=600) as response:
            if response.status not in (200,201):raise RuntimeError('Storage upload did not succeed')
    with args.file.open('rb') as stream: digest=hashlib.file_digest(stream,'sha256').hexdigest()
    print(json.dumps({'uploaded':remote.as_posix(),'bytes':size,'sha256':digest}))


if __name__=='__main__':
    try:main()
    except HTTPError as error:raise SystemExit('Bunny Storage HTTP '+str(error.code)+'; credentials and response body omitted')
