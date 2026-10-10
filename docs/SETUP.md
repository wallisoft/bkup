# Setting up bkup

## 1. The machine that keeps the backups

Mount the disk (or two) the backups will live on so that it is there at boot, in `/etc/fstab`, not by a desktop
login. Then, as root:

    git clone https://github.com/wallisoft/bkup && cd bkup
    ./install-store.sh NAME SERVER-ADDRESS /mnt/disk1 /mnt/disk2

`NAME` is what to call the server. The script installs restic and rsync, makes a key at
`/root/.ssh/bkup_ed25519`, makes the pass phrase at `/root/.bkup-pass`, writes `/etc/bkup/bkup.conf` and sets
the nightly run at 03:30.

**Copy the pass phrase somewhere that is neither this machine nor the server**: a password manager, or paper.
Lose it and the backups are unreadable.

## 2. The server

As root, with the line the first script printed:

    git clone https://github.com/wallisoft/bkup && cd bkup
    ./install-server.sh 'ssh-ed25519 AAAA… bkup read-only pull'

For a database that wants a password, give the file it is kept in and the name on its line:

    ./install-server.sh 'ssh-ed25519 AAAA…' /etc/myapp/app.env DB_ROOT_PASSWORD

The key is added to root's `authorized_keys` tied to `rrsync -ro /`: it can read, and nothing else. If the
server refuses root over ssh altogether, set `PermitRootLogin forced-commands-only`, which lets in only keys
tied to a command and still gives nobody a root shell.

## 3. The first night

On the backup machine:

    bkup && bkup status

Then prove it: `bkup restore /tmp/look` and read a few files, and open a database copy under
`/tmp/look/var/backups/bkup/`.

## Changing what is backed up

`/etc/bkup/bkup.conf` on the backup machine: `PATHS` (what to pull), `EXCLUDES`, `COPIES` (more disks),
`STICK_LABELS` (the labels of sticks to copy to when one is plugged in), `KEEP` (how many nights).

`/etc/bkup/prepare.conf` on the server: where to look for SQLite files, and a database password if needed.

## Rebuilding a server from a backup

1. Install the same release of the system on the new server.
2. `bkup restore /somewhere` on the backup machine, and copy what is needed across.
3. `var/backups/bkup/system/packages` is the list of packages to put back
   (`dpkg --set-selections < packages && apt-get dselect-upgrade`).
4. `/etc`, `/var/www`, `/usr/local`, `/root`, `/home` go back where they were.
5. Each `var/backups/bkup/mariadb/NAME.sql` is fed to `mariadb`; each file under `var/backups/bkup/sqlite/`
   goes back to the path it is filed under.
6. `var/backups/bkup/system/` says what was enabled, mounted and listening, to check against.
