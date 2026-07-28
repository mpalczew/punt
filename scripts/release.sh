#!/bin/bash
# Local release: build universal, sign, notarize, GitHub release, Homebrew cask.
# Usage: scripts/release.sh X.Y.Z
#
# Notarization credentials (either):
#   NOTARY_PROFILE          keychain profile from `xcrun notarytool store-credentials`
#   or all three of:
#   NOTARIZE_APPLE_ID
#   NOTARIZE_PASSWORD       app-specific password
#   NOTARIZE_TEAM_ID
#
# Optional:
#   SIGNING_IDENTITY        codesign identity (default: Makefile default)
#   HOMEBREW_TAP_REPO       default: mpalczew/homebrew-punt
#   SKIP_HOMEBREW=1         skip tap update
#   SKIP_PUSH=1             build/sign/zip only; no commit/tag/push/release

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: scripts/release.sh X.Y.Z"
  exit 1
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: version must be semver (e.g. 1.0.0)"
  exit 1
fi

APP_NAME="Punt"
BUILD_DIR=".build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ZIP_NAME="$APP_NAME-$VERSION-universal.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
HOMEBREW_TAP_REPO="${HOMEBREW_TAP_REPO:-mpalczew/homebrew-punt}"
TAG="v$VERSION"

die() { echo "Error: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# --- preflight ---

require_cmd git
require_cmd make
require_cmd gh
require_cmd codesign
require_cmd ditto
require_cmd shasum
[ -x /usr/libexec/PlistBuddy ] || die "missing /usr/libexec/PlistBuddy"

if [ -n "$(git status --porcelain)" ]; then
  die "working tree is dirty. Commit or stash changes first."
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  die "tag $TAG already exists"
fi

# Signing identity must exist in keychain
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Michal Palczewski (FS3CWH8867)}"
if ! security find-identity -v -p codesigning | grep -F "$SIGNING_IDENTITY" >/dev/null; then
  die "codesigning identity not found in keychain: $SIGNING_IDENTITY"
fi

# Notary: keychain profile or env triple
NOTARY_ARGS=()
if [ -n "${NOTARY_PROFILE:-}" ]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [ -n "${NOTARIZE_APPLE_ID:-}" ] && [ -n "${NOTARIZE_PASSWORD:-}" ] && [ -n "${NOTARIZE_TEAM_ID:-}" ]; then
  NOTARY_ARGS=(
    --apple-id "$NOTARIZE_APPLE_ID"
    --password "$NOTARIZE_PASSWORD"
    --team-id "$NOTARIZE_TEAM_ID"
  )
else
  cat >&2 <<'EOF'
Error: notarization credentials not configured.

Store a keychain profile (recommended):
  xcrun notarytool store-credentials punt-notary \
    --apple-id YOU@example.com \
    --team-id FS3CWH8867 \
    --password app-specific-password
  export NOTARY_PROFILE=punt-notary

Or export for this shell:
  NOTARIZE_APPLE_ID  NOTARIZE_PASSWORD  NOTARIZE_TEAM_ID
EOF
  exit 1
fi

if [ "${SKIP_PUSH:-}" != "1" ]; then
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated (run: gh auth login)"
fi

# --- changelog ---

DATE=$(date +%Y-%m-%d)
HEADER="## [$VERSION] - $DATE"

if grep -qE "^## \[$VERSION\]" CHANGELOG.md; then
  die "CHANGELOG.md already has a section for $VERSION"
fi

# Insert new version header after the changelog preamble (before first ## [)
if grep -qE '^## \[' CHANGELOG.md; then
  sed -i '' "/^## \[/i\\
\\
$HEADER\\
\\
### Changed\\
- TODO: fill in changes\\
" CHANGELOG.md
else
  printf '\n%s\n\n### Changed\n- TODO: fill in changes\n' "$HEADER" >> CHANGELOG.md
fi

echo "Opening CHANGELOG.md for editing..."
${EDITOR:-vi} CHANGELOG.md

if grep -q 'TODO: fill in changes' CHANGELOG.md; then
  die "CHANGELOG.md still contains 'TODO: fill in changes'. Fill it in and re-run."
fi

