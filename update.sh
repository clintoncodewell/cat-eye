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
open CatEye.app
echo "Cat Eye restarted on $BRANCH @ $(git rev-parse --short HEAD)"
