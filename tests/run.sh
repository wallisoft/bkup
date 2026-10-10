#!/bin/bash
# The whole thing end to end, on one machine and in a temporary folder: a pretend server with files and
# databases, prepared, pulled, stored, copied, changed, backed up again and restored. Needs root (as bkup does),
# rsync, sqlite3 and restic.   sudo tests/run.sh
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "PASS  $1"; else fail=$((fail + 1)); echo "FAIL  $1: got '$2', wanted '$3'"; fi; }

srv="$T/server"
mkdir -p "$srv/etc/nginx" "$srv/var/www/site/data" "$srv/var/www/site/.cache" "$srv/root" "$T/disk1" "$T/disk2" "$T/etc"
echo "server { listen 80; }" > "$srv/etc/nginx/site.conf"
echo "<h1>hello</h1>" > "$srv/var/www/site/index.html"
echo "junk" > "$srv/var/www/site/.cache/x"
sqlite3 "$srv/var/www/site/data/shop.db" "create table orders(id integer primary key, what text); insert into orders(what) values('tea'),('biscuits');"
sqlite3 "$srv/var/www/site/data/live.db" "pragma journal_mode=wal; create table t(n); insert into t values(1);" >/dev/null
echo "not a database" > "$srv/var/www/site/data/fake.db"

cat > "$T/etc/prepare.conf" <<CONF
OUT="$srv/var/backups/bkup"
SQLITE_ROOTS="$srv/var/www"
SQLITE_SKIP="$srv/var/backups/bkup"
CONF
cat > "$T/etc/bkup.conf" <<CONF
NAME=pretend
SOURCE="$srv/."
PATHS="/etc /var/www /root /var/backups/bkup"
STAGE="$T/state/stage"
STATE="$T/state"
REPO="$T/disk1/restic"
REPO_DISK=/
COPIES="/:$T/disk2/restic"
PASSFILE="$T/etc/pass"
KEEP="--keep-last 100"
CONF
echo "a pass phrase for the test only" > "$T/etc/pass"
export BKUP_PREPARE_CONF="$T/etc/prepare.conf" BKUP_CONF="$T/etc/bkup.conf"
prepare="$here/bin/bkup-prepare"; bkup="$here/bin/bkup"
field() { grep -o "\"$1\": [^,]*" "$T/state/status.json" | head -1 | cut -d' ' -f2- | tr -d '"'; }
stepof() { grep "\"step\": \"$1\"" "$T/state/status.json" | grep -o '"result": "[a-z]*"' | cut -d'"' -f4; }

check "before the server has prepared, the backup still runs but says so" "$("$bkup" >/dev/null 2>&1; echo $?; stepof databases)" "1
problem"

"$prepare" > "$T/prepare.log" 2>&1
check "prepare: finishes without problems" "$?" "0"
check "prepare: a SQLite database is copied whole" "$(sqlite3 "$srv/var/backups/bkup/sqlite$srv/var/www/site/data/shop.db" 'select count(*) from orders')" "2"
check "prepare: one in use (with a -wal file) is copied with its newest rows" "$(sqlite3 "$srv/var/backups/bkup/sqlite$srv/var/www/site/data/live.db" 'select count(*) from t')" "1"
check "prepare: a file only named like a database is left out" "$([ -e "$srv/var/backups/bkup/sqlite$srv/var/www/site/data/fake.db" ] && echo copied || echo no)" "no"
check "prepare: notes how the machine is set up" "$([ -s "$srv/var/backups/bkup/system/packages" ] && [ -s "$srv/var/backups/bkup/system/kernel" ] && echo yes)" "yes"
check "prepare: says when it ran and that nothing went wrong" "$(grep -c -E '^(finished_epoch=[0-9]+|problems=0)$' "$srv/var/backups/bkup/STATUS")" "2"
"$prepare" > "$T/prepare2.log" 2>&1
check "prepare: a second run copies only what changed" "$(grep -o 'SQLite: .*' "$T/prepare2.log")" "SQLite: 0 copied, 2 unchanged"

