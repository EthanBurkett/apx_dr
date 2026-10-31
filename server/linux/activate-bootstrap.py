#!/usr/bin/env python3
"""Activate the initial Miami release after bootstrap and complete map sync.

Subsequent releases use apx-deploy COMMIT_SHA. Run in a recorded Teleport session.
"""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time

BASE = Path('/srv/apx-dr')


def main():
    if os.getuid() != 0 or socket.gethostname() != 'apx-dr-mia':
        raise SystemExit('Run as root inside apx-dr-mia only.')
    with Path('/run/lock/apx-dr-deploy.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if subprocess.run(['systemctl', 'is-active', '--quiet', 'apx-dr']).returncode == 0:
            raise SystemExit('Server is already active; use the manual deployment workflow.')
        state = json.loads((BASE / 'bootstrap.json').read_text())
        revision = state['revision']
        if not re.fullmatch('[0-9a-f]{40}', revision):
            raise ValueError('Invalid bootstrap revision.')
        report = json.loads((BASE / 'map-sync.json').read_text())
        expected = {row['path'] for row in json.loads((BASE / 'map-files.json').read_text())}
        if not expected or report['errors'] or {row['path'] for row in report['verified']} != expected:
            raise ValueError('Complete the map/CDN sync before activating.')
        if not (BASE / 'steam-runtime.json').exists():
            raise ValueError('Install the pinned Steam runtime before activating.')
        spec = importlib.util.spec_from_file_location('release_deploy', '/usr/local/lib/apx-dr/deploy.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        release = BASE / 'releases' / revision
        if (BASE / 'game/mods/apx_dr').resolve() != release:
            raise ValueError('Active release link differs from the bootstrap revision.')
        module.prepare_rotation(release, revision)
        module.smoke(release, revision)
        module.publish_cdn(release, module.credentials())
        module.service('start')
        if not module.healthy(28960, timeout=60, settle=5):
            module.service('stop')
            raise RuntimeError('Initial service did not pass its health check; inspect private logs.')
        maps = set(re.findall(r'\bmap (mp_[a-z0-9_]+)', (release / 'config/server/rotation.cfg').read_text()))
        record = {'revision': revision, 'previous': None, 'files': state['mod_files'], 'maps': len(maps),
                  'deployed_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                  'teleport_node': 'apx-dr-mia', 'endpoint': '103.195.100.33:28960'}
        Path('/var/lib/apx-dr/deployed.json').write_text(json.dumps(record, indent=2) + '\n')
        print('Initial server and CDN checks passed; ' + str(len(maps)) + ' maps available.')


if __name__ == '__main__':
    main()
