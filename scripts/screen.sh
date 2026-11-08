#!/bin/bash
# screen.sh - dark or wake the bench phone's display.
#
#   ./scripts/screen.sh off     turn the panel fully off
#   ./scripts/screen.sh on      wake it and unlock
#   ./scripts/screen.sh status  report what the device says it is doing
#
# The action goes through the AutoUnlock SpringBoard tweak, which owns the
# backlight and lock screen. notifypost is built and installed on the device
# the first time it is needed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_HOST="${SSH_HOST:-itgphone}"
SSH_OPTS="-o ConnectTimeout=6 -o BatchMode=yes"

device() { ssh $SSH_OPTS "$SSH_HOST" "$@"; }

ensure_notifypost() {
	if device 'test -x /usr/bin/notifypost' 2>/dev/null; then
		return
	fi
	local sdk="$ROOT/build/sdks/iPhoneOS15.6.sdk"
	[ -d "$sdk" ] || sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
	xcrun -sdk iphoneos clang -arch armv7 -mno-thumb -isysroot "$sdk" \
		-mios-version-min=6.0 -Wl,-no_pie -framework CoreFoundation \
		-o /tmp/notifypost "$ROOT/tools/notifypost/notifypost.c"
	ldid -S /tmp/notifypost
	scp -q /tmp/notifypost "$SSH_HOST:/usr/bin/notifypost"
	device 'chmod 755 /usr/bin/notifypost'
}

case "${1:-}" in
	off)
		ensure_notifypost
		device 'notifypost org.legacy.itg.screenoff'
		echo "screen off"
		;;
	on)
		ensure_notifypost
		device 'notifypost org.legacy.itg.screenon'
		echo "screen on"
		;;
	status)
		device 'launchctl list | grep -i legacy || true; echo "---"; ls -l /Library/MobileSubstrate/DynamicLibraries/AutoUnlock.dylib'
		;;
	*)
		echo "usage: $0 {off|on|status}" >&2
		exit 2
		;;
esac
