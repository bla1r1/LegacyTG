#!/bin/bash
# shots.sh - shoot a list of screens on the bench phone, for a before/after
# check of a change. Each step is "name=route[,route...]": the routes are
# itglegacy:// paths opened in order (a wait after each), then the screen is
# shot as name.png. A step without "=" is only opened, not shot.
#
#   scripts/shots.sh OUT tab/1 search 'search-empty=type/zzqq' tab/0
#   scripts/shots.sh --wait 6 OUT 'gift=screen/gift' 'folders=settings/9'
#   scripts/shots.sh --list my.steps OUT     one step per line, # comments
#
# Compare two runs with scripts/shotdiff.py OUT_BEFORE OUT_AFTER.
set -uo pipefail

SSH_HOST=itgphone
SSH_OPTS="-o ConnectTimeout=6 -o BatchMode=yes"
WAIT=4
LIST=""
while [ $# -gt 0 ]; do
	case "$1" in
		--wait) WAIT="$2"; shift 2 ;;
		--list) LIST="$2"; shift 2 ;;
		-*) echo "unknown option: $1" >&2; exit 2 ;;
		*) break ;;
	esac
done
[ $# -ge 1 ] || { sed -n '2,12p' "$0"; exit 2; }
OUT="$1"; shift
mkdir -p "$OUT"

STEPS=("$@")
if [ -n "$LIST" ]; then
	while IFS= read -r line; do
		line="${line%%#*}"; line="$(echo "$line" | xargs)"
		[ -n "$line" ] && STEPS+=("$line")
	done < "$LIST"
fi

IPROXY_PID=""
trap '[ -n "$IPROXY_PID" ] && kill "$IPROXY_PID" 2>/dev/null' EXIT
dev() { ssh $SSH_OPTS "$SSH_HOST" "$@"; }
if ! dev true 2>/dev/null; then
	iproxy 2222 22 >/dev/null 2>&1 &
	IPROXY_PID=$!
	sleep 2
	dev true || { echo "no ssh to the phone" >&2; exit 1; }
fi

open_route() { dev "uiopen 'itglegacy://$1' 2>/dev/null; true"; sleep "$WAIT"; }

SHOT=0
for step in "${STEPS[@]}"; do
	name=""; routes="$step"
	case "$step" in *=*) name="${step%%=*}"; routes="${step#*=}" ;; esac
	IFS=',' read -ra list <<< "$routes"
	for route in "${list[@]}"; do open_route "$route"; done
	[ -n "$name" ] || continue
	dev "rm -f /var/mobile/Library/Caches/screen.png; uiopen itglegacy://screenshot"
	sleep 2
	if scp -O -q $SSH_OPTS "$SSH_HOST:/var/mobile/Library/Caches/screen.png" "$OUT/$name.png"; then
		SHOT=$((SHOT + 1))
	else
		echo "no shot: $name" >&2
	fi
done
echo "$SHOT shots in $OUT"
