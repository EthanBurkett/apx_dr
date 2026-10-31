#!/usr/bin/env python3
"""One-time Miami VM bootstrap, run in an interactive Teleport host session.

Creates only VM 101 and its owned files. Cloud-init contains no credentials.
The downloaded guest image has OpenSSH units masked before its first boot.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import time
import urllib.request

WORK=Path('/root/apx-dr-provision')
VMID='101'
IP='10.77.0.20'
IMAGE='debian-13-genericcloud-amd64.qcow2'
SHA512='3ace18e33bdd036edb49d1f79342bd01d2ab980e35194edb0b410435cd543538d286a0bd13bbb0835f7862306e3d385ce2f6a70d8ecf0bd961111166adbc1b8e'


def run(*args,**kwargs):
    print('+',' '.join(map(str,args)),flush=True)
    return subprocess.run(list(map(str,args)),check=True,**kwargs)


def main():
    if subprocess.check_output(['hostname'],text=True).strip()!='mia-fl-01':
        raise SystemExit('This bootstrap is restricted to mia-fl-01.')
    resources=json.loads(subprocess.check_output(['pvesh','get','/cluster/resources','--type','vm','--output-format','json']))
    if any(str(row['vmid'])==VMID for row in resources):
        raise SystemExit('VM 101 already exists; inspect rather than overwriting it.')
    WORK.mkdir(mode=0o700,exist_ok=True)
    source=WORK/IMAGE
    if not source.exists():
        print('Downloading the official Debian cloud image.',flush=True)
        urllib.request.urlretrieve('https://cloud.debian.org/images/cloud/trixie/latest/'+IMAGE,source)
    with source.open('rb') as stream:
        if hashlib.file_digest(stream,'sha512').hexdigest()!=SHA512:
            raise SystemExit('Debian image checksum mismatch.')
    print('Debian SHA-512 verified.',flush=True)
    if Path('/sys/block/nbd0/pid').exists():raise SystemExit('nbd0 is busy; refusing to reuse it.')
    mount=WORK/'image-root';mount.mkdir(exist_ok=True)
    run('qemu-nbd','--connect=/dev/nbd0',source)
    mounted=False
    try:
        run('udevadm','settle')
        for attempt in range(50):
            block=json.loads(subprocess.check_output(['lsblk','-J','-b','-o','NAME,PATH,FSTYPE,SIZE','/dev/nbd0']))['blockdevices'][0]
            partitions=[p for p in block.get('children',[]) if p.get('fstype')=='ext4']
            if partitions:break
            time.sleep(.2)
        if not partitions:raise RuntimeError('Timed out waiting for the owned image partition scan.')
        root=max(partitions,key=lambda p:int(p['size']))['path']
        run('mount',root,mount);mounted=True
        if 'ID=debian' not in (mount/'etc/os-release').read_text():raise SystemExit('Unexpected image OS.')
        for name in ('ssh.service','sshd.service','ssh.socket','sshd.socket'):
            target=mount/'etc/systemd/system'/name
            target.unlink(missing_ok=True)
            target.symlink_to('/dev/null')
        print('OpenSSH units masked in the offline image before first boot.',flush=True)
    finally:
        if mounted:run('umount',mount)
        run('qemu-nbd','--disconnect','/dev/nbd0')
    snippet=Path('/mnt/pve/nvme0/snippets/apx-dr-101.yaml')
    snippet.parent.mkdir(exist_ok=True)
    snippet.write_bytes((WORK/'cloud-user.yaml').read_bytes());snippet.chmod(0o600)
    network='''#!/bin/sh
set -eu
ensure() { table=$1; shift; iptables -t "$table" -C "$@" 2>/dev/null || iptables -t "$table" -I "$@"; }
ensure nat PREROUTING -i vmbr0 -d 103.195.100.33 -p udp --dport 28960 -j DNAT --to-destination 10.77.0.20:28960
ensure filter FORWARD -i vmbr0 -o vmbr1 -d 10.77.0.20 -p udp --dport 28960 -j ACCEPT
ensure filter FORWARD -i vmbr1 -o wt0 -s 10.77.0.20 -d 100.76.142.172 -p tcp --dport 443 -j ACCEPT
ensure filter FORWARD -i wt0 -o vmbr1 -s 100.76.142.172 -d 10.77.0.20 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ensure nat POSTROUTING -o wt0 -s 10.77.0.20 -d 100.76.142.172 -p tcp --dport 443 -j SNAT --to-source 100.76.123.100
'''
    Path('/usr/local/sbin/apx-dr-network').write_text(network)
    Path('/usr/local/sbin/apx-dr-network').chmod(0o750)
    Path('/etc/systemd/system/apx-dr-network.service').write_text('''[Unit]
Description=ApX game UDP and Teleport-only VM network rules
Wants=network-online.target
After=network-online.target pve-firewall.service netbird.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/apx-dr-network
[Install]
WantedBy=multi-user.target
''')
    run('systemctl','daemon-reload')
    run('systemctl','enable','--now','apx-dr-network.service')
    run('qm','create',VMID,'--name','apx-dr-mia','--memory','8192','--cores','4','--cpu','host',
        '--net0','virtio,bridge=vmbr1','--scsihw','virtio-scsi-single','--agent','enabled=1',
        '--serial0','socket','--vga','serial0','--ostype','l26','--onboot','1',
        '--description','ApX Deathrun production. Miami. Administration exclusively through Teleport; no OpenSSH.')
    run('qm','set',VMID,'--scsi0','nvme0:0,import-from='+str(source)+',format=qcow2,discard=on,iothread=1')
    run('qm','resize',VMID,'scsi0','128G')
    run('qm','set',VMID,'--ide2','nvme0:cloudinit','--boot','order=scsi0',
        '--ipconfig0','ip='+IP+'/24,gw=10.77.0.1','--nameserver','1.1.1.1 9.9.9.9',
        '--cicustom','user=nvme0:snippets/apx-dr-101.yaml')
    run('qm','start',VMID)
    print('VM 101 started: apx-dr-mia, '+IP+', public UDP 103.195.100.33:28960.',flush=True)


if __name__=='__main__':main()
