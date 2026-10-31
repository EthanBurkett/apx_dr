"""Package committed public files and deploy through recorded Teleport sessions.

No OpenSSH client, ProxyJump, personal key export or direct host connection is
used. Authenticate with Teleport Connect/tsh first. CI is intentionally disabled.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[1]
PUBLIC=('mod.ff','apx_dr.iwd','apx_dr_sounds.iwd')


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT)


def package(output, artifacts, revision):
    if not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('Expected a full commit SHA')
    if git('rev-parse', 'HEAD').decode().strip() != revision:
        raise ValueError('Build checkout must match the release revision')
    dirty = git('diff', '--name-only', 'HEAD', '--', 'src', 'assets', 'manifests', 'ui').decode().splitlines()
    dirty = [name for name in dirty if not re.fullmatch(r'assets/shader_bin/(?:shader_names|(?:vs|ps)_[23]_0_[0-9a-f]{8})', name)]
    if dirty:
        raise ValueError('Commit generated menus/assets and source changes before deployment')
    payload = {}
    for name in PUBLIC:
        path = artifacts / name
        if not path.is_file() or path.stat().st_size < 1024:
            raise ValueError('Missing/empty build artifact: ' + name)
        payload[name] = path
    configs = git('ls-tree', '-r', '--name-only', revision, 'config').decode().splitlines()
    for name in configs:
        if 'private' in name.lower() or not name.endswith('.cfg'):
            continue
        relative = name.removeprefix('config/')
        destination = relative if '/' not in relative else name
        payload[destination] = git('show', revision + ':' + name)
    manifest = {'revision': revision, 'files': {}}
    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(output, 'w') as bundle:
        for name, value in sorted(payload.items()):
            if isinstance(value, Path):
                with value.open('rb') as stream:
                    manifest['files'][name] = hashlib.file_digest(stream, 'sha256').hexdigest()
                bundle.add(value, arcname=name, recursive=False)
            else:
                manifest['files'][name] = hashlib.sha256(value).hexdigest()
                info = tarfile.TarInfo(name)
                info.size = len(value)
                info.mode = 0o640
                bundle.addfile(info, io.BytesIO(value))
        data = (json.dumps(manifest, sort_keys=True, indent=2) + '\n').encode()
        info = tarfile.TarInfo('manifest.json')
        info.size = len(data)
        bundle.addfile(info, io.BytesIO(data))
    print('Packaged committed release ' + revision, flush=True)


def transport_deploy(output,revision,node='apx-dr-mia'):
    if not re.fullmatch('[0-9a-f]{40}',revision):raise ValueError('Expected a full commit SHA')
    if not re.fullmatch('[a-zA-Z0-9][a-zA-Z0-9._-]*',node):raise ValueError('Invalid Teleport node')
    target='root@'+node
    remote='/srv/apx-dr/incoming/'+revision+'.tar'
    subprocess.run(['tsh','scp',str(output),target+':'+remote+'.pending'],check=True)
    subprocess.run(['tsh','ssh','-t',target,'mv',remote+'.pending',remote],check=True)
    subprocess.run(['tsh','ssh','-t',target,'/usr/local/sbin/apx-deploy',revision],check=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    sub=parser.add_subparsers(dest='command',required=True)
    sub.add_parser('trigger',help='Explain the retired CI trigger')
    pack=sub.add_parser('package',help='Package committed public files only')
    deploy=sub.add_parser('deploy',help='Upload through Teleport and activate in a recorded terminal')
    deploy.add_argument('--node',default='apx-dr-mia')
    for command in (pack,deploy):
        command.add_argument('--artifacts',type=Path,default=ROOT/'dist')
        command.add_argument('--revision',default=git('rev-parse','HEAD').decode().strip())
        command.add_argument('--output',type=Path,default=ROOT/'build/public-release.tar')
    args=parser.parse_args()
    if args.command=='trigger':
        raise SystemExit('CI deployment is intentionally disabled. Use: python tools/deploy.py deploy (Teleport only).')
    package(args.output,args.artifacts,args.revision)
    if args.command=='deploy':transport_deploy(args.output,args.revision,args.node)


if __name__=='__main__':main()
