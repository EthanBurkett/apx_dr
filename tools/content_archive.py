"""Inventory/download the revived CFGFactory archive; never execute pack scripts.

Original archives and attribution pages live under build/content-cache. Importing
into release assets is a separate, explicit operation after dependency checks.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import html
import json
from pathlib import Path
import re
import urllib.request
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT/'build/content-cache'
BASE = 'https://cfgfactory.com'

def get(url):
    request=urllib.request.Request(url,headers={'User-Agent':'ApX-Deathrun-content-import/1.0'})
    with urllib.request.urlopen(request,timeout=90) as response:
        return response.read()

def plain(source):
    return html.unescape(re.sub('<[^>]+>',' ',source)).strip()

def inventory():
    CACHE.mkdir(parents=True,exist_ok=True)
    pages=[BASE+'/skins/category/32/'+('' if page==1 else '?page='+str(page)) for page in range(1,26)]
    # Static archive pagination is discovered from the first page, not assumed.
    first=get(pages[0]).decode()
    pagination=re.findall(r'href="([^"]+)"[^>]*>\s*(?:2|25)\s*</a>',first)
    if pagination:
        second=urljoin(BASE,pagination[0])
        if '?page=' not in second:
            if 'page-2.html' not in second: raise ValueError('Unknown archive pagination: '+second)
            pages=[pages[0]]+[second.replace('page-2.html','page-'+str(page)+'.html') for page in range(2,26)]
    links=set()
    with ThreadPoolExecutor(max_workers=4) as pool:
        for source in pool.map(get,pages):
            links.update(urljoin(BASE,link) for link in re.findall(r'href="(/skins/show/[^"]+)"',source.decode()))
    def detail(url):
        source=get(url).decode()
        id=url.rsplit('/',1)[-1].replace('.html','')
        (CACHE/(id+'.html')).write_text(source,encoding='utf8')
        title=plain(re.search(r'<h1[^>]*>(.*?)</h1>',source,re.S)[1])
        desc=re.search(r'<div class="card-body desc">(.*?)</div>',source,re.S)
        author=re.search(r'>Author</span><span>(.*?)</span>',source,re.S)
        download=re.search(r'href="(/dl/[^"]+)"',source)
        return {'id':id,'name':title,'page':url,'author':plain(author[1]) if author else '',
                'description':plain(desc[1]) if desc else '',
                'download':urljoin(BASE,download[1]) if download else None}
    with ThreadPoolExecutor(max_workers=4) as pool:
        records=list(pool.map(detail,sorted(links,reverse=True)))
    (CACHE/'index.json').write_text(json.dumps(records,indent=2),encoding='utf8')
    print('Indexed',len(records),'packs.',flush=True)
    return records

def download(record):
    if not record['download']: return record
    suffix=Path(record['download']).suffix.lower()
    dest=CACHE/(record['id']+suffix)
    if not dest.exists():
        data=get(record['download'])
        # Archive payloads only. Never execute downloaded programs or installers.
        if not (data.startswith(b'PK') or data.startswith(b'Rar!') or data.startswith(b'7z')):
            record['error']='Not an archive payload'; return record
        dest.write_bytes(data)
    record.update(archive=dest.name,sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),bytes=dest.stat().st_size)
    print('Downloaded',record['name'],round(record['bytes']/1048576,1),'MB',flush=True)
    return record

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--index',action='store_true'); parser.add_argument('--download',action='store_true'); parser.add_argument('--limit',type=int,default=200)
    args=parser.parse_args()
    records=inventory() if args.index else json.loads((CACHE/'index.json').read_text())
    if args.download:
        # Prioritize player models, then broad weapon variety; camo-only packs wait.
        characters=[r for r in records if re.search(r'player|character|pmodel|playermodel',r['name'],re.I)]
        weapons=[r for r in records if r not in characters and not re.search(r'camo|shader|reskin|skin pack|glowing|invisible',r['name'],re.I)]
        selected=characters+weapons[:max(0,args.limit-len(characters))]
        def safe(record):
            try: return download(record)
            except Exception as error: return dict(record,error=str(error))
        with ThreadPoolExecutor(max_workers=4) as pool: imported=list(pool.map(safe,selected))
        (CACHE/'downloads.json').write_text(json.dumps(imported,indent=2),encoding='utf8')
        print('Downloaded',sum('archive' in r for r in imported),'archives; failures',sum('error' in r for r in imported),flush=True)

if __name__=='__main__': main()
