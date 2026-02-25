#!/bin/bash
set -euo pipefail

APP_NAME="WorkWidget"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "Building ${APP_NAME}..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"

# Ad-hoc sign without entitlements for local dev (entitlements need a real cert)
codesign --force --deep --sign - "${APP_BUNDLE}"

# Remove quarantine attribute so macOS doesn't block the local build
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Install to /Applications for Spotlight discovery
echo "Installing to /Applications..."
rm -rf "/Applications/${APP_BUNDLE}"
cp -R "${APP_BUNDLE}" "/Applications/${APP_BUNDLE}"

echo "Built: ${APP_BUNDLE}"
echo "Installed to: /Applications/${APP_BUNDLE}"
echo "Run with: open /Applications/${APP_BUNDLE}"
