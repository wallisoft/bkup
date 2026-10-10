# bkup

Nightly, encrypted, pull-based backups of a Linux server, kept on a machine of your own, with copies on a
second disk and on a stick you can take away.

Two small shell scripts around tools that have earned their trust: `rsync` to fetch, `restic` to store.

```
   the server                         the machine that keeps the backups
  ┌────────────────────┐   rsync    ┌────────────────────────────────────────────┐
  │ bkup-prepare 02:30 │  over ssh  │ bkup 03:30                                 │
  │  safe copies of    │ ─────────▶ │  pull ─▶ encrypted store on disk 1         │
  │  every database    │ read-only  │              ├─▶ copy on disk 2            │
  └────────────────────┘            │              └─▶ copy on a stick, if in    │
                                    └────────────────────────────────────────────┘
```

## Why it is built this way

- **The backups are pulled, not pushed.** The server holds no key to the place its backups live, so someone
  who breaks into the server cannot reach, change or delete them. The key that does the pulling is tied on the
  server to one thing, reading files with rsync: it cannot run a command or write a byte.
- **Databases are copied properly.** Copying a database's files while it runs gives a broken copy some of the
  time. `bkup-prepare` dumps each MariaDB/MySQL database in one transaction and copies each SQLite file through
  SQLite's own backup, into `/var/backups/bkup`, and notes how the machine is set up (packages, services, cron
  jobs, disks) for the day it has to be rebuilt.
- **Everything is encrypted before it is kept.** A real backup of a server holds its passwords and its
  customers' data. The store can sit on a stick in a glovebox and give nothing away.
- **Every night is a full picture, and only what changed takes room.** Fourteen days, eight weeks and twelve
  months are kept by default.
- **Each copy is a store of its own.** Damage to one is not copied onto the others.
- **Nothing is written unless the backup disk is really there.** A disk that didn't mount does not quietly
  fill the system disk.
- **It says what happened.** `/var/lib/bkup/status.json` after every run, for a person or a program.

## Setting up

On the machine that keeps the backups (as root, in a copy of this repository):

    ./install-store.sh NAME SERVER-ADDRESS STORE-DISK [SECOND-DISK]

It prints one line to run on the server:

    ./install-server.sh 'ssh-ed25519 AAAA… bkup read-only pull' [PASSWORD-FILE PASSWORD-NAME]

Then, back on the backup machine:

    bkup            # the first night (it will run by itself after this, at 03:30)
    bkup status

**Keep a copy of `/root/.bkup-pass` somewhere else.** It is the one secret: without it nobody can read the
backups, you included. More in [docs/SETUP.md](docs/SETUP.md).

## Using it

    bkup status            what happened last night
    bkup snapshots         the nights that are kept
    bkup restore DIR       put the newest night's files in DIR
    bkup restore DIR ID    …or another night's
    bkup check             read back part of the store to prove it is sound

A backup you have never restored from is a hope, not a backup. Restore into a spare folder (or a spare machine)
when you set this up, and now and then after.

## What it does not do (yet)

- It backs up one server per backup machine config. More servers means more configs, by hand.
- It does not back up containers or virtual machines as such, only the files in the paths you give it.
- It does not send an alert when a night fails: read `bkup status`, or have something read `status.json`.
- There is no copy to a cloud store built in, though restic can do that, and a copy step would be small.

## Needs

Debian or Ubuntu on both machines (it uses `apt`, `rrsync` and cron), root on both, and ssh from the backup
machine to the server. `tests/run.sh` runs the whole thing end to end in a temporary folder.

## Licence

MIT. Made by Steve at Wallisoft with Claude (Anthropic).
