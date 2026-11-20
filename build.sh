#!/bin/zsh
set -eu
cd "${0:A:h}"
app="../徽光.app"
temp=$(mktemp -d)
trap 'rm -r "$temp"' EXIT
mkdir -p "$app/Contents/MacOS"
clang -mmacosx-version-min=13.0 -fobjc-arc -c Lamp.m -o "$temp/Lamp.o"
swiftc -target arm64-apple-macos13.0 -module-cache-path "$temp/cache" -import-objc-header Lamp.h main.swift "$temp/Lamp.o" -o "$app/Contents/MacOS/LogoLight"
mkdir -p "$app/Contents/Resources"
cp Glow.icns "$app/Contents/Resources/"
cp Info.plist "$app/Contents/"
xattr -cr "$app"
codesign --force --sign - "$app"
