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
for script in postinst postrm; do
	cat > "$WORK/control/$script" <<'EOF'
#!/bin/sh
# SpringBoard caches installed app bundles; refresh it as the mobile user.
if command -v uicache >/dev/null 2>&1; then
	su mobile -c uicache 2>/dev/null || uicache || true
fi
exit 0
EOF
	chmod 755 "$WORK/control/$script"
done

# Owned by root as dpkg expects, without macOS extended attributes.
export COPYFILE_DISABLE=1
( cd "$WORK/control" && tar --uid 0 --gid 0 --uname root --gname wheel -czf ../control.tar.gz ./ )
( cd "$WORK/data" && tar --uid 0 --gid 0 --uname root --gname wheel -czf ../data.tar.gz ./Applications )
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
