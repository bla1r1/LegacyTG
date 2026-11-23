#!/bin/bash
# build_deb.sh - the Cydia package from the universal IPA.
#
#   scripts/build_deb.sh                 build/ipa/LegacyTG.ipa -> build/ipa/<pkg>.deb
#   scripts/build_deb.sh path/to.ipa
#
# The deb carries the same app as the IPA under /Applications, and refreshes
# SpringBoard's icon cache after install and removal. Version and build come
# from the app's Info.plist, so the package always says what it contains.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA="${1:-$ROOT/build/ipa/LegacyTG.ipa}"
PKG=org.legacy.itg
[ -f "$IPA" ] || { echo "no IPA at $IPA (make ipa first)" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/data/Applications" "$WORK/control"
unzip -q "$IPA" -d "$WORK/ipa"
APP="$(ls -d "$WORK"/ipa/Payload/*.app | head -1)"
[ -d "$APP" ] || { echo "no .app in $IPA" >&2; exit 1; }
cp -R "$APP" "$WORK/data/Applications/"

PLIST="$APP/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
DEBVER="$VERSION-$BUILD"

cat > "$WORK/control/control" <<EOF
Package: $PKG
Name: LegacyTG
Version: $DEBVER
Architecture: iphoneos-arm
Section: Social
Depends: firmware (>= 6.0)
Maintainer: bla1r1
Author: bla1r1
Description: LegacyTG: Telegram for iOS 6.0-12.5.7 on old iPhones and iPads.
Depiction: https://bla1r1.github.io/LegacyTG/depiction/$PKG/
Icon: https://bla1r1.github.io/LegacyTG/CydiaIcon.png
EOF
cat > "$WORK/control/postinst" <<'EOF'
#!/bin/sh
APP="/Applications/LegacyTG.app"

# 1. Register with uicache (targeted -p on iOS 8+, fallback to -a or bare uicache on iOS 6/7)
if command -v uicache >/dev/null 2>&1; then
	uicache -p "$APP" 2>/dev/null || uicache -a 2>/dev/null || uicache 2>/dev/null || su mobile -c uicache 2>/dev/null || true
fi

# 2. Tell Cydia / Zebra to prompt for SpringBoard restart so the icon appears immediately on all iOS versions
if [ -n "$CYDIA" ]; then
	CYFD="${CYDIA%% *}"
	if [ -n "$CYFD" ]; then
		eval "echo 'finish:restart' >&$CYFD" 2>/dev/null || true
	fi
fi

exit 0
EOF
chmod 755 "$WORK/control/postinst"

cat > "$WORK/control/postrm" <<'EOF'
#!/bin/sh
APP="/Applications/LegacyTG.app"

# 1. Unregister from uicache
if command -v uicache >/dev/null 2>&1; then
	uicache -u "$APP" 2>/dev/null || uicache -a 2>/dev/null || uicache 2>/dev/null || su mobile -c uicache 2>/dev/null || true
fi

# 2. Tell Cydia / Zebra to prompt for SpringBoard restart
if [ -n "$CYDIA" ]; then
	CYFD="${CYDIA%% *}"
	if [ -n "$CYFD" ]; then
		eval "echo 'finish:restart' >&$CYFD" 2>/dev/null || true
	fi
fi

exit 0
EOF
chmod 755 "$WORK/control/postrm"

# Strip all extended attributes recursively before packaging.
xattr -rc "$WORK" 2>/dev/null || true

# Owned by root as dpkg expects, in POSIX ustar format, without macOS extended attributes or PAX headers.
export COPYFILE_DISABLE=1
TAR_FLAGS=(--uid 0 --gid 0 --uname root --gname wheel)
if tar --format ustar --version >/dev/null 2>&1; then
	TAR_FLAGS+=(--format ustar)
fi
if tar --no-xattrs --version >/dev/null 2>&1; then
	TAR_FLAGS+=(--no-xattrs)
fi
if tar --no-mac-metadata --version >/dev/null 2>&1; then
	TAR_FLAGS+=(--no-mac-metadata)
fi

( cd "$WORK/control" && tar "${TAR_FLAGS[@]}" -czf ../control.tar.gz ./ )
( cd "$WORK/data" && tar "${TAR_FLAGS[@]}" -czf ../data.tar.gz ./Applications )
printf '2.0\n' > "$WORK/debian-binary"

OUT="$(dirname "$IPA")/${PKG}_${DEBVER}_iphoneos-arm.deb"
# A plain ar archive: macOS ar adds a __.SYMDEF member dpkg has no use for.
python3 - "$OUT" "$WORK/debian-binary" "$WORK/control.tar.gz" "$WORK/data.tar.gz" <<'EOF'
import os, sys, time
out, members = sys.argv[1], sys.argv[2:]
with open(out, "wb") as f:
    f.write(b"!<arch>\n")
    for path in members:
        data = open(path, "rb").read()
        name = os.path.basename(path).encode()
        header = b"%-16s%-12d%-6d%-6d%-8s%-10d`\n" % (name, int(time.time()), 0, 0, b"100644", len(data))
        f.write(header + data + (b"\n" if len(data) % 2 else b""))
EOF
echo "$OUT"
