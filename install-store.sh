#!/bin/bash
# Set up the machine that KEEPS the backups. Run as root, from a copy of this repository:
#
#   sudo ./install-store.sh NAME SERVER-ADDRESS STORE-DISK [SECOND-DISK]
#   sudo ./install-store.sh web1 203.0.113.10 /mnt/disk1 /mnt/disk2
#
# It installs restic and rsync, puts bkup in /usr/local/sbin, makes a key that can only READ the server, makes
# the pass phrase that locks the store, writes /etc/bkup/bkup.conf and sets the nightly run. Then it prints
# the one line to run on the server. Nothing here needs the server yet.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run this as root (sudo)"; exit 1; }
[ $# -ge 3 ] || { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
name=$1; address=$2; disk=$3; second=${4:-}
[ "$disk" = / ] || disk=${disk%/}
[ -z "$second" ] || [ "$second" = / ] || second=${second%/}
here=$(cd "$(dirname "$0")" && pwd)
mountpoint -q "$disk" || { echo "$disk is not a mounted disk"; exit 1; }
[ -z "$second" ] || mountpoint -q "$second" || { echo "$second is not a mounted disk"; exit 1; }

export DEBIAN_FRONTEND=noninteractive
command -v restic >/dev/null && command -v rsync >/dev/null || apt-get install -y -q restic rsync >/dev/null
install -m 755 "$here/bin/bkup" /usr/local/sbin/bkup
mkdir -p /etc/bkup /var/lib/bkup /root/.ssh; chmod 700 /root/.ssh /var/lib/bkup

key=/root/.ssh/bkup_ed25519
[ -e "$key" ] || ssh-keygen -q -t ed25519 -N "" -C "bkup read-only pull from $(hostname)" -f "$key"
if ! grep -q "^Host bkup-source$" /root/.ssh/config 2>/dev/null; then
    printf '\nHost bkup-source\n    HostName %s\n    User root\n    IdentityFile %s\n    IdentitiesOnly yes\n    StrictHostKeyChecking accept-new\n' "$address" "$key" >> /root/.ssh/config
    chmod 600 /root/.ssh/config
fi

pass=/root/.bkup-pass
if [ ! -e "$pass" ]; then
    ( umask 077; head -c 33 /dev/urandom | base64 | tr -d '\n' > "$pass"; echo >> "$pass" )
    newpass=1
fi

conf=/etc/bkup/bkup.conf
if [ ! -e "$conf" ]; then
    {
        echo "NAME=$name"
        echo 'SOURCE="bkup-source:"'
        echo 'PATHS="/etc /root /home /usr/local /var/www /var/spool/cron /var/backups/bkup /opt"'
        echo 'EXCLUDES=".cache/ node_modules/ *.sock lost+found/"'
        echo "REPO=$disk/bkup/restic"
        echo "REPO_DISK=$disk"
        [ -z "$second" ] || echo "COPIES=\"$second:$second/bkup/restic\""
        echo 'STICK_LABELS=""'
        echo "PASSFILE=$pass"
        echo 'KEEP="--keep-daily 14 --keep-weekly 8 --keep-monthly 12"'
    } > "$conf"
    chmod 600 "$conf"
fi
printf 'SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n# every night at half past three, an hour after the server prepares\n30 3 * * * root /usr/local/sbin/bkup >/dev/null 2>&1\n' > /etc/cron.d/bkup

echo
echo "This machine is ready to keep backups of $name in $disk/bkup/restic."
[ -z "${newpass:-}" ] || cat <<MSG

IMPORTANT: the pass phrase that locks the store is in $pass
Without it the backups cannot be read by anyone, you included. Copy it now to somewhere that is
not this machine and not the server: a password manager, or paper in a drawer.   sudo cat $pass
MSG
cat <<MSG

Next, on the server ($address), as root, from a copy of this repository:

  ./install-server.sh '$(cat "$key.pub")'

Then back here:   sudo bkup && sudo bkup status
MSG
