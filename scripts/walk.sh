#!/bin/bash
# walk.sh - open about 40 screens of the dev build on the bench phone through
# itglegacy:// and fail if the app dies on any of them.
#
#   scripts/walk.sh                three passes: light/English, dark, Russian
#   scripts/walk.sh --pass light   one pass (light | dark | ru)
#
# Needs the dev build installed (devrun.sh --smoke builds, installs, then runs
# this) and SSH to the phone (the `itgphone` block in ~/.ssh/config).
#
# Exit 1 on SIGABRT, "unrecognized selector", "Terminating app", a new crash
# report from LegacyTG or a LowMemory report naming it. The screenshots in
# build/devlogs/walk-<stamp>/ are for a person; the exit code is the gate.
#
# Sends nothing from the account: no send/, no call/, only screens that change
# nothing until something on them is tapped. The run leaves the phone on
# Night Mode off and the system language.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/build/devlogs/walk-$STAMP"
SSH_HOST=itgphone
SSH_OPTS="-o ConnectTimeout=6 -o BatchMode=yes"
CRASH='SIGABRT|unrecognized selector|Terminating app'
# A public channel and its profile: real posts, nobody's private chat.
PUBLIC=telegram
PASSES="light dark ru"

while [ $# -gt 0 ]; do
	case "$1" in
		--pass) PASSES="$2"; shift 2 ;;
		*) echo "unknown option: $1"; exit 2 ;;
	esac
done

mkdir -p "$OUT"
IPROXY_PID=""
SYSLOG_PID=""
cleanup() {
	[ -n "$SYSLOG_PID" ] && kill "$SYSLOG_PID" 2>/dev/null
	[ -n "$IPROXY_PID" ] && kill "$IPROXY_PID" 2>/dev/null
}
trap cleanup EXIT

dev() { ssh $SSH_OPTS "$SSH_HOST" "$@"; }
if ! dev true 2>/dev/null; then
	iproxy 2222 22 >/dev/null 2>&1 &
	IPROXY_PID=$!
	sleep 2
	dev true || { echo "no ssh to the phone" >&2; exit 1; }
fi

# Crash and LowMemory reports already on the phone are not ours.
reports() { idevicecrashreport -e -k "$1" >/dev/null 2>&1; ls "$1" 2>/dev/null | sort; }
reports "$OUT/reports-before" > "$OUT/.before"

idevicesyslog > "$OUT/syslog.log" 2>&1 &
SYSLOG_PID=$!
sleep 2

FAILED=0
hits() { grep -cE "$CRASH" "$OUT/syslog.log" 2>/dev/null || true; }

open_url() { dev "uiopen '$1' 2>/dev/null; true"; }

shot() {
	open_url itglegacy://screenshot
	sleep 1.5
	scp -O $SSH_OPTS "$SSH_HOST:/var/mobile/Library/Caches/screen.png" "$1" >/dev/null 2>&1 \
		|| echo "  (no screenshot)" >&2
}

N=0
screen() {   # screen <url> [wait seconds]
	local url="$1" wait="${2:-3}" before
	before=$(hits)
	open_url "itglegacy://$url"
	sleep "$wait"
	N=$((N + 1))
	shot "$OUT/$PASS/$(printf '%02d' $N)-$(echo "$url" | tr '/:' '__').png"
	if [ "$(hits)" != "$before" ]; then
		echo "  FAIL $url" >&2
		grep -E "$CRASH" "$OUT/syslog.log" | tail -3 >&2
		FAILED=1
	else
		echo "  ok   $url"
	fi
}

cold() {
	dev "killall LegacyTG 2>/dev/null; true"
	sleep 2
	open_url itglegacy://tab/0
	sleep 8
}

walk() {
	for t in 0 1 2 3 4; do screen "tab/$t"; done
	for p in $(seq 1 20); do screen "settings/$p"; done
	screen settings/wallpaper
	screen saved 4
	screen aicompose
	screen "chat/$PUBLIC" 6
	screen "profile/$PUBLIC" 5
	screen profile/me 4
	screen ownscreen/colours
	screen ownscreen/edit
	screen search
	screen callscreen/Walk
	open_url itglegacy://hangup; sleep 2
	# The sign-in steps replace the tab bar; they go last, and the next
	# pass starts cold.
	for s in code password email recovery; do screen "loginstep/$s"; done
}

for PASS in $PASSES; do
	echo "=== pass: $PASS"
	mkdir -p "$OUT/$PASS"
	N=0
	cold
	case "$PASS" in
		light) open_url itglegacy://night/off; open_url itglegacy://lang/en ;;
		dark)  open_url itglegacy://night/on;  open_url itglegacy://lang/en ;;
		ru)    open_url itglegacy://night/off; open_url itglegacy://lang/ru ;;
	esac
	# The pack comes from TDLib; a relaunch draws every screen in it.
	sleep 8
	cold
	walk
done

cold
open_url itglegacy://night/off
open_url itglegacy://lang/system
sleep 4
dev "killall LegacyTG 2>/dev/null; true"

sleep 3
reports "$OUT/reports-after" > "$OUT/.after"
for r in $(comm -13 "$OUT/.before" "$OUT/.after"); do
	f="$OUT/reports-after/$r"
	case "$r" in
		LegacyTG*|iTgLegacy*) echo "FAIL crash report: $r" >&2; FAILED=1 ;;
		LowMemory*) grep -q LegacyTG "$f" && { echo "FAIL LowMemory names LegacyTG: $r" >&2; FAILED=1; } ;;
	esac
done

echo "screens: $OUT"
[ "$FAILED" = 0 ] && echo "walk: PASSED" || echo "walk: FAILED"
exit "$FAILED"
