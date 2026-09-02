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
