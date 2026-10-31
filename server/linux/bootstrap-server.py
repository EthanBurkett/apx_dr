#!/usr/bin/env python3
"""Install the verified release in the new Miami guest, through Teleport.

Inputs stay in /root/apx-install. Licensed base files arrive on a temporary
read-only virtual disk; secrets are never served over HTTP or printed.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import pwd
import secrets
import shutil
import socket
import string
import subprocess
import tarfile

WORK=Path('/root/apx-install')
BASE=Path('/srv/apx-dr')
BINARY_SHA='3574542eec0d4d2bfa1e177fbf358314b8615d70e802e908c294daeba1ecf36b'


def run(*args):
    print('+',' '.join(map(str,args)),flush=True)
    subprocess.run(list(map(str,args)),check=True)


def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def main():
    if os.getuid()!=0 or socket.gethostname()!='apx-dr-mia':raise SystemExit('Run as root inside apx-dr-mia only.')
    try:pwd.getpwnam('apxdr')
    except KeyError:run('useradd','--system','--home-dir','/var/lib/apx-dr','--create-home','--shell','/usr/sbin/nologin','apxdr')
    BASE.mkdir(mode=0o750,exist_ok=True)
    game=BASE/'game';game.mkdir(mode=0o750,exist_ok=True)
    (game/'mods').mkdir(exist_ok=True)
    (BASE/'releases').mkdir(mode=0o750,exist_ok=True)
    run('chown','root:apxdr',BASE,game,game/'mods',BASE/'releases')
    # Teleport sessions deliberately use a restrictive umask. Set group access
    # explicitly, rather than relying on mkdir's requested mode surviving it.
    for path in (BASE,game,game/'mods',BASE/'releases'):path.chmod(0o750)
    files=json.loads((WORK/'base-game-files.json').read_text())
    devices=json.loads(subprocess.check_output(['lsblk','-J','-o','PATH,SERIAL']))['blockdevices']
    disk=next(row['path'] for row in devices if row.get('serial')=='apx-base')
    if subprocess.check_output(['blockdev','--getro',disk],text=True).strip()!='1':raise SystemExit('Bootstrap disk must be read-only.')
    with tarfile.open(disk,'r:') as archive:
        members=archive.getmembers()
        if {m.name for m in members}!={r['path'] for r in files}:raise ValueError('Base archive differs from its manifest.')
        if any(not m.isfile() or PurePosixPath(m.name).is_absolute() or '..' in PurePosixPath(m.name).parts for m in members):
            raise ValueError('Unexpected base archive member.')
        archive.extractall(game,filter='data')
    for row in files:
        path=game/row['path']
        if path.stat().st_size!=row['bytes'] or digest(path)!=row['sha256']:raise ValueError('Base file checksum mismatch: '+row['path'])
        os.chown(path,0,pwd.getpwnam('apxdr').pw_gid);path.chmod(0o640)
        parent=path.parent
        while parent!=game:
            os.chown(parent,0,pwd.getpwnam('apxdr').pw_gid);parent.chmod(0o750)
            parent=parent.parent
    print('Verified all '+str(len(files))+' licensed base-game files.',flush=True)
    binary=WORK/'apx_cod4x_dedrun'
    if digest(binary)!=BINARY_SHA:raise ValueError('Native executable checksum mismatch.')
    shutil.copy2(binary,game/'apx_cod4x_dedrun');(game/'apx_cod4x_dedrun').chmod(0o755)
    run('ldd',game/'apx_cod4x_dedrun')
    spec=importlib.util.spec_from_file_location('release_deploy',WORK/'deploy.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    with tarfile.open(WORK/'release.tar','r:') as archive:manifest=json.load(archive.extractfile('manifest.json'))
    revision=manifest['revision'];release=BASE/'releases'/revision
    module.extract_release(WORK/'release.tar',release,revision)
    run('chgrp','-R','apxdr',release)
    run('chmod','-R','g+rX,o-rwx',release)
    link=game/'mods/apx_dr'
    if link.exists() or link.is_symlink():
        if link.resolve()!=release.resolve():raise SystemExit('Existing installation points at another release; inspect it.')
    else:link.symlink_to(release)
    etc=Path('/etc/apx-dr');etc.mkdir(mode=0o750,exist_ok=True)
    private=etc/'private.cfg'
    handoff=etc/'operator-credentials.txt'
    if not private.exists():
        rcon=''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(12))
        admin=secrets.token_hex(16)
        token=(WORK/'master-token.txt').read_text().strip()
        if len(token)!=40 or any(c not in string.hexdigits for c in token):raise ValueError('Invalid saved listing-token format.')
        private.write_text('// Private operator credentials. Never publish.\n'
            +'set rcon_password "'+rcon+'"\n'
            +'set dr_admin_loginpass_0 "hype;'+admin+';bcdefghijklmnopv"\n'
            +'set sv_authtoken "'+token+'"\n')
        private.chmod(0o640)
        handoff.write_text('ApX Deathrun / Miami\nEndpoint: apx.ethanburkett.dev:28960\n'
            +'RCON password: '+rcon+'\nAdmin username: hype\nAdmin login password: '+admin+'\n')
        handoff.chmod(0o600)
    elif not handoff.exists():raise SystemExit('Existing credentials are not from this bootstrap; inspect them.')
    shutil.copyfile(WORK/'bunny.env',etc/'bunny.env');(etc/'bunny.env').chmod(0o600)
    shutil.copyfile(WORK/'maps.json',BASE/'map-files.json')
    # Files copied from a Windows checkout must be normalized before a POSIX
    # shell executes them. Do not rely on git checkout settings during transfer.
    for name in ('install.sh','apx-dr.service'):
        path=WORK/name;path.write_text(path.read_text())
    run('sh',WORK/'install.sh')
    Path('/etc/nftables.conf').write_text('''#!/usr/sbin/nft -f
flush ruleset
table inet apx_guest {
 chain input {
  type filter hook input priority 0; policy drop;
  iifname "lo" accept
  ct state established,related accept
  ct state invalid drop
  ip protocol icmp accept
  meta l4proto ipv6-icmp accept
  udp dport 28960 accept
 }
 chain forward { type filter hook forward priority 0; policy drop; }
 chain output { type filter hook output priority 0; policy accept; }
}
''')
    run('nft','-c','-f','/etc/nftables.conf')
    run('systemctl','enable','--now','nftables.service')
    resolved=Path('/etc/systemd/resolved.conf.d');resolved.mkdir(exist_ok=True)
    (resolved/'apx.conf').write_text('[Resolve]\nLLMNR=no\nMulticastDNS=no\n')
    run('systemctl','restart','systemd-resolved')
    run('systemctl','disable','--now','exim4.service')
    record={'revision':revision,'binary_sha256':BINARY_SHA,'base_files':len(files),'mod_files':manifest['files']}
    (BASE/'bootstrap.json').write_text(json.dumps(record,indent=2)+'\n')
    print('Verified server installation complete; service is deliberately not started until maps and CDN agree.',flush=True)


if __name__=='__main__':main()
