#!/bin/bash
set -e

# cd to script dir:
cd "$(dirname "$0")"

# Clean previous build artifacts
rm -rf build
# Build the Xcode project using the Release configuration and custom derived data path
xcodebuild -project clisolarwallpaper.xcodeproj -scheme clisolarwallpaper -configuration Release -derivedDataPath build
# Remove any existing built bundle and copy the new one
rm -rf clisolarwallpaper/clisolarwallpaper.app
mv build/Build/Products/Release/clisolarwallpaper.app ./clisolarwallpaper.app
