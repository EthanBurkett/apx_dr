#!/usr/bin/env python3
"""Root-owned deployment entry point. CI may supply a release, never root code.

Install outside the checkout at /usr/local/lib/apx-dr/deploy.py. The dedicated
SSH user can invoke this program with one commit SHA through a narrow sudo rule.
"""
import hashlib
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from urllib.parse import quote

BASE = Path('/srv/apx-dr')
PUBLIC = ('mod.ff', 'apx_dr.iwd', 'apx_dr_sounds.iwd')
CDN = 'http://cdn.apx.ethanburkett.dev'
STORAGE = 'https://storage.bunnycdn.com/apxcod4assets/mods/apx_dr/'
PULL_ZONE = 6826235


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def allowed_member(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name:
        return False
    if name in (*PUBLIC, 'manifest.json', 'server.cfg', 'deathrun.cfg', 'dr_songs.cfg', 'dr_sprays.cfg'):
        return True
    return (len(path.parts) >= 2 and path.parts[0] == 'config'
            and path.suffix == '.cfg' and 'private' not in name.lower()
            and len(path.parts) <= 4)


def _extract_release(archive, destination, revision):
    with tarfile.open(archive, 'r:') as bundle:
        members = bundle.getmembers()
        names = [member.name for member in members]
        if len(names) != len(set(names)) or len(names) > 150:
            raise ValueError('Duplicate or excessive release members')
        if any(not member.isfile() or not allowed_member(member.name) for member in members):
            raise ValueError('Release contains a forbidden path or file type')
        if sum(member.size for member in members) > 4 * 1024**3:
            raise ValueError('Release exceeds its size limit')
        if 'manifest.json' not in names:
            raise ValueError('Missing release manifest')
        manifest = json.load(bundle.extractfile('manifest.json'))
        if manifest.get('revision') != revision or set(manifest.get('files', {})) != set(names) - {'manifest.json'}:
            raise ValueError('Manifest does not match this release')
        required = {*PUBLIC, 'server.cfg', 'deathrun.cfg', 'config/server/rotation.cfg'}
        if not required.issubset(names):
            raise ValueError('Release is incomplete')
        destination.mkdir(mode=0o750)
        for member in members:
            target = destination / member.name
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.extractfile(member) as source, target.open('xb') as output:
                while data := source.read(1024 * 1024):
                    output.write(data)
            if member.name != 'manifest.json' and digest(target) != manifest['files'][member.name]:
                raise ValueError('Release checksum mismatch: ' + member.name)
    return manifest


def extract_release(archive, destination, revision):
    fingerprint = digest(archive)
    if destination.exists():
        record = destination / '.archive-sha256'
        if record.is_file() and record.read_text().strip() == fingerprint:
            return json.loads((destination / 'manifest.json').read_text())
        raise ValueError('A different candidate already exists for this commit')
    with tempfile.TemporaryDirectory(prefix='.apx-candidate-', dir=destination.parent) as folder:
        pending = Path(folder) / 'release'
        manifest = _extract_release(archive, pending, revision)
        (pending / '.archive-sha256').write_text(fingerprint + '\n')
        pending.rename(destination)
    return manifest


def credentials():
    values = {}
    for line in Path('/etc/apx-dr/bunny.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            values[name.strip().lower()] = value.strip().strip('"\'')
    if not values.get('access_key') or not values.get('api_key'):
        raise ValueError('Deployment needs storage and purge keys in the private Bunny env file')
    return values


def purge(keys):
    request = Request(f'https://api.bunny.net/pullzone/{PULL_ZONE}/purgeCache',
                      data=b'{}', method='POST',
                      headers={'AccessKey': keys['api_key'], 'Content-Type': 'application/json'})
    with urlopen(request, timeout=60) as reply:
        if reply.status not in (200, 204):
            raise RuntimeError('CDN purge did not succeed')


def prepare_rotation(release, revision):
    config = release / 'config/server/rotation.cfg'
    requested = config.with_name('.rotation.requested.cfg')
    if not requested.exists():
        requested.write_bytes(config.read_bytes())
    names = list(dict.fromkeys(re.findall(r'\bmap\s+(mp_[A-Za-z0-9_]+)', requested.read_text())))
    records = json.loads((BASE / 'map-files.json').read_text())
    selected = [row for row in records if row['path'].split('/')[0] in names]
    def available(row):
        url = CDN + '/usermaps/' + quote(row['path'], safe='/') + '?apx_ready=' + revision
        try:
            with urlopen(Request(url, method='HEAD'), timeout=15) as response:
                ok = response.status == 200 and int(response.headers.get('Content-Length', '-1')) == row['bytes']
        except OSError:
            ok = False
        return row['path'], ok
    with ThreadPoolExecutor(max_workers=16) as pool:
        ready = dict(pool.map(available, selected))
    accepted = []
    for name in names:
        files = [row['path'] for row in selected if row['path'].split('/')[0] == name]
        if files and all(ready.get(path) for path in files):
            accepted.append(name)
    if not accepted or 'mp_deathrun_supermario' not in accepted:
        raise RuntimeError('The starting map or complete CDN rotation is not available')
    pages = []
    for name in accepted:
        command = 'map ' + name
        if not pages or len(pages[-1]) + len(command) + 1 > 800:
            pages.append(command)
        else:
            pages[-1] += ' ' + command
    lines = ['// Measured maps with complete public CDN downloads.', 'set apx_rotation_page_count ' + str(len(pages))]
    lines += [f'set apx_rotation_{i} "{page}"' for i, page in enumerate(pages)]
    lines += ['set sv_mapRotation "gametype deathrun ' + pages[0] + '"', 'set sv_mapRotationCurrent ""', '']
    config.write_text('\n'.join(lines))
    print(f'Rotation ready: {len(accepted)} maps; {len(names)-len(accepted)} uploads still pending.', flush=True)


def publish_cdn(release, keys):
    for name in PUBLIC:
        path = release / name
        with path.open('rb') as stream:
            request = Request(STORAGE + name, data=stream, method='PUT', headers={
                'AccessKey': keys['access_key'], 'Content-Type': 'application/octet-stream',
                'Content-Length': str(path.stat().st_size), 'Checksum': digest(path).upper()})
            with urlopen(request, timeout=600) as reply:
                if reply.status not in (200, 201):
                    raise RuntimeError('CDN upload failed: ' + name)
        print('Uploaded ' + name, flush=True)
    purge(keys)
    for name in PUBLIC:
        expected = digest(release / name)
        for attempt in range(6):
            try:
                with urlopen(CDN + '/mods/apx_dr/' + name, timeout=120) as reply:
                    actual = hashlib.file_digest(reply, 'sha256').hexdigest()
            except OSError:
                actual = None
            if actual == expected:
                break
            time.sleep(5)
        else:
            raise RuntimeError('Public CDN checksum mismatch: ' + name)
        print('Verified public CDN checksum: ' + name, flush=True)


def service(action):
    subprocess.run(['systemctl', action, 'apx-dr.service'], check=True)


def status(port):
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(1)
        sock.sendto(b'\xff\xff\xff\xffgetstatus apx-deploy', ('127.0.0.1', port))
        return sock.recv(65535).decode('utf-8', 'replace')


def healthy(port, process=None, timeout=45, settle=0):
    start = time.monotonic()
    while time.monotonic() - start < timeout:
        if process and process.poll() is not None:
            return False
        try:
            response = status(port)
            if 'statusResponse' in response and time.monotonic() - start >= settle:
                return True
        except OSError:
            pass
        time.sleep(1)
    return False


def smoke(release, revision):
    link = BASE / 'game/mods/apx_ci_smoke'
    if link.exists() or link.is_symlink():
        raise RuntimeError('A previous smoke-test link needs operator inspection')
    link.symlink_to(release)
    logdir = Path('/var/lib/apx-dr/deploy-logs')
    logdir.mkdir(exist_ok=True)
    log = logdir / (revision + '.log')
    command = ['runuser', '-u', 'apxdr', '--', str(BASE / 'game/apx_cod4x_dedrun'),
               '+set', 'dedicated', '1', '+set', 'net_ip', '127.0.0.1',
               '+set', 'net_port', '28961', '+set', 'sv_maxclients', '32',
               '+set', 'fs_basepath', str(BASE / 'game'),
               '+set', 'fs_homepath', '/var/lib/apx-dr/smoke',
               '+set', 'fs_game', 'mods/apx_ci_smoke', '+set', 'g_gametype', 'deathrun',
               '+exec', 'server.cfg', '+set', 'net_ip', '127.0.0.1', '+set', 'sv_authtoken', '',
               '+set', 'rcon_password', '', '+map', 'mp_deathrun_supermario']
    process = None
    try:
        with log.open('wb') as output:
            process = subprocess.Popen(command, cwd=BASE / 'game', stdout=output, stderr=subprocess.STDOUT)
            ok = healthy(28961, process, settle=20)
        errors = re.search(r'script (?:compile|runtime) error|Sys_Error|exceeded limit|cannot cast undefined',
                           log.read_text(errors='replace'), re.I)
        if not ok or errors:
            raise RuntimeError('Native candidate smoke test failed; inspect the private deployment log')
    finally:
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        link.unlink()


def activate(release):
    link = BASE / 'game/mods/apx_dr'
    temporary = link.with_name('.apx_dr.next')
    temporary.symlink_to(release)
    temporary.replace(link)


def main():
    import fcntl
    if os.geteuid() != 0 or len(sys.argv) != 2 or not re.fullmatch('[0-9a-f]{40}', sys.argv[1]):
        raise SystemExit('Usage: sudo apx-deploy COMMIT_SHA')
    revision = sys.argv[1]
    with Path('/run/lock/apx-dr-deploy.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        release = BASE / 'releases' / revision
        previous = (BASE / 'game/mods/apx_dr').resolve(strict=True)
        if previous.parent != BASE / 'releases':
            raise ValueError('Live release is outside the managed release directory')
        if previous == release:
            print('This commit is already active.')
            return
        keys = credentials()
        manifest = extract_release(BASE / 'incoming' / (revision + '.tar'), release, revision)
        # Keep operator credentials; only admit measured maps with complete CDN files.
        private = release / 'config/private.cfg'
        if not private.is_symlink():
            private.symlink_to('/etc/apx-dr/private.cfg')
        prepare_rotation(release, revision)
        (release / 'config/deathrun/testing.cfg').write_text('set g_bots 0\n')
        (release / 'config/server/downloads.cfg').write_text(
            f'set sv_allowdownload 1\nset sv_wwwDownload 1\nset sv_wwwBaseURL "{CDN}"\nset sv_wwwDlDisconnected 0\n')
        subprocess.run(['chgrp', '-R', 'apxdr', str(release)], check=True)
        subprocess.run(['chmod', '-R', 'g+rX,o-rwx', str(release)], check=True)
        smoke(release, revision)
        print('Native candidate smoke test passed.', flush=True)
        service('stop')
        try:
            publish_cdn(release, keys)
            activate(release)
            service('start')
            if not healthy(28960):
                raise RuntimeError('Live server did not answer its health check')
        except Exception:
            service('stop')
            print('Deployment failed; restoring the previous server and CDN files.', flush=True)
            publish_cdn(previous, keys)
            activate(previous)
            service('start')
            if not healthy(28960):
                raise RuntimeError('Rollback requires operator attention')
            raise
        Path('/var/lib/apx-dr/deployed.json').write_text(json.dumps({
            'revision': revision, 'previous': previous.name, 'files': manifest['files'],
            'deployed_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}, indent=2) + '\n')
        print('Deployed ' + revision + '; server and public CDN checks passed.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except HTTPError as error:
        raise SystemExit(f'Bunny/CDN HTTP {error.code}; response and credentials omitted')