"$bkup" > "$T/run1.log" 2>&1
check "bkup: the first night runs clean" "$?" "0"
check "bkup: status says ok, with every step ok" "$(field ok) $(grep -c '"result": "ok"' "$T/state/status.json") $(grep -c '"result": "problem"' "$T/state/status.json")" "true 5 0"
check "bkup: the files are pulled, with what was excluded left behind" "$([ -e "$T/state/stage/etc/nginx/site.conf" ] && [ ! -e "$T/state/stage/var/www/site/.cache" ] && echo yes)" "yes"
check "bkup: the store is encrypted (the page's text is nowhere in it)" "$(grep -rl 'hello' "$T/disk1/restic" | wc -l)" "0"
check "bkup: the nights so far are in the store, and in the copy" "$("$bkup" snapshots 2>/dev/null | grep -c pretend) $(restic --password-file "$T/etc/pass" -r "$T/disk2/restic" snapshots 2>/dev/null | grep -c pretend)" "2 2"

echo "<h1>changed</h1>" > "$srv/var/www/site/index.html"
sqlite3 "$srv/var/www/site/data/shop.db" "insert into orders(what) values('cake');"
rm "$srv/etc/nginx/site.conf"
"$prepare" >/dev/null 2>&1; "$bkup" > "$T/run2.log" 2>&1
check "bkup: another night after changes runs clean, and adds one" "$? $("$bkup" snapshots 2>/dev/null | grep -c pretend)" "0 3"

"$bkup" restore "$T/back" >/dev/null 2>&1
check "restore: the newest night has the changed page and the new order" "$(cat "$T/back/var/www/site/index.html") $(sqlite3 "$T/back/var/backups/bkup/sqlite$srv/var/www/site/data/shop.db" 'select count(*) from orders')" "<h1>changed</h1> 3"
first=$("$bkup" snapshots 2>/dev/null | awk '/pretend/{n++; if (n == 2) print $1}')
"$bkup" restore "$T/back1" "$first" >/dev/null 2>&1
check "restore: an earlier night still has the file deleted since, and the page as it was" "$(cat "$T/back1/etc/nginx/site.conf") $(cat "$T/back1/var/www/site/index.html")" "server { listen 80; } <h1>hello</h1>"
restic --password-file "$T/etc/pass" -r "$T/disk2/restic" restore latest --target "$T/back2" >/dev/null 2>&1
check "restore: the copy on the second disk restores by itself" "$(cat "$T/back2/var/www/site/index.html")" "<h1>changed</h1>"
check "check: the store reads back sound" "$("$bkup" check >/dev/null 2>&1; echo $?)" "0"

sed -i "s|^REPO_DISK=.*|REPO_DISK=$T/not-a-disk|" "$T/etc/bkup.conf"; mkdir -p "$T/not-a-disk"
"$bkup" > "$T/run3.log" 2>&1
check "a store whose disk is not mounted: nothing is written, and it says why" "$? $(stepof store)" "1 problem"
sed -i "s|^REPO_DISK=.*|REPO_DISK=/|; s|^SOURCE=.*|SOURCE=\"nobody@no-such-server.invalid:\"|" "$T/etc/bkup.conf"
"$bkup" > "$T/run4.log" 2>&1
check "a server that can't be reached: no new night is made of a failed pull" "$? $(stepof pull) $("$bkup" snapshots 2>/dev/null | grep -c pretend)" "1 problem 3"
sed -i "s|^SOURCE=.*|SOURCE=\"$srv/.\"|; s|^PATHS=.*|PATHS=\"/etc /var/www /root /var/backups/bkup /not/there\"|" "$T/etc/bkup.conf"
"$bkup" > "$T/run4b.log" 2>&1
check "a folder asked for that isn't on the server: the rest is backed up, and it is reported" "$? $(stepof pull) $(stepof backup)" "1 problem ok"
sed -i "s|^PATHS=.*|PATHS=\"/etc /var/www /root /var/backups/bkup\"|" "$T/etc/bkup.conf"
sed -i "s|^SOURCE=.*|SOURCE=\"$srv/.\"|" "$T/etc/bkup.conf"
sed -i "s/^finished_epoch=.*/finished_epoch=$(( $(date +%s) - 40 * 3600 ))/" "$srv/var/backups/bkup/STATUS"
"$bkup" > "$T/run5.log" 2>&1
check "databases prepared too long ago: backed up anyway, but reported as a problem" "$? $(stepof databases) $(stepof backup)" "1 problem ok"
check "status is JSON a program can read" "$(python3 -c "import json,sys; d=json.load(open('$T/state/status.json')); print(d['name'], d['ok'], len(d['steps'])>3)")" "pretend False True"

echo; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
