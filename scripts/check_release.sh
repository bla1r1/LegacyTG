#!/bin/sh
# A build without DEV=1 must carry no dev mode. The automation URLs would let any
# web page send messages and answer calls, so this reads the linked binary rather
# than trusting the #ifs.
#
# Before that, the iOS 7+ selectors: every one the armv7 binary sends must sit
# behind a guard in the source. There used to be a compile gate with
# -Werror=unguarded-availability in front of this; clang counts only
# @available as a guard, not the respondsToSelector: this tree uses, so it
# failed on every run (160 errors, nearly all guarded) and nobody read it.
# The normal build still prints those as warnings.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# -----------------------------------------------------------------
# 1) Selector audit: an iOS 7+ selector that is in the armv7 binary must be
#    guarded at every call site in src/.
#
#    The list is the selectors -Wunguarded-availability names in this tree
#    (2026-11-14), less three whose names older classes share since iOS 2-5
#    (setBounds:, setTintColor:, setTranslucent:), which would flag every
#    frame and bar. Classes, constants and enums are not selectors and are
#    not covered here; the build's warnings name them.
#
#    setMuted: is left out too: it is AVPlayer's, and TGCall's and the
#    stores' own.
#
#    A call site is a message send with every part of the selector in one
#    statement, or dot syntax for a getter or setter. It is guarded when one
#    of the 12 lines up to it asks respondsToSelector:,
#    instancesRespondToSelector:, NSClassFromString, @available,
#    NSFoundationVersionNumber or TGAttributedTextDrawing(). A guard further
#    away (an early return, a check in the caller) is named in a comment
#    "ios7-guarded: <where>" just above the call.
# -----------------------------------------------------------------
# The example's keys build fine and fail only at sign-in, as API_ID_INVALID.
if grep -Eq '^#define[[:space:]]+TG_API_ID[[:space:]]+12345([^0-9]|$)' "$ROOT/vendor/include/tg_config.h"; then
	echo "[check_release] vendor/include/tg_config.h has the example's api_id 12345: no release with placeholder keys"
	exit 1
fi

echo "[check_release] selector audit: iOS 7+ guard coverage"
# All three packages: the entitlement check below reads every IPA.
make -C "$ROOT" -j8 DEV=0 ipa >/dev/null
APP="$ROOT/build/armv7/app/LegacyTG.app"
BIN="$APP/LegacyTG"

DANGEROUS_SELECTORS="
attributedStringWithAttachment:
authorizationStatusForMediaType:
base64EncodedStringWithOptions:
boundingRectWithSize:options:attributes:context:
currentUserNotificationSettings
drawInRect:withAttributes:
imageWithRenderingMode:
initWithBase64EncodedString:options:
interactivePopGestureRecognizer
popoverPresentationController
requestAccessForMediaType:completionHandler:
requestWhenInUseAuthorization
selectedImage
setBarTintColor:
setEdgesForExtendedLayout:
setKeyboardDismissMode:
setNeedsStatusBarAppearanceUpdate
setSectionIndexBackgroundColor:
setSectionIndexTrackingBackgroundColor:
setSelectable:
setSelectedImage:
setSelectedImageTintColor:
setTextContainerInset:
setTintAdjustmentMode:
sizeWithAttributes:
textContainer
textContainerInset
topLayoutGuide
"

# The armv7 slice's selector table: what the binary can actually send.
TMPBIN="$ROOT/build/armv7/_audit_armv7"
lipo -thin armv7 "$BIN" -output "$TMPBIN" 2>/dev/null || cp "$BIN" "$TMPBIN"
otool -v -s __TEXT __objc_methname "$TMPBIN" 2>/dev/null \
	| grep -v '^Contents' | awk '{print $NF}' > "$TMPBIN.sels"
rm -f "$TMPBIN"

if ! SELECTORS="$DANGEROUS_SELECTORS" python3 - "$ROOT/src" "$TMPBIN.sels" <<'PY_AUDIT'
import os, re, sys

src, table = sys.argv[1], sys.argv[2]
in_binary = set(open(table).read().split())
GUARD = re.compile(r'respondsToSelector:|instancesRespondToSelector:|NSClassFromString'
                   r'|@available|NSFoundationVersionNumber|TGAttributedTextDrawing\(\)'
                   r'|ios7-guarded:')
WINDOW = 12

def strip(text):
    # Comments and string literals out, line count kept.
    blank = lambda m: re.sub(r'[^\n]', ' ', m.group(0))
    return re.sub(r'//[^\n]*|/\*.*?\*/|@?"(?:\\.|[^"\\\n])*"', blank, text, flags=re.S)

def patterns(sel):
    parts = [p for p in sel.split(':') if p]
    if sel.endswith(':'):
        # Every keyword, in order, inside one statement.
        send = r'\b' + r':[^;{}]*?\b'.join(map(re.escape, parts)) + ':'
        out = [send]
        if len(parts) == 1 and sel.startswith('set') and len(sel) > 4:
            prop = sel[3].lower() + sel[4:-1]
            out.append(r'\.' + re.escape(prop) + r'\s*=(?!=)')
        return out
    return [r'\s' + re.escape(sel) + r'\s*\]', r'\.' + re.escape(sel) + r'\b']

