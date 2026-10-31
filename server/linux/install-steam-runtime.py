#!/usr/bin/env python3
"""Install the hash-pinned CoD4x Steam runtime, without replacing the server.

Run as root in a recorded Teleport terminal on apx-dr-mia. Only two verified
ELF32 libraries are taken from the upstream-recommended community container.
No container daemon, container commands, stock executable or bundled libc is used.
"""
import hashlib
import io
import json
import os
from pathlib import Path
import pwd
import socket
import tarfile
from urllib.request import Request, urlopen

REPOSITORY = 'alexandercurl/cod4x-server'
DIGEST = 'sha256:522f90b194ead1bf001b53b770b365f0b7a32f6d1e84f7dac139d27bbd4fc962'
EXPECTED = {
    'steam_api.so': '85e7254f95eedc7306d1506a8b0f593381507ffe5f880d8e7a944d9dc5b549b8',
    'steamclient.so': '56a07761e0eb4b4709816bc8d0ee72bad84daaea399ebdfd3ee0302c5f096035',
}
BINARY_SHA = '3574542eec0d4d2bfa1e177fbf358314b8615d70e802e908c294daeba1ecf36b'


def main():
    if os.getuid() != 0 or socket.gethostname() != 'apx-dr-mia':
        raise SystemExit('Run as root inside apx-dr-mia only.')
    game = Path('/srv/apx-dr/game')
    binary = game / 'apx_cod4x_dedrun'
    if hashlib.sha256(binary.read_bytes()).hexdigest() != BINARY_SHA:
        raise ValueError('Unexpected server executable; inspect before installing runtime.')
    registry = 'https://registry-1.docker.io/v2/' + REPOSITORY
    with urlopen('https://auth.docker.io/token?service=registry.docker.io&scope=repository:'
                 + REPOSITORY + ':pull', timeout=30) as response:
        token = json.load(response)['token']
    headers = {'Authorization': 'Bearer ' + token,
               'Accept': 'application/vnd.docker.distribution.manifest.v2+json'}

    def get(url, maximum):
        with urlopen(Request(url, headers=headers), timeout=90) as response:
            payload = response.read(maximum + 1)
        if len(payload) > maximum:
            raise ValueError('Registry response exceeds its size limit.')
        return payload

    raw = get(registry + '/manifests/' + DIGEST, 2 * 1024 * 1024)
    if 'sha256:' + hashlib.sha256(raw).hexdigest() != DIGEST:
        raise ValueError('Container manifest checksum mismatch.')
    manifest = json.loads(raw)
    payloads, records = {}, []
    for layer in manifest['layers']:
        if layer['size'] > 120 * 1024 * 1024:
            continue
        blob = get(registry + '/blobs/' + layer['digest'], layer['size'])
        if len(blob) != layer['size'] or 'sha256:' + hashlib.sha256(blob).hexdigest() != layer['digest']:
            raise ValueError('Container layer checksum mismatch.')
        with tarfile.open(fileobj=io.BytesIO(blob), mode='r:*') as archive:
            for member in archive:
                name = Path(member.name).name
                if name not in EXPECTED or not member.isfile():
                    continue
                if member.size > 32 * 1024 * 1024:
                    raise ValueError('Unexpected runtime library size.')
                payload = archive.extractfile(member).read()
                checksum = hashlib.sha256(payload).hexdigest()
                if payload[:5] != b'\x7fELF\x01' or checksum != EXPECTED[name]:
                    raise ValueError('Runtime checksum/architecture mismatch: ' + name)
                payloads[name] = payload
                records.append({'file': name, 'bytes': len(payload), 'sha256': checksum,
                                'layer': layer['digest']})
        if set(payloads) == set(EXPECTED):
            break
    if set(payloads) != set(EXPECTED):
        raise ValueError('Incomplete runtime; no installed libraries were changed.')
    account = pwd.getpwnam('apxdr')
    for name, payload in payloads.items():
        candidate = game / (name + '.pending')
        with candidate.open('wb') as stream:
            stream.write(payload)
        os.chown(candidate, 0, account.pw_gid)
        candidate.chmod(0o640)
        candidate.replace(game / name)
    steam = Path('/var/lib/apx-dr/.steam')
    sdk = steam / 'sdk32'
    sdk.mkdir(parents=True, exist_ok=True)
    for folder in (steam, sdk):
        os.chown(folder, account.pw_uid, account.pw_gid)
        folder.chmod(0o750)
    link = sdk / 'steamclient.so'
    target = game / 'steamclient.so'
    if link.is_symlink() and link.readlink() == target:
        pass
    elif link.exists() or link.is_symlink():
        raise ValueError('Existing Steam SDK link/file differs; inspect it.')
    else:
        link.symlink_to(target)
    provenance = Path('/srv/apx-dr/steam-runtime.json')
    provenance.write_text(json.dumps({'image': REPOSITORY, 'digest': DIGEST,
                                     'files': records}, indent=2) + '\n')
    provenance.chmod(0o644)
    print('Verified Steam libraries installed. Restart apx-dr and check Steam connection in the journal.')


if __name__ == '__main__':
    main()
