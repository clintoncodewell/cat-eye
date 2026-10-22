#!/bin/bash
# Pull the latest code, rebuild, and relaunch Cat Eye.
# Usage: ./update.sh [branch]   (defaults to the currently checked-out branch)
set -e
cd "$(dirname "$0")"
BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"
./build.sh
pkill -x cat-eye 2>/dev/null || true
sleep 0.5
# The login item launches /Applications/CatEye.app, so refresh that copy too.
# Without this the rebuild lands in the dev tree and the app you actually run
# stays on the old binary — which is how the two drifted apart before.
DEST=/Applications/CatEye.app
# rsync --delete on the wrong target eats an unrelated app, so only write to a
# real directory (not a symlink) that is already our bundle.
if [ -d "$DEST" ] && [ ! -L "$DEST" ] &&
   [ "$(defaults read "$DEST/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "com.clintoncodewell.cateye" ]; then
  rsync -a --delete CatEye.app/ "$DEST/"
  open "$DEST"
else
  open CatEye.app
fi
echo "Cat Eye restarted on $BRANCH @ $(git rev-parse --short HEAD)"

# Guard against a busy loop shipping unnoticed (a redraw loop once held a core
# at 100% for weeks). Skip the launch burst, then measure CPU over 30 seconds.
# The gh helpers are child processes, so only the app's own work counts here.
cputime() { ps -o time= -p "$1" 2>/dev/null | awk -F: 'NF { s = 0; for (i = 1; i <= NF; i++) s = s * 60 + $i; print s }'; }
sleep 10
# Newest instance owned by this user, so a stale or another user's copy isn't measured.
PID=$(pgrep -n -u "$(id -u)" -x cat-eye || true)
if [ -z "$PID" ] || ! ps -o command= -p "$PID" | grep -q 'CatEye.app/Contents/MacOS/cat-eye'; then
  echo "WARNING: Cat Eye is not running 10 seconds after launch." >&2
  exit 1
fi
T0=$(cputime "$PID"); sleep 30; T1=$(cputime "$PID")
if [ -z "$T0" ] || [ -z "$T1" ]; then
  echo "WARNING: Cat Eye quit during the 30-second CPU check." >&2
  exit 1
fi
USED=$(awk -v a="$T0" -v b="$T1" 'BEGIN { printf "%.2f", b - a }')
if awk -v u="$USED" 'BEGIN { exit !(u > 3 || u < 0) }'; then
  echo "WARNING: Cat Eye used ${USED}s of CPU in 30s (over 10%). Something is looping." >&2
  exit 1
fi
echo "CPU check OK: ${USED}s of CPU in 30s"
