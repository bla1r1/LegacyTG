#!/bin/bash
# release.sh - build, check and publish the version resources/Info.plist names.
#
#   scripts/release.sh             build, checks, emulator smoke, then ask before publishing
#   scripts/release.sh --dry-run   everything up to publishing; nothing leaves this Mac
#   scripts/release.sh --yes       publish without the question
#   scripts/release.sh --no-emu    skip the emulator smoke (Intel Mac, or no device)
#
# Publishing is what 1.3 was: tag VERSION on main, push main and the tag, a
# GitHub Release "LegacyTG vVERSION" with LegacyTG.ipa and SHA256SUMS whose
# notes start "build: N" (the update bot reads it) followed by the version's
# CHANGELOG.md section, and the deb into the Cydia repository on gh-pages.
# The Telegram channel post is left to a person: its text is written to
# build/ipa/telegram-post.txt.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
die() { echo "[-] $*" >&2; exit 1; }

DRY=0 YES=0 EMU=1
for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY=1 ;;
		--yes) YES=1 ;;
		--no-emu) EMU=0 ;;
		*) sed -n 2,7p "$0"; exit 2 ;;
	esac
done

VER=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' resources/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' resources/Info.plist)
TAG=$VER
echo "[+] LegacyTG $VER ($BUILD)"

# What would make a published release wrong, before an hour of building.
[ "$(git branch --show-current)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "uncommitted changes: commit them first"
git fetch -q origin main gh-pages
git merge-base --is-ancestor origin/main HEAD || die "main is behind origin/main: pull first"
! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "tag $TAG exists: bump CFBundleShortVersionString"
! gh release view "$TAG" >/dev/null 2>&1 || die "GitHub already has release $TAG"
NOTES=build/ipa/release-notes.md
mkdir -p build/ipa
{ printf 'build: %s\n\n' "$BUILD"
  awk -v head="## $VER ($BUILD)" 'index($0, head) == 1 {on = 1} on && /^## / && index($0, head) != 1 {exit} on' CHANGELOG.md
} > "$NOTES"
grep -q "^## $VER ($BUILD)" "$NOTES" || die "CHANGELOG.md has no \"## $VER ($BUILD)\" section"

scripts/build_all.sh
for f in LegacyTG.ipa LegacyTG-armv7.ipa LegacyTG-arm64.ipa; do
	v=$(unzip -p "build/ipa/$f" Payload/LegacyTG.app/Info.plist | plutil -extract CFBundleVersion raw -)
	[ "$v" = "$BUILD" ] || die "$f is build $v, not $BUILD"
done

if [ "$EMU" = 1 ]; then
	echo "[+] emulator smoke (~7 min): launch, phone step, connection"
	scripts/emu.sh test | tee build/logs/emu-release.log
	grep -q 'authorizationStateWaitPhoneNumber' build/logs/emu-release.log &&
		grep -q 'connectionStateReady' build/logs/emu-release.log ||
		die "the release did not reach the phone step with a connection in the emulator (build/logs/emu-release.log); --no-emu skips this"
fi

scripts/build_deb.sh
DEB=build/ipa/org.legacy.itg_${VER}-${BUILD}_iphoneos-arm.deb
[ -f "$DEB" ] || die "no $DEB"

echo
echo "    tag $TAG on $(git rev-parse --short HEAD), push main and the tag"
echo "    GitHub Release \"LegacyTG v$VER\": LegacyTG.ipa, SHA256SUMS, notes $NOTES"
echo "    Cydia: $(basename "$DEB") into gh-pages"
if [ "$DRY" = 1 ]; then
	echo "[=] dry run: nothing published"
	exit 0
fi
if [ "$YES" != 1 ]; then
	read -r -p "Publish $VER? [y/N] " answer
	[ "$answer" = y ] || [ "$answer" = Y ] || { echo "[=] not published"; exit 0; }
fi

git tag "$TAG"
git push origin main "refs/tags/$TAG"
gh release create "$TAG" build/ipa/LegacyTG.ipa build/ipa/SHA256SUMS \
	--title "LegacyTG v$VER" --notes-file "$NOTES" --target main
URL=$(gh release view "$TAG" --json url --jq .url)

# gh-pages in its own worktree under build/, so this checkout's files stay put.
WT=build/gh-pages
git worktree remove --force "$WT" 2>/dev/null || true
git worktree add -q --detach "$WT" origin/gh-pages
python3 scripts/update_repo.py "$WT" "$DEB"
git -C "$WT" add -A
git -C "$WT" commit -q -m "cydia: $VER ($BUILD)"
git -C "$WT" push -q origin HEAD:gh-pages
git worktree remove "$WT"

POST=build/ipa/telegram-post.txt
{ echo "LegacyTG $VER"
  echo
  sed -n '/^- /p' "$NOTES" | tr -d '`'
  echo
  echo "$URL"
} > "$POST"
echo "[+] published: $URL"
echo "[+] channel post: $POST, the IPA to attach: build/ipa/LegacyTG.ipa"
