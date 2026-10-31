# Miami server and Teleport deployment

The public server is VM **101**, `apx-dr-mia`, on **mia-fl-01** in Miami:
4 host CPU cores, 8 GiB RAM and a 128 GiB NVMe-backed disk. Public game endpoint:
`apx.ethanburkett.dev:28960` (`103.195.100.33`, UDP). The guest uses
`10.77.0.20/24` behind `10.77.0.1`. DNS must remain DNS-only for the game endpoint.

The previous server and its Proxmox host were removed. Do not use the retired
IP, ProxyJump connection, direct SSH clients, or direct port-22 access.
**All administration uses Teleport. Use interactive terminals so activity is
captured in session recordings.** The guest has no OpenSSH server. Teleport
connects outward through its authenticated reverse tunnel, with no public
administrative listener. The `apx-dr-operator` role limits root access to nodes
labelled `project=apx-dr,service=apx-dr` and requires strict session recording.

## Operate

Authenticate with Teleport Connect, then:

```powershell
tsh ls
tsh ssh -t root@apx-dr-mia
```

Inside that recorded session:

```sh
systemctl status apx-dr
journalctl -u apx-dr -n 60 --no-pager
systemctl restart apx-dr
cat /var/lib/apx-dr/deployed.json
```

Journal output and private settings must remain private. Do not print password,
admin-login or listing-token cvars into recordings. Credentials live in
`/etc/apx-dr/private.cfg`; the private operator handoff is
`/etc/apx-dr/operator-credentials.txt`. Bunny keys live in `/etc/apx-dr/bunny.env`.
None of these belongs in Git, an Actions artifact, a release archive, or FastDL.

The service runs as unprivileged `apxdr`, restarts on failure, starts on boot,
and writes only its runtime home and update-lock file. Base `g_speed` is 210.
Public spectator chat is enabled throughout the match. Managed test bots are off.

The initial release is `6d3e1641e2b1cf7908a3795287a069beb52a8a8a`. Public UDP
status queries, Steam connection, a full VM reboot and the CoD4x master-list entry
were verified. Both the game service and Teleport reconnect automatically.
The custom server executable retains SHA-256
`3574542eec0d4d2bfa1e177fbf358314b8615d70e802e908c294daeba1ecf36b`.
An actual player join is still needed to confirm the complete client experience.

## Manual update

CI deployment is intentionally disabled at the owner's request. The obsolete
SSH deployment secret and known-hosts variable were removed. Do not re-enable
the old workflow; any future automation must use Teleport and the existing
self-hosted runner infrastructure.

Build and validate a committed checkout using the normal Windows SDK tools:

```powershell
python tools/check.py --suite full
.\tools\build.ps1
python tools/deploy.py deploy
```

The manual uploader uses `tsh scp`, then activates the release through `tsh ssh
-t`, so the remote terminal output is recorded. It never exports personal keys,
uses `ssh.exe`/`scp.exe`, or falls back to a direct host connection. For a separate
package/upload/activation flow:

```powershell
python tools/deploy.py package --output build/public-release.tar
# Replace COMMIT_SHA with the exact 40-character packaged commit.
tsh scp build/public-release.tar root@apx-dr-mia:/srv/apx-dr/incoming/COMMIT_SHA.tar
tsh ssh -t root@apx-dr-mia
```

Then, inside the interactive remote terminal:

```sh
/usr/local/sbin/apx-deploy COMMIT_SHA
```

The root-owned helper validates archive paths/checksums, preserves private
settings, restricts rotation to measured maps with complete CDN files, runs a
loopback native smoke test, publishes the three public mod files, purges Bunny's
cache, verifies public download hashes, then switches and checks the service.
Activation failures restore the previous server and CDN files. Deployment
briefly disconnects players. Candidate releases remain available for inspection.

## Layout

| Path | Purpose |
|---|---|
| `/srv/apx-dr/game` | Licensed base assets, native executable and usermaps |
| `/srv/apx-dr/game/mods/apx_dr` | Symlink to the active release |
| `/srv/apx-dr/releases/<commit>` | Verified, retained public release files |
| `/srv/apx-dr/incoming` | Operator-uploaded release archives |
| `/srv/apx-dr/map-files.json` | Approved map paths, lengths and SHA-256 hashes |
| `/var/lib/apx-dr` | Runtime home, player profiles and private native logs |
| `/var/lib/apx-dr/deployed.json` | Active revision and built hashes |
| `/usr/local/lib/apx-dr/deploy.py` | Root-owned activation/rollback implementation |
| `/etc/apx-dr` | Private operator configuration and CDN credentials |

## Provisioning and maps

`server/linux/provision-miami.py` documents the one-time Proxmox bootstrap. It
is restricted to the Miami host, verifies the official Debian image, masks
OpenSSH before first boot, creates only the new VM and narrowly scoped game/
Teleport networking. Never rerun it over an existing VM. The cloud-init payload
contains no credentials. The guest is enrolled through the recorded Proxmox
console; long-lived secrets are transferred privately after boot.

`server/linux/bootstrap-server.py` verifies the licensed base-game archive on a
temporary **read-only** virtual disk and the pinned native binary. It validates
and installs the committed public release, preserves existing credentials,
installs the service and guest firewall, and leaves initial activation gated on
map/CDN checks. Never publish the licensed base archive or SDK on the CDN.
`install.sh` also installs the root-owned deployment helper and creates the
separate unprivileged smoke-test home.

Run `server/linux/install-steam-runtime.py` in the recorded guest terminal after
bootstrap to install the two required Steam libraries. It verifies the pinned
container manifest, downloaded layers and both library hashes, and leaves the
custom server executable intact. The source is the container recommended by the
[upstream server README](https://github.com/callofduty4x/CoD4x_Server),
`alexandercurl/cod4x-server` at digest
`sha256:522f90b194ead1bf001b53b770b365f0b7a32f6d1e84f7dac139d27bbd4fc962`.
It does not run the container or install its old system libraries. Provenance is
saved in `/srv/apx-dr/steam-runtime.json`. Restart the service and verify
`Steam: Server connected successfully` in its journal. Detach the temporary
bootstrap disk after the licensed files have been verified on the root disk.

`server/linux/sync-maps.py` reads the approved manifest, verifies SHA-256 hashes,
fetches from the existing CDN or the pinned original source, and repairs missing
CDN objects using the private storage key. Its report is `/srv/apx-dr/map-sync.json`.
Only approved paths are touched. The curated collection currently admits 439
maps; Village and Break exceed the 2,000-material safety target and are excluded.
These are asset/load checks, not certification of every third-party gameplay
trigger. See [CONTENT.md](CONTENT.md) for the native client-zone audit policy.

For a fresh installation, run `server/linux/activate-bootstrap.py` after map sync
and Steam runtime installation. It checks the complete sync report, prepares
rotation, runs the native smoke test, publishes/verifies the public mod files and
starts the service. It refuses to replace an already running server. Later
updates use the manual deployment workflow above.

The public downloads remain at `http://cdn.apx.ethanburkett.dev`, under
`mods/apx_dr/` and `usermaps/`. Keep their contents identical to the game server.
The CoD4x binary, pool patch and corresponding source/license remain described
in [the server guide](../server/README.md).
