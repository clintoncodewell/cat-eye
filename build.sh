#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building GH Actions Bar..."
swiftc -Osize -o GHActionsBar.app/Contents/MacOS/gh-actions-bar main.swift -framework Cocoa -framework UserNotifications
strip GHActionsBar.app/Contents/MacOS/gh-actions-bar
echo "Done. $(ls -lh GHActionsBar.app/Contents/MacOS/gh-actions-bar | awk '{print $5}') binary"
echo "Run with: open GHActionsBar.app"
