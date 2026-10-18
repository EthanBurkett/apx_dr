"""Fetch the private SDK, package a committed build, or deploy it over SSH.

Credentials arrive through APX_DEPLOY_KEY and APX_SSH_KNOWN_HOSTS environment
variables. Nothing private enters the release archive or the command line.
"""
import argparse
from contextlib import contextmanager
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REMOTE = 'apxdeploy@10.50.0.10'
JUMP = 'apx-ci@apx.ethanburkett.dev'
PUBLIC = ('mod.ff', 'apx_dr.iwd', 'apx_dr_sounds.iwd')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def secure_windows_key(path):
    powershell = str(Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe')
    # Start with a fresh DACL. Removing inheritance alone leaves explicit
    # OWNER RIGHTS entries installed by the hosted runner's temp directory.
    script = '''$ErrorActionPreference = 'Stop'
$account = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$acl = New-Object System.Security.AccessControl.FileSecurity
$acl.SetOwner($account.User)
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($account.User, 'FullControl', 'Allow')
$acl.AddAccessRule($rule)
[System.IO.File]::SetAccessControl($env:APX_SSH_IDENTITY, $acl)
'''
    environment = dict(os.environ, APX_SSH_IDENTITY=str(path))
    subprocess.run([powershell, '-NoProfile', '-NonInteractive', '-Command', script],
                   check=True, env=environment, stdout=subprocess.DEVNULL)


@contextmanager
def ssh_options():
    key = os.environ.get('APX_DEPLOY_KEY', '')
    hosts = os.environ.get('APX_SSH_KNOWN_HOSTS', '')
    if not key or not hosts:
        raise ValueError('Set APX_DEPLOY_KEY and APX_SSH_KNOWN_HOSTS')
    with tempfile.TemporaryDirectory(prefix='apx-deploy-ssh-') as folder:
        identity = Path(folder) / 'identity'
        identity.write_text(key.strip() + '\n', encoding='ascii')
        identity.chmod(0o600)
        known = Path(folder) / 'known_hosts'
        known.write_text(hosts.strip() + '\n', encoding='ascii')
        if os.name == 'nt':
            secure_windows_key(identity)
        # ProxyJump's inner SSH process inherits -F, unlike command-line -i.
        config = Path(folder) / 'config'
        config.write_text(
            'Host *\n  IdentityFile "' + identity.as_posix() + '"\n'
            '  IdentitiesOnly yes\n  BatchMode yes\n  StrictHostKeyChecking yes\n'
            '  UserKnownHostsFile "' + known.as_posix() + '"\n  ConnectTimeout 20\n'
            'Host 10.50.0.10\n  ProxyJump ' + JUMP + '\n', encoding='ascii')
        yield ['-F', str(config)]


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('trigger', help='Start the production workflow for main using your gh login')
    fetch = sub.add_parser('fetch-sdk')
    fetch.add_argument('--output', type=Path, default=ROOT / 'build/ci-sdk.zip')
    pack = sub.add_parser('package')
    deploy = sub.add_parser('deploy')
    for command in (pack, deploy):
        command.add_argument('--artifacts', type=Path, default=ROOT / 'dist')
        command.add_argument('--revision', default=git('rev-parse', 'HEAD').decode().strip())
        command.add_argument('--output', type=Path, default=ROOT / 'build/public-release.tar')
    args = parser.parse_args()
    if args.command == 'trigger':
        subprocess.run(['gh', 'workflow', 'run', 'deploy.yml', '--ref', 'main',
                        '--repo', 'EthanBurkett/apx_dr'], check=True)
        print('Production workflow requested; follow it in GitHub Actions.')
        return
    if args.command == 'fetch-sdk':
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with ssh_options() as options:
            subprocess.run(['scp', '-q', *options, REMOTE + ':/srv/apx-dr/sdk/build-sdk.zip', str(args.output)], check=True)
        expected = os.environ.get('APX_SDK_SHA256', '')
        with args.output.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha256').hexdigest()
        if not re.fullmatch('[0-9a-f]{64}', expected) or actual != expected:
            raise ValueError('Private SDK archive failed its pinned checksum')
        print('Private SDK archive checksum verified.')
        return
    package(args.output, args.artifacts, args.revision)
    if args.command == 'package':
        return
    with ssh_options() as options:
        remote_path = '/srv/apx-dr/incoming/' + args.revision + '.tar'
        subprocess.run(['scp', '-q', *options, str(args.output), REMOTE + ':' + remote_path + '.pending'], check=True)
        subprocess.run(['ssh', *options, REMOTE, 'mv', remote_path + '.pending', remote_path], check=True)
        subprocess.run(['ssh', *options, REMOTE, 'sudo', '/usr/local/sbin/apx-deploy', args.revision], check=True)


if __name__ == '__main__':
    main()
