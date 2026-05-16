#!/bin/bash
# Rebuild and restart zerocmux app

set -e

cd "$(dirname "$0")/.."

# Kill existing app if running
pkill -9 -f "zerocmux|cmux" 2>/dev/null || true

# Build
swift build

# Copy to app bundle. Keep cmux.app as a legacy SwiftPM fallback if it exists.
APP_BUNDLE=".build/debug/zerocmux.app"
APP_BINARY_NAME="zerocmux"
if [ ! -d "$APP_BUNDLE" ] && [ -d ".build/debug/cmux.app" ]; then
  APP_BUNDLE=".build/debug/cmux.app"
  APP_BINARY_NAME="cmux"
fi
cp .build/debug/cmux "$APP_BUNDLE/Contents/MacOS/$APP_BINARY_NAME"

# Open the app
open "$APP_BUNDLE"
