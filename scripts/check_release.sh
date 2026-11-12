#!/bin/sh
# A build without DEV=1 must carry no dev mode. The automation URLs would let any
# web page send messages and answer calls, so this reads the linked binary rather
# than trusting the #ifs.
#
# Availability gate: the armv7 slice must compile cleanly with
# -Werror=unguarded-availability, proving every iOS 7+ API call is guarded by
# a respondsToSelector: check. This is a hard pre-release requirement; tagging
# a release with an unguarded call is the same as shipping a known crash on 6.1.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# -----------------------------------------------------------------
# 1) Availability gate: compile the armv7 slice with Werror promotion.
#    Uses a single representative source file to validate the flag without
#    a full rebuild; the Makefile's -Wunguarded-availability already fires
#    warnings during ipa-armv7, so this gate catches any regression that
#    somehow slipped past the warning stage.
# -----------------------------------------------------------------
echo "[check_release] availability gate: armv7 -Werror=unguarded-availability"
make -C "$ROOT" DEV=0 ipa-armv7 CFLAGS_ARMV7_EXTRA="-Werror=unguarded-availability" >/dev/null 2>&1 || {
	echo "FAIL: armv7 build has unguarded iOS 7+ API calls."
	echo "      Run:  make -C . DEV=0 ipa-armv7 CFLAGS_ARMV7_EXTRA=-Werror=unguarded-availability"
	echo "      Fix every warning before tagging a release."
	exit 1
}
echo "[check_release] availability gate: PASSED"

# -----------------------------------------------------------------
# 2) Binary selector audit: every iOS 7+ selector in the armv7 binary
#    must be paired with a respondsToSelector: guard in src/.
#
#    Rationale: -Wunguarded-availability only fires for API symbols the
#    toolchain can resolve at compile time (SDK headers). A selector sent
#    via a string literal or a category extension can slip through. This
#    second gate reads the actual __objc_methname section of the linked
#    binary and cross-checks each dangerous selector against the source.
# -----------------------------------------------------------------
echo "[check_release] binary selector audit: iOS 7+ guard coverage"
make -C "$ROOT" DEV=0 ipa-armv7 >/dev/null
APP="$ROOT/build/armv7/app/LegacyTG.app"
BIN="$APP/LegacyTG"

DANGEROUS_SELECTORS="
setSectionIndexBackgroundColor:
setSectionIndexTrackingBackgroundColor:
setBarTintColor:
setEdgesForExtendedLayout:
setTintAdjustmentMode:
interactivePopGestureRecognizer
imageWithRenderingMode:
setSelectedImageTintColor:
"

AUDIT_FAIL=0

# Extract the flat list of selectors from the Mach-O methname section.
# otool prints one entry per line; the final field (awk $NF) strips the
# address prefix.  On a fat binary, lipo extracts the armv7 slice first so
# we always audit the right architecture.
TMPBIN="$ROOT/build/armv7/_audit_armv7"
lipo -thin armv7 "$BIN" -output "$TMPBIN" 2>/dev/null || cp "$BIN" "$TMPBIN"
BINARY_SELS=$(otool -v -s __TEXT __objc_methname "$TMPBIN" 2>/dev/null \
              | grep -v '^Contents' | awk '{print $NF}')
rm -f "$TMPBIN"

for sel in $DANGEROUS_SELECTORS; do
	[ -z "$sel" ] && continue
	if echo "$BINARY_SELS" | grep -qxF "$sel"; then
		# Selector is present in the binary.  For every source file that
		# mentions it, verify no bare call site lacks a guard.
		FILES=$(grep -rlF "$sel" "$ROOT/src/" 2>/dev/null || true)
		for f in $FILES; do
			# Collect line numbers of real call sites (dot-setter or bracket
			# send), skipping comment lines and respondsToSelector: lines.
			CALL_LINES=$(grep -nE "(\[.*${sel}\]|\.${sel%%:*}\s*=)" "$f" 2>/dev/null \
			             | grep -vE "respondsToSelector|^\s*//|^\s*\*" \
			             | awk -F: '{print $1}')
			for lineno in $CALL_LINES; do
				# Accept if any of the 5 lines before the call contain a guard.
				START=$(( lineno > 5 ? lineno - 5 : 1 ))
				GUARD=$(sed -n "${START},${lineno}p" "$f" 2>/dev/null \
				        | grep -c "respondsToSelector" || true)
				if [ "$GUARD" = "0" ]; then
					echo "FAIL: unguarded '$sel' in $f line $lineno" >&2
					sed -n "${START},${lineno}p" "$f" | head -6 >&2
					AUDIT_FAIL=1
				fi
			done
		done
	fi
done

if [ "$AUDIT_FAIL" = "1" ]; then
	echo "[check_release] binary selector audit: FAILED"
	exit 1
fi
echo "[check_release] binary selector audit: PASSED"

# -----------------------------------------------------------------
# 3) Dev-mode content gate: the linked binary must carry no dev symbols.
#    Reuses the binary from the selector audit above (same build, same path).
# -----------------------------------------------------------------
# APP and BIN already set by section 2.
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
[ "$FOUND" = 0 ] && echo "release clean"
exit "$FOUND"
