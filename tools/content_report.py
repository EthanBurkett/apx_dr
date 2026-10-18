"""Produce attribution and progression documentation from the shipped registry."""
import csv
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def main():
    spec=json.loads((ROOT/'ui/content_catalog.json').read_text())
    entries=[e for e in spec['entries'] if not e.get('quarantined') and not e.get('moved_to')]
    lines=['# Community content credits','','Source: [CFGFactory community archive](https://cfgfactory.com/skins/category/32/).',
           'Names and author credits below follow the archived download records. The original games and models belong to their respective creators.',
           'Original archives, checksums and supplied readmes are retained in build/content-cache and build/content-staging. No downloaded scripts or executables are run or shipped.','',
           '| Category / ID | Content | Author / archive credit | Unlock | Source |','|---|---|---|---|---|']
    for e in sorted(entries,key=lambda e:(e['prestige'],e['level'],e['category'],e['id'])):
        clean=lambda value:str(value).replace('|','/').replace('\n',' ')
        unlock='Inactive; source retained' if e.get('inactive_profile') else f"P{e['prestige']} / LV {e['level']}"
        lines.append('| '+ ' | '.join([e['category']+' / '+str(e['id']),clean(e['name']),clean(e['author'] or 'Not credited in archive'),unlock,f"[Download record]({e['page']})"])+' |')
    lines+=['','## Shared dependencies','']
    for e in spec.get('shared_dependencies',[]):
        lines.append(f"- `{e['asset']}` — {e['author']}; [archive record]({e['page']}).")
    text='\n'.join(lines)+'\n'
    (ROOT/'docs/CONTENT_CREDITS.md').write_text(text,encoding='utf8')
    (ROOT/'src/content_credits.txt').write_text(text,encoding='utf8')
    counts={}
    for kind,table in [('Primary','itemTable'),('Knife','knifeTable'),('Operator','characterTable')]:
        rows=list(csv.reader((ROOT/'src/mp'/(table+'.csv')).read_text().splitlines()))
        counts[kind]=sum(bool(row) and (len(row)<9 or row[8]!='0') for row in rows)
    active=[e for e in entries if not e.get('inactive_profile')]
    print('Active content:',counts,'active community entries:',len(active),'retained community imports:',len(entries))

if __name__=='__main__': main()
