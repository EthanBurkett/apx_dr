"""Restrict a measured rotation to maps whose public CDN files are complete.

The file manifest contains path/bytes/SHA-256 records from the installed,
validated map collection. HEAD checks verify public availability and lengths;
they do not claim to verify remote file hashes. Does not delete or upload maps.
"""
import argparse,json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request,urlopen
from sync_map_rotation import rotation


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory',type=Path,required=True)
    parser.add_argument('--files',type=Path,required=True)
    parser.add_argument('--cdn',required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    args=parser.parse_args()
    inventory=json.loads(args.inventory.read_text())
    selected=[r['map'] for r in inventory['maps'] if r['rotation']]
    files=json.loads(args.files.read_text())
    def available(row):
        try:
            request=Request(args.cdn.rstrip('/')+'/usermaps/'+quote(row['path'],safe='/'),method='HEAD')
            with urlopen(request,timeout=12) as reply:
                return row['path'],reply.status==200 and int(reply.headers.get('Content-Length','-1'))==row['bytes']
        except Exception:return row['path'],False
    with ThreadPoolExecutor(max_workers=16) as executor:status=dict(executor.map(available,files))
    names=[];waiting=[]
    for name in selected:
        needed=[r['path'] for r in files if r['path'].split('/')[0]==name]
        missing=[p for p in needed if not status.get(p)]
        (waiting if not needed or missing else names).append(name)
    # rotation() refuses to replace a valid config with an empty collection.
    text=rotation(names)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    temporary=args.output.with_suffix('.pending');temporary.write_text(text,encoding='ascii');temporary.replace(args.output)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps({'cdn':args.cdn,'ready':names,'pending':waiting},indent=2)+'\n')
    print(len(names),'CDN-ready maps;',len(waiting),'still pending. Rotation written to',args.output)


if __name__=='__main__':main()
