#!/bin/bash
# Set up the SERVER being backed up. Run as root, from a copy of this repository:
#
#   ./install-server.sh 'PUBLIC-KEY-LINE' [PASSWORD-FILE PASSWORD-NAME]
#
# PUBLIC-KEY-LINE is what install-store.sh printed on the machine that keeps the backups. That key is let in as
# root but tied to one thing: reading files with rsync. It cannot run commands, and cannot change or delete.
# PASSWORD-FILE and PASSWORD-NAME are for a database that wants a password (a file with a line NAME=password).
#
# It installs sqlite3 and rsync, puts bkup-prepare in /usr/local/sbin, sets it to run nightly, and runs it once.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run this as root (sudo)"; exit 1; }
[ $# -ge 1 ] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
pub=$1; passfile=${2:-}; passname=${3:-}
here=$(cd "$(dirname "$0")" && pwd)
case "$pub" in ssh-ed25519\ *|ssh-rsa\ *|ecdsa-*) ;; *) echo "that doesn't look like a public key line"; exit 1 ;; esac

export DEBIAN_FRONTEND=noninteractive
command -v sqlite3 >/dev/null && command -v rsync >/dev/null && [ -x /usr/bin/rrsync ] || apt-get install -y -q sqlite3 rsync python3 >/dev/null
[ -x /usr/bin/rrsync ] || { echo "rrsync is missing (it comes with rsync on Debian and Ubuntu)"; exit 1; }
install -m 755 "$here/bin/bkup-prepare" /usr/local/sbin/bkup-prepare
mkdir -p /etc/bkup /root/.ssh /var/backups/bkup; chmod 700 /root/.ssh /var/backups/bkup

if [ ! -e /etc/bkup/prepare.conf ]; then
    { [ -z "$passfile" ] || { echo "DB_PASSWORD_FILE=$passfile"; echo "DB_PASSWORD_NAME=$passname"; }; } > /etc/bkup/prepare.conf
    chmod 600 /etc/bkup/prepare.conf
fi

auth=/root/.ssh/authorized_keys
touch "$auth"; chmod 600 "$auth"
body=$(echo "$pub" | awk '{print $2}')
grep -qF "$body" "$auth" || echo "command=\"/usr/bin/rrsync -ro /\",restrict $pub" >> "$auth"

printf 'SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n# every night at half past two, an hour before the backup is pulled\n30 2 * * * root /usr/local/sbin/bkup-prepare >/var/log/bkup-prepare.log 2>&1\n' > /etc/cron.d/bkup-prepare

root=$(sshd -T 2>/dev/null | awk '$1=="permitrootlogin"{print $2}')
case "$root" in
    no) echo "NOTE: this server refuses root over ssh altogether (PermitRootLogin no), so the pull will be refused."
        echo "      Set  PermitRootLogin forced-commands-only  in /etc/ssh/sshd_config and reload ssh: that lets in"
        echo "      only keys tied to one command, like this one, and still no root shell for anyone." ;;
    *)  echo "root over ssh here is: ${root:-unknown} (the backup key is tied to read-only rsync either way)" ;;
esac

echo "Preparing once now..."
/usr/local/sbin/bkup-prepare || true
echo
echo "The server is ready. On the machine that keeps the backups:   sudo bkup && sudo bkup status"