echo ""
echo "CHANGELOG.md (head):"
head -25 CHANGELOG.md
echo ""

# --- version + build ---

echo "Setting Info.plist version to $VERSION..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Resources/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Resources/Info.plist

echo "Building universal binary..."
make build-universal

echo "Signing..."
make sign SIGNING_IDENTITY="$SIGNING_IDENTITY"

echo "Notarizing (this can take several minutes)..."
NOTARIZE_ZIP="$BUILD_DIR/Punt-notarize.zip"
rm -f "$NOTARIZE_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARIZE_ZIP"
xcrun notarytool submit "$NOTARIZE_ZIP" "${NOTARY_ARGS[@]}" --wait
rm -f "$NOTARIZE_ZIP"

echo "Stapling..."
xcrun stapler staple "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --verbose=2 "$APP_BUNDLE"
spctl --assess --type exec --verbose=2 "$APP_BUNDLE" || {
  echo "Warning: spctl assess failed (common before first Gatekeeper cache); codesign verify passed."
}

echo "Creating release zip..."
rm -f "$ZIP_PATH"
(cd "$BUILD_DIR" && zip -r -y "$ZIP_NAME" "$APP_NAME.app")
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
echo "Zip: $ZIP_PATH"
echo "SHA256: $SHA256"

# Keep in-repo cask in sync (tap is the install source)
if [ -f Casks/punt.rb ]; then
  sed -i '' "s/version \".*\"/version \"$VERSION\"/" Casks/punt.rb
  if grep -q 'sha256 :no_check' Casks/punt.rb; then
    sed -i '' "s/sha256 :no_check/sha256 \"$SHA256\"/" Casks/punt.rb
  else
    sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" Casks/punt.rb
  fi
fi

if [ "${SKIP_PUSH:-}" = "1" ]; then
  echo ""
  echo "SKIP_PUSH=1: left versioned artifacts uncommitted."
  echo "Zip ready at $ZIP_PATH"
  exit 0
fi

echo ""
read -p "Commit, tag $TAG, push, create GitHub release, update Homebrew? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted (artifacts left in $BUILD_DIR; working tree has version bumps)."
  exit 1
fi

git add CHANGELOG.md Resources/Info.plist
[ -f Casks/punt.rb ] && git add Casks/punt.rb
git commit -m "Release $TAG"

git tag "$TAG"
git push origin main
git push origin "$TAG"

echo "Creating GitHub release..."
gh release create "$TAG" "$ZIP_PATH" \
  --title "Punt $TAG" \
  --notes "## Installation

**Homebrew:**
\`\`\`
brew tap mpalczew/punt
brew install --cask punt
\`\`\`

**Manual:**
1. Download \`$ZIP_NAME\` below
2. Unzip and drag \`Punt.app\` to your Applications folder
3. Launch Punt

See [CHANGELOG.md](https://github.com/mpalczew/punt/blob/main/CHANGELOG.md) for details."

if [ "${SKIP_HOMEBREW:-}" != "1" ]; then
  echo "Updating Homebrew tap ($HOMEBREW_TAP_REPO)..."
  TAP_DIR=$(mktemp -d)
  trap 'rm -rf "$TAP_DIR"' EXIT
  gh repo clone "$HOMEBREW_TAP_REPO" "$TAP_DIR/tap" -- --depth 1
  CASK="$TAP_DIR/tap/Casks/punt.rb"
  [ -f "$CASK" ] || die "cask not found in tap: Casks/punt.rb"
  sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK"
  if grep -q 'sha256 :no_check' "$CASK"; then
    sed -i '' "s/sha256 :no_check/sha256 \"$SHA256\"/" "$CASK"
  else
    sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK"
  fi
  (
    cd "$TAP_DIR/tap"
    git config user.name "punt-release"
    git config user.email "punt-release@local"
    git add Casks/punt.rb
    if git diff --cached --quiet; then
      echo "Homebrew cask already at $VERSION; nothing to commit."
    else
      git commit -m "Update cask to $TAG"
      git push origin HEAD
    fi
  )
fi

echo ""
echo "Released $TAG"
echo "  https://github.com/mpalczew/punt/releases/tag/$TAG"
echo "  zip sha256: $SHA256"