bad = 0
selectors = [s for s in os.environ['SELECTORS'].split() if s in in_binary]
for root, _, names in os.walk(src):
    for name in sorted(names):
        if not name.endswith(('.m', '.mm')):
            continue
        path = os.path.join(root, name)
        raw = open(path, errors='replace').read()
        clean = strip(raw)
        lines = raw.split('\n')
        for sel in selectors:
            for pat in patterns(sel):
                for m in re.finditer(pat, clean, re.S):
                    before = clean[:m.start()]
                    # @selector(x) and respondsToSelector: lines are the guards themselves.
                    if re.search(r'@selector\(\s*$', before[-40:]):
                        continue
                    line = before.count('\n')
                    # A declaration in a category or protocol is not a call.
                    if re.match(r'\s*[-+]\s*\(', lines[line]):
                        continue
                    window = '\n'.join(lines[max(0, line - WINDOW + 1):line + 1])
                    if not GUARD.search(window):
                        print(f'  unguarded {sel} at {os.path.relpath(path, os.path.dirname(src))}:{line + 1}')
                        bad += 1
print(f'  {len(selectors)} of the listed selectors are in the binary')
sys.exit(1 if bad else 0)
PY_AUDIT
then
	rm -f "$TMPBIN.sels"
	echo "[check_release] selector audit: FAILED"
	exit 1
fi
rm -f "$TMPBIN.sels"
echo "[check_release] selector audit: PASSED"

# -----------------------------------------------------------------
# 1b) No weak import from libSystem. Against a modern SDK a function newer
#    than iOS 6 links weak and dyld leaves it NULL on older systems: libvpx's
#    clock_gettime branched to 0 on the first VP8 frame. src/Compat defines
#    such functions strongly instead.
# -----------------------------------------------------------------
for arch in armv7 arm64; do
	slice="$ROOT/build/$arch/app/LegacyTG.app/LegacyTG"
	[ -f "$slice" ] || continue
	weak=$(nm -m "$slice" | grep 'weak external' | grep '(from libSystem)' || true)
	if [ -n "$weak" ]; then
		echo "[check_release] $arch weak libSystem imports, NULL before the iOS that added them:"
		echo "$weak"
		exit 1
	fi
done

# -----------------------------------------------------------------
# 2) Dev-mode content gate: the linked binary must carry no dev symbols.
#    Reuses the binary the selector audit built (same build, same path).
# -----------------------------------------------------------------
FOUND=0
for word in TGDevShowcase TGDevBench TGDevModeViewController TGDevTestHarnessViewController \
		TGMessageToolsViewController delete_selected itg_cmd handleOpenURL: \
		"Dev Showcase" "Dev Settings" "Read a String" "Look Up a Card" \
		"Web Proxy Carrier" "Message Tools" TGGhostMode "dev builds only"; do
	# handleOpenURL: the selector stays; its log line and routes must not.
	[ "$word" = "handleOpenURL:" ] && word="handleOpenURL: %@"
	if strings -a "$APP/LegacyTG" | grep -qF "$word"; then
		echo "FOUND in release: $word"
		FOUND=1
	fi
done
if plutil -p "$APP/Info.plist" | grep -qE 'legacytg|itglegacy'; then
	echo "FOUND in release: automation URL scheme"
	FOUND=1
fi
for f in avatar-durov.jpg avatar-bot.jpg; do
	if [ -e "$APP/$f" ]; then
		echo "FOUND in release: $f"
		FOUND=1
	fi
done
[ "$FOUND" = 0 ] && echo "release clean"

# -----------------------------------------------------------------
# 3) Keychain entitlements: every slice of every IPA. 1.3 was re-signed by a
#    bare codesign after lipo, securityd answered "missing entitlement", and
#    the database key and passcode were never stored. IPA_DIR=<dir> checks
#    another set of packages.
# -----------------------------------------------------------------
IPA_DIR="${IPA_DIR:-$ROOT/build/ipa}"
# scripts/gen_api_key.py masks the hash; a plain copy back in a slice means
# something compiled tg_config.h's TG_API_HASH in directly.
API_HASH=$(sed -nE 's/^#define[[:space:]]+TG_API_HASH[[:space:]]+"([^"]+)".*/\1/p' "$ROOT/vendor/include/tg_config.h")
# Release packages only: a dev IPA left over from devrun.sh is not shipped.
IPAS=$(ls "$IPA_DIR"/*.ipa 2>/dev/null | grep -v -- '-dev\.ipa$' || true)
if [ -z "$IPAS" ]; then
	echo "NO release IPA in $IPA_DIR to check entitlements on"
	exit 1
fi
ENT_TMP="$(mktemp -d)"
for ipa in $IPAS; do
	rm -rf "$ENT_TMP/Payload"
	if ! unzip -oq "$ipa" 'Payload/*.app/LegacyTG' -d "$ENT_TMP"; then
		echo "NO LegacyTG binary in $(basename "$ipa")"
		FOUND=1
		continue
	fi
	bin="$(echo "$ENT_TMP"/Payload/*.app/LegacyTG)"
	for arch in $(lipo -archs "$bin"); do
		lipo -thin "$arch" "$bin" -output "$ENT_TMP/slice" 2>/dev/null || cp "$bin" "$ENT_TMP/slice"
		if [ -n "$API_HASH" ] && grep -qaF "$API_HASH" "$ENT_TMP/slice"; then
			echo "API hash in plain text: $(basename "$ipa") $arch"
			FOUND=1
		fi
		ldid -e "$ENT_TMP/slice" > "$ENT_TMP/ent.plist" 2>/dev/null
		if plutil -extract keychain-access-groups xml1 -o - "$ENT_TMP/ent.plist" 2>/dev/null \
				| grep -q '<string>org.legacy.itg</string>'; then
			echo "entitlements ok: $(basename "$ipa") $arch"
		else
			echo "NO keychain-access-groups org.legacy.itg: $(basename "$ipa") $arch"
			FOUND=1
		fi
	done
done
rm -rf "$ENT_TMP"
exit "$FOUND"
