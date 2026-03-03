#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: scripts/release.sh X.Y.Z"
  exit 1
fi

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "Error: version must be semver (e.g. 1.0.0)"
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Error: working tree is dirty. Commit or stash changes first."
  exit 1
fi

if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  echo "Error: tag v$VERSION already exists"
  exit 1
fi

DATE=$(date +%Y-%m-%d)
HEADER="## [$VERSION] - $DATE"

# Insert new version header after the changelog preamble
sed -i '' "/^## \[/i\\
\\
$HEADER\\
\\
### Changed\\
- TODO: fill in changes\\
" CHANGELOG.md

echo "Opening CHANGELOG.md for editing..."
${EDITOR:-vi} CHANGELOG.md

echo ""
echo "CHANGELOG.md updated. Review:"
head -20 CHANGELOG.md
echo ""
read -p "Commit, tag v$VERSION, and push? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 1
fi

git add CHANGELOG.md
git commit -m "Release v$VERSION"
git tag "v$VERSION"
git push origin main
git push origin "v$VERSION"

echo ""
echo "Pushed v$VERSION. CI will build, sign, notarize, release, and update Homebrew."
echo "Watch: gh run watch"
