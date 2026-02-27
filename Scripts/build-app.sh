#!/bin/bash
set -euo pipefail

APP_NAME="WorkWidget"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
ENTITLEMENTS="Resources/WorkWidget.entitlements"

resolve_sign_identity() {
    if [ -n "${SIGN_IDENTITY:-}" ]; then
        echo "${SIGN_IDENTITY}"
        return
    fi

    local auto_identity
    auto_identity=$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Apple Development[^\"]*\)"/\1/p' \
        | head -n 1)

    if [ -n "${auto_identity}" ]; then
        echo "${auto_identity}"
        return
    fi

    # Fallback for environments without a configured signing identity.
    echo "-"
}

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

# Copy .env if it exists
if [ -f ".env" ]; then
    cp ".env" "${RESOURCES}/.env"
    echo "Bundled .env into Resources"
fi

SIGNING_IDENTITY="$(resolve_sign_identity)"
if [ "${SIGNING_IDENTITY}" = "-" ]; then
    echo "⚠️  No Apple Development identity found. Falling back to ad-hoc signing."
    echo "⚠️  Keychain 'Always Allow' prompts may reappear across rebuilds."
else
    echo "Using signing identity: ${SIGNING_IDENTITY}"
fi

if [ -f "${ENTITLEMENTS}" ]; then
    codesign --force --deep --options runtime --entitlements "${ENTITLEMENTS}" --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
else
    codesign --force --deep --options runtime --sign "${SIGNING_IDENTITY}" "${APP_BUNDLE}"
fi

# Remove quarantine attribute so macOS doesn't block the local build
xattr -cr "${APP_BUNDLE}" 2>/dev/null || true

# Install to /Applications for Spotlight discovery
echo "Installing to /Applications..."
rm -rf "/Applications/${APP_BUNDLE}"
cp -R "${APP_BUNDLE}" "/Applications/${APP_BUNDLE}"

echo "Built: ${APP_BUNDLE}"
echo "Installed to: /Applications/${APP_BUNDLE}"
echo "Run with: open /Applications/${APP_BUNDLE}"
