#!/bin/bash
# bench.sh - scroll and open chats on the device with nobody holding it, and
# say where the main thread spent the time.
#
#   ./scripts/bench.sh                launch cold, run the suite, report
#   ./scripts/bench.sh --no-launch    run against the app as it is now
#   ./scripts/bench.sh --prof         also sample stacks (adds ~5% load)
#   ./scripts/bench.sh --udid UDID    the phone to use when several are on the
#                                     cable; without it iproxy and syslog pick
#                                     whichever comes first and may disagree
#   ./scripts/bench.sh --only chat    open the first chat (CHAT=n for another) and scroll it twice;
#                                     skips contacts and the three opens (~40 s)
#   ./scripts/bench.sh --swap         put build/armv7/app-dev's binary into the
#                                     installed app first. No uicache, so no
#                                     SpringBoard restart: on the iPod touch 4
#                                     that restart is what set off the watchdog
#                                     panics and reboots. Code changes only; a
#                                     resource or Info.plist change needs devrun
#   ./scripts/bench.sh --sbunlock     send URLs through the AutoUnlock tweak:
#                                     the 4S on iOS 7.1 drops most uiopen calls
#                                     into a running app; a URL lands ~10 s later
#
# Exits 1 when a run is over budget, so it doubles as the regression test for
# what a host test cannot see (CoreAnimation, backboardd). Budgets are the
# iPod touch 4 plus headroom: chat scroll was 33% dropped frames with a
# 277 ms worst before the layer work, 9-10% / ~50 ms after. For scale, the
# plain grouped Settings table drops 13-22% on the same phone: backboardd
# needs ~3 s of every 8 to recomposite a moving 640x960 screen.
#
# Needs the app installed (devrun.sh) and the itgphone ssh block.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build/bench/$(date +%Y%m%d-%H%M%S)"
SSH="ssh -o ConnectTimeout=6 -o BatchMode=yes itgphone"
BIN="$ROOT/build/armv7/app-dev/LegacyTG.app/LegacyTG"
LAUNCH=1
PROF=""
UOPT=""
SBUNLOCK=0
ONLY=""
SWAP=0
while [ $# -gt 0 ]; do
	case "$1" in
		--no-launch) LAUNCH=0; shift ;;
		--prof) PROF="/prof"; shift ;;
		--udid) UOPT="-u $2"; shift 2 ;;
		--sbunlock) SBUNLOCK=1; shift ;;
		--only) ONLY="$2"; shift 2 ;;
		--swap) SWAP=1; shift ;;
		*) echo "unknown option: $1"; exit 2 ;;
	esac
done
mkdir -p "$OUT"

if [ -n "$UOPT" ]; then
	# Port 2222 may still forward to the other phone.
	pkill -f "iproxy 2222 22" 2>/dev/null; sleep 1
	iproxy 2222 22 $UOPT >/dev/null 2>&1 & sleep 2
else
	$SSH true 2>/dev/null || { iproxy 2222 22 >/dev/null 2>&1 & sleep 2; }
fi
if [ "$SWAP" = 1 ]; then
	$SSH "cat > /tmp/LegacyTG.xcent" < "$ROOT/resources/LegacyTG-jailbreak.xcent" &&
	$SSH "killall LegacyTG 2>/dev/null; cat > /Applications/LegacyTG.app/LegacyTG.new && \
		ldid -S/tmp/LegacyTG.xcent /Applications/LegacyTG.app/LegacyTG.new && \
		chmod 755 /Applications/LegacyTG.app/LegacyTG.new && \
		mv -f /Applications/LegacyTG.app/LegacyTG.new /Applications/LegacyTG.app/LegacyTG" < "$BIN" \
		|| { echo "binary swap failed"; exit 2; }
	echo "swapped the binary"
fi
if [ "$SBUNLOCK" = 1 ]; then
	# Waits the delivery out so every step's own sleep still counts from arrival.
	open_url() { $SSH "sbunlock --url 'itglegacy://$1'" >/dev/null 2>&1; sleep 12; }
else
	open_url() { $SSH "uiopen 'itglegacy://$1'"; }
fi

idevicesyslog $UOPT 2>/dev/null | grep --line-buffered -E "LegacyTG|\[perf\]|\[bench\]" > "$OUT/syslog.log" &
LOGPID=$!
trap 'kill $LOGPID 2>/dev/null' EXIT

