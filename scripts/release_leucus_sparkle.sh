#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 0.0.5"
  exit 1
fi

VERSION="$1"
TAG="v${VERSION}"
OWNER="${LEUCUS_GITHUB_OWNER:-linhay}"
REPO="${LEUCUS_GITHUB_REPO:-Leucus}"
KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-$HOME/.config/leucus/sparkle_private_key.txt}"
WORKDIR="/tmp/leucus-release-${VERSION}"
ARCHIVES_DIR="${WORKDIR}/archives"

if [[ ! -f "${KEY_FILE}" ]]; then
  echo "Missing Sparkle private key file: ${KEY_FILE}"
  echo "Set SPARKLE_PRIVATE_KEY_FILE or generate/export key first."
  exit 1
fi

APPCAST_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type f -path '*SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' | grep 'Leucus-' | head -n 1 || true)"
if [[ -z "${APPCAST_BIN}" ]]; then
  echo "generate_appcast not found in DerivedData. Build once in Xcode first."
  exit 1
fi

rm -rf "${WORKDIR}"
mkdir -p "${ARCHIVES_DIR}"

echo "[1/5] Build Release app"
xcodebuild \
  -project Example/Leucus.xcodeproj \
  -scheme Leucus \
  -configuration Release \
  -destination 'platform=macOS' \
  build >/tmp/leucus-release-build-${VERSION}.log

APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*Build/Products/Release/Leucus.app' | grep -v 'Index.noindex' | head -n 1)"
cp -R "${APP_PATH}" "${WORKDIR}/Leucus.app"

echo "[2/5] Package zip"
(
  cd "${WORKDIR}"
  ditto -c -k --sequesterRsrc --keepParent Leucus.app "Leucus-${VERSION}.zip"
)
cp "${WORKDIR}/Leucus-${VERSION}.zip" "${ARCHIVES_DIR}/Leucus-${VERSION}.zip"

echo "[3/5] Prepare existing appcast context"
curl -fsSL "https://${OWNER}.github.io/${REPO}/appcast.xml" -o "${ARCHIVES_DIR}/appcast.xml" || true

echo "[4/5] Generate signed appcast"
"${APPCAST_BIN}" \
  --ed-key-file "${KEY_FILE}" \
  --download-url-prefix "https://github.com/${OWNER}/${REPO}/releases/download/${TAG}/" \
  --link "https://github.com/${OWNER}/${REPO}" \
  "${ARCHIVES_DIR}"

echo "[5/5] Publish release assets"
if gh release view "${TAG}" >/dev/null 2>&1; then
  gh release upload "${TAG}" "${ARCHIVES_DIR}/Leucus-${VERSION}.zip" "${ARCHIVES_DIR}/appcast.xml" --clobber
else
  gh release create "${TAG}" \
    "${ARCHIVES_DIR}/Leucus-${VERSION}.zip" \
    "${ARCHIVES_DIR}/appcast.xml" \
    --title "Leucus ${VERSION}" \
    --notes "Signed Sparkle release ${VERSION}."
fi

echo "Release published: https://github.com/${OWNER}/${REPO}/releases/tag/${TAG}"
