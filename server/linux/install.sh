#!/bin/sh
# Install the service after transferring the licensed base game, a built native
# server and a public mod release. Run as root; never put private.cfg on FastDL.
set -eu
game=/srv/apx-dr/game
mod="$game/mods/apx_dr"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test "$(id -u)" = 0 || { echo 'Run with sudo.' >&2; exit 1; }
test -x "$game/apx_cod4x_dedrun"
test -f "$mod/mod.ff"
test -f "$mod/apx_dr.iwd"
test -f "$game/zone/english/common_mp.ff"
id apxdr >/dev/null 2>&1 || useradd --system --home-dir /var/lib/apx-dr --create-home --shell /usr/sbin/nologin apxdr
install -d -o apxdr -g apxdr -m 0750 /var/lib/apx-dr /var/lib/apx-dr/main /var/lib/apx-dr/mods/apx_dr /var/lib/apx-dr/smoke
install -d -o root -g apxdr -m 0750 /etc/apx-dr
if [ ! -e "$game/autoupdate.lock" ]; then
    install -o apxdr -g apxdr -m 0600 /dev/null "$game/autoupdate.lock"
fi
if [ ! -e /etc/apx-dr/private.cfg ]; then
    python3 - <<'PY'
import os,secrets,string
path='/etc/apx-dr/private.cfg'
fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o640)
with os.fdopen(fd,'w') as stream:
    stream.write('// Private operator credentials. Never publish this file.\n')
    stream.write('set rcon_password "'+''.join(secrets.choice(string.ascii_letters+string.digits) for _ in range(12))+'"\n')
    stream.write('set dr_admin_loginpass_0 "hype;'+secrets.token_hex(16)+';bcdefghijklmnopv"\n')
    stream.write('// Set sv_authtoken here after obtaining a valid listing token.\n')
PY
fi
chown root:apxdr /etc/apx-dr/private.cfg
chmod 0640 /etc/apx-dr/private.cfg
if [ -e "$mod/config/private.cfg" ] || [ -L "$mod/config/private.cfg" ]; then
    test "$(readlink "$mod/config/private.cfg")" = /etc/apx-dr/private.cfg || {
        echo 'Existing private.cfg is not the managed symlink; preserve it and resolve manually.' >&2; exit 1;
    }
else
    ln -s /etc/apx-dr/private.cfg "$mod/config/private.cfg"
fi
printf '%s\n' '// Public server: managed test clients disabled.' 'set g_bots 0' > "$mod/config/deathrun/testing.cfg"
cat > "$mod/config/server/downloads.cfg" <<'CFG'
// Only public mod and usermap files are published to this CDN.
set sv_allowdownload 1
set sv_wwwDownload 1
set sv_wwwBaseURL "http://cdn.apx.ethanburkett.dev"
set sv_wwwDlDisconnected 0
CFG
install -m 0644 "$here/apx-dr.service" /etc/systemd/system/apx-dr.service
install -d -o root -g root -m 0750 /usr/local/lib/apx-dr /srv/apx-dr/incoming
install -o root -g root -m 0750 "$here/deploy.py" /usr/local/lib/apx-dr/deploy.py
printf '%s\n' '#!/bin/sh' 'exec /usr/bin/python3 /usr/local/lib/apx-dr/deploy.py "$@"' > /usr/local/sbin/apx-deploy
chmod 0750 /usr/local/sbin/apx-deploy
systemctl daemon-reload
systemctl enable apx-dr.service
echo 'Service installed. Start with: sudo systemctl start apx-dr'