if [ "$LAUNCH" = 1 ]; then
	$SSH "killall LegacyTG 2>/dev/null; rm -f /var/mobile/Applications/*/Library/Caches/bench-*.txt \
		/private/var/mobile/Library/Caches/bench-*.txt; true"
	sleep 2
	from=$(wc -l < "$OUT/syslog.log")
	open_url ""
	# TDLib opens its database and fetches the chat list before anything is
	# worth timing: wait for the connection (4 s on the iPod touch 4), then
	# give the list a few seconds. 30 s is the ceiling for the 3GS class.
	for _ in $(seq 60); do
		tail -n +$((from + 1)) "$OUT/syslog.log" | grep -q "connectionStateReady" && break
		sleep 0.5
	done
	sleep 4
else
	sleep 2
fi

# Every bench step ends with one "mem" line (an open with two: the push and
# the pop); the next URL goes once it is out, since one sent mid-run is
# refused. The seconds are the old fixed waits, now only a ceiling.
step() {
	local url=$1 lines=$2 ceiling=$3 base
	base=$(grep -ac "\] mem task=" "$OUT/syslog.log")
	open_url "$url"
	for _ in $(seq $((ceiling * 4))); do
		[ "$(grep -ac "\] mem task=" "$OUT/syslog.log")" -ge $((base + lines)) ] && break
		sleep 0.25
	done
	sleep 0.5
}

open_url "tab/0";                     sleep 2
if [ "$ONLY" != chat ]; then
	step "bench/scroll/8$PROF" 1 11
	open_url "scroll/0";              sleep 1
	for row in 0 1 2; do
		step "bench/open/$row$PROF" 2 7
	done
fi
open_url "chatindex/${CHAT:-0}";       sleep 4
# Twice: the first pass pays one-time costs (a sticker build is 100-500 ms on
# a background queue, the first emoji measure ~70 ms) that the second does not.
step "bench/scroll/8$PROF" 1 11
# Both passes write the same sample file; keep the first one's stacks apart.
[ -n "$PROF" ] && $SSH 'for f in /var/mobile/Applications/*/Library/Caches/bench-scroll-TGChatViewController.txt \
		/private/var/mobile/Library/Caches/bench-scroll-TGChatViewController.txt; do
	[ -f "$f" ] && mv "$f" "${f%.txt}-cold.txt"; done; true'
step "bench/scroll/8$PROF" 1 11
open_url "tab/0";                     sleep 1

kill $LOGPID 2>/dev/null
echo "=== results"
# idevicesyslog replays the device's buffer first; only this run counts.
awk -v launch="$LAUNCH" 'launch == 1 && /Starting application/ { n = 0; delete keep }
	/\[bench\]|\[perf\]/ { keep[n++] = $0 } END { for (i = 0; i < n; i++) print keep[i] }' "$OUT/syslog.log" \
	| grep -av "\] dump " | sed 's/.*LegacyTG[^:]*: //' | tee "$OUT/summary.txt"

if [ -n "$PROF" ]; then
	for remote in $($SSH "ls /var/mobile/Applications/*/Library/Caches/bench-*.txt \
			/private/var/mobile/Library/Caches/bench-*.txt 2>/dev/null"); do
		local_f="$OUT/$(basename "$remote")"
		scp -q -o BatchMode=yes "itgphone:$remote" "$local_f"
		echo
		echo "=== $(basename "$remote" .txt)"
		python3 "$ROOT/scripts/bench_report.py" "$local_f" "$BIN" | tee "${local_f%.txt}.report"
	done
fi
echo
echo "saved in $OUT"

# what, max dropped %, max worst frame ms, which run (head or tail)
check() {
	grep -a "\[bench\] $1 first" "$OUT/summary.txt" | ${4:-tail} -1 | awk -v what="$1" -v pct="$2" -v worst="$3" '
		{ match($0, /\(([0-9]+)%\)/); d = substr($0, RSTART + 1, RLENGTH - 3) + 0
		  match($0, /worst=[0-9]+/); w = substr($0, RSTART + 6, RLENGTH - 6) + 0
		  if (d > pct || w > worst) { printf "OVER BUDGET %s: %d%% dropped (max %d), worst %d ms (max %d)\n", what, d, pct, w, worst; bad = 1 } }
		END { exit bad }'
}
status=0
# No check on the chat list: on the showcase account it is shorter than the
# screen, so its "scroll" never moves and always reads 60 fps.
check scroll-TGChatViewController 20 250 head || status=1
check scroll-TGChatViewController 15 100 tail || status=1
check open-1 10 80 || status=1
[ "$status" = 0 ] && echo "within budget"
exit $status
