"""Asset-budget policy shared by rotation generation and regression tests."""
import hashlib
import json
from pathlib import Path


def source_signature(root):
    root=Path(root)
    paths=[]
    # Names/references and active tables determine pool occupancy. Pixel payload
    # and mesh vertex streams affect memory, not the number of asset records.
    for folder in ('manifests','src/ui','src/ui_mp','src/weapons','src/mp',
                   'assets/xmodel','assets/materials','assets/fx','assets/techsets','assets/techniques'):
        # Script-only control-flow repairs do not change the linked pool assets.
        paths.extend(p for p in (root/folder).rglob('*') if p.is_file() and p.suffix.lower()!='.gsc')
    digest=hashlib.sha256()
    for path in sorted(paths,key=lambda p:p.relative_to(root).as_posix()):
        digest.update(path.relative_to(root).as_posix().encode()+b'\0')
        payload=path.read_bytes()
        # Git normalizes source text to LF. Windows checkout line endings must
        # not invalidate measurements for identical resource references.
        if path.relative_to(root).parts[0] in ('manifests','src'):
            payload=payload.replace(b'\r\n',b'\n')
            payload=b'\n'.join(line.rstrip(b' \t') for line in payload.split(b'\n'))
        digest.update(hashlib.sha256(payload).digest())
    return digest.hexdigest()


def compatible(record,limits):
    if not record:return False,'Not measured for this asset build'
    if record.get('error'):return False,'Native map load failed; repair and retest'
    usage=record.get('usage',{})
    for kind,maximum in limits.items():
        if kind not in usage:return False,'Missing '+kind+' counter'
        if usage[kind]>maximum:return False,kind+' uses '+str(usage[kind])+' / budget '+str(maximum)
    if usage.get('material',0)<=0:return False,'No loaded map assets'
    if record.get('measurement')=='baseline-plus-image-pages':
        return True,'Measured baseline plus image-page dependencies; within client-zone asset budgets'
    return True,'Measured within client-zone asset budgets'


def public_report(report,root,limits):
    if set(report.get('client_zones',[]))!={'ui_mp','localized_common_mp'}:
        raise ValueError('Budget report must include the extra client startup zones')
    rows=[]
    for row in report['maps']:
        allowed,reason=compatible(row,limits)
        result={'map':row['map'],'compatible':allowed,'reason':reason}
        if 'usage' in row:result['usage']={key:row['usage'][key] for key in limits if key in row['usage']}
        if row.get('error'):result['error']='Native map load failed'
        rows.append(result)
    return {'source_signature':source_signature(root),'mod_sha256':report['mod_sha256'],
            'client_zones':report['client_zones'],'limits':limits,'maps':sorted(rows,key=lambda r:r['map'])}
