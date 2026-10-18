#!/bin/sh
# Operator bootstrap only. Run through a trusted SSH session as root.
# Usage: setup-ci.sh jump|server /path/to/deploy-key.pub
set -eu
test "$(id -u)" = 0 || { echo 'Run as root.' >&2; exit 1; }
role=${1:-}
keyfile=${2:-}
test -f "$keyfile" || { echo 'Supply the public Ed25519 CI key file.' >&2; exit 1; }
grep -Eq '^ssh-ed25519 [A-Za-z0-9+/=]+( .*)?$' "$keyfile" || { echo 'Invalid public key.' >&2; exit 1; }
case "$role" in
    jump)
        id apx-ci >/dev/null 2>&1 || useradd --system --create-home --home-dir /var/lib/apx-ci --shell /bin/false apx-ci
        install -d -o root -g root -m 0755 /var/lib/apx-ci /var/lib/apx-ci/.ssh
        printf 'restrict,port-forwarding,permitopen="10.50.0.10:22",command="/bin/false" %s\n' "$(cat "$keyfile")" > /var/lib/apx-ci/.ssh/authorized_keys
        chmod 0644 /var/lib/apx-ci/.ssh/authorized_keys
        ;;
    server)
        here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
        id apxdeploy >/dev/null 2>&1 || useradd --create-home --shell /bin/bash apxdeploy
        install -d -o root -g apxdeploy -m 0750 /home/apxdeploy /home/apxdeploy/.ssh
        printf 'restrict %s\n' "$(cat "$keyfile")" > /home/apxdeploy/.ssh/authorized_keys
        chown root:apxdeploy /home/apxdeploy/.ssh/authorized_keys
        chmod 0640 /home/apxdeploy/.ssh/authorized_keys
        install -d -o apxdeploy -g apxdeploy -m 0750 /srv/apx-dr/incoming
        install -d -o root -g apxdeploy -m 0750 /srv/apx-dr/sdk
        install -d -o root -g root -m 0755 /usr/local/lib/apx-dr
        install -o root -g root -m 0755 "$here/deploy.py" /usr/local/lib/apx-dr/deploy.py
        printf '#!/bin/sh\nexec /usr/bin/python3 /usr/local/lib/apx-dr/deploy.py "$@"\n' > /usr/local/sbin/apx-deploy
        chmod 0755 /usr/local/sbin/apx-deploy
        printf 'apxdeploy ALL=(root) NOPASSWD: /usr/local/sbin/apx-deploy *\n' > /etc/sudoers.d/apx-deploy
        chmod 0440 /etc/sudoers.d/apx-deploy
        visudo -cf /etc/sudoers.d/apx-deploy
        ;;
    *) echo 'Usage: setup-ci.sh jump|server /path/to/deploy-key.pub' >&2; exit 1 ;;
esac
echo "Installed restricted CI identity for $role."
