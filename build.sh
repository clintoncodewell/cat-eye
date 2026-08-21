#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Building Cat Eye..."
mkdir -p CatEye.app/Contents/MacOS
swiftc -Osize -o CatEye.app/Contents/MacOS/cat-eye main.swift -framework Cocoa -framework UserNotifications
strip CatEye.app/Contents/MacOS/cat-eye
codesign --force --deep --sign - --timestamp=none CatEye.app
codesign --verify --deep --strict CatEye.app
echo "Done. $(ls -lh CatEye.app/Contents/MacOS/cat-eye | awk '{print $5}') binary"
echo "Run with: open CatEye.app"
