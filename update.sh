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
if [ -d /Applications/CatEye.app ]; then
  rsync -a --delete CatEye.app/ /Applications/CatEye.app/
  open /Applications/CatEye.app
else
  open CatEye.app
fi
echo "Cat Eye restarted on $BRANCH @ $(git rev-parse --short HEAD)"
