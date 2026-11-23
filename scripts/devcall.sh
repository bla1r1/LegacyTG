#!/bin/bash
# devcall.sh - one round of a call check on the device: build, put the new
# binary in, relaunch, video-call a chat by name, and print what the call did.
#
#   scripts/devcall.sh NAME                  build, swap, relaunch, call NAME
#   scripts/devcall.sh --no-build NAME       the binary already built
#   scripts/devcall.sh --seconds 60 NAME     watch the call this long once up (default 45)
#   scripts/devcall.sh --udid UDID NAME      the phone when several are on the cable
#
# ~2-3 min a round against ~7 for devrun.sh plus tests: only the executable
# goes over (bench.sh --swap; no uicache, no SpringBoard restart), iproxy is
# kept when ssh already answers, and the host tests and call stand are left
# for the end of the work. A resource or Info.plist change needs devrun.sh.
# Needs a dev build installed once (devrun.sh) and the itgphone ssh block.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD=1 SECONDS_UP=45 UDID= NAME=
while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) BUILD=0; shift ;;
		--seconds) SECONDS_UP=$2; shift 2 ;;
		--udid) UDID=$2; shift 2 ;;
		*) NAME=$1; shift ;;
	esac
done
[ -n "$NAME" ] || { echo "usage: scripts/devcall.sh [--no-build] [--seconds N] [--udid UDID] NAME"; exit 2; }
UOPT=${UDID:+-u $UDID}
SSH="ssh -o ConnectTimeout=8 -o BatchMode=yes itgphone"
LOG="$ROOT/build/devlogs/devcall-$(date +%Y%m%d-%H%M%S).log"
BIN="$ROOT/build/armv7/app-dev/LegacyTG.app/LegacyTG"
mkdir -p "$ROOT/build/devlogs"

if [ "$BUILD" = 1 ]; then
	echo "[+] make DEV=1 ipa-armv7"
	make -C "$ROOT" -j"$(sysctl -n hw.logicalcpu)" DEV=1 ipa-armv7 > "$ROOT/build/devcall-build.log" 2>&1 ||
		{ grep -m5 'error:' "$ROOT/build/devcall-build.log"; exit 1; }
fi

if ! timeout 12 $SSH true 2>/dev/null; then
	pkill -f "iproxy 2222 22" 2>/dev/null; sleep 1
	iproxy 2222 22 $UOPT >/dev/null 2>&1 &
	for _ in $(seq 1 12); do timeout 12 $SSH true 2>/dev/null && break; sleep 5; done
fi

echo "[+] swapping the binary"
timeout 20 $SSH "cat > /tmp/LegacyTG.xcent" < "$ROOT/resources/LegacyTG-jailbreak.xcent" &&
timeout 120 $SSH "killall LegacyTG 2>/dev/null; cat > /Applications/LegacyTG.app/LegacyTG.new && \
	ldid -S/tmp/LegacyTG.xcent /Applications/LegacyTG.app/LegacyTG.new && \
	chmod 755 /Applications/LegacyTG.app/LegacyTG.new && \
	mv -f /Applications/LegacyTG.app/LegacyTG.new /Applications/LegacyTG.app/LegacyTG" < "$BIN" ||
	{ echo "[-] binary swap failed"; exit 1; }

idevicesyslog $UOPT 2>/dev/null | grep --line-buffered "LegacyTG" > "$LOG" &
LOGPID=$!
trap 'kill $LOGPID 2>/dev/null' EXIT
# idevicesyslog starts by replaying the phone's recent buffer: only what
# comes after this round's launch counts.
sleep 3
START=$(($(wc -l < "$LOG") + 1))
fresh() { tail -n +"$START" "$LOG"; }
wait_for() {   # pattern, seconds
	for _ in $(seq 1 "$2"); do fresh | grep -qE "$1" && return 0; sleep 1; done
	return 1
}

echo "[+] launching"
timeout 15 $SSH "uiopen itglegacy://" >/dev/null
wait_for "connectionStateReady" 40 || echo "[!] no connectionStateReady in 40 s"
NAME_URL=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$NAME")
echo "[+] video call to $NAME"
timeout 15 $SSH "uiopen 'itglegacy://videocall/$NAME_URL'" >/dev/null
if ! wait_for "callStateReady|callStateError|discarded, reason|no private chat" 120; then
	echo "[-] the call never got anywhere"; exit 1
fi
if fresh | grep -qE "callStateReady"; then
	echo "[+] up; watching ${SECONDS_UP} s"
	wait_for "discarded, reason" "$SECONDS_UP"
fi

echo "--- call ($LOG)"
fresh | grep -E "TGCall: (callState|discarded, reason)|no private chat|message = " | cut -c40-130 | uniq
fresh | grep -E "samples/s in|cpu [0-9]+%|VideoIntake|peer frames (decoded|assembled)|incoming level|codecs|holes|refused" | cut -c40-260 | tail -24
