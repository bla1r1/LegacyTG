#!/bin/bash
# feedback.sh - pull the notes made on the phone with the dev feedback tool
# (four taps or a three-finger tap, circle, comment, Save).
#
#   ./scripts/feedback.sh          copy new notes to build/feedback/ and list them
#   ./scripts/feedback.sh --clear  also delete them from the phone afterwards
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SSH_HOST="${SSH_HOST:-itgphone}"
OUT="$ROOT/build/feedback"
mkdir -p "$OUT"
pgrep -f 'iproxy 2222' >/dev/null || (iproxy 2222 22 >/dev/null 2>&1 &)
sleep 1
# An App Store-style install lives in a container; an SSH install uses the
# shared Caches folder. Take whichever has notes.
DIRS=$(ssh -o ConnectTimeout=6 "$SSH_HOST" \
	'ls -d /var/mobile/Applications/*/Library/Caches/feedback /var/mobile/Library/Caches/feedback 2>/dev/null' || true)
for dir in $DIRS; do
	scp -O -q "$SSH_HOST:$dir/*" "$OUT/" 2>/dev/null || true
	[ "${1:-}" = "--clear" ] && ssh "$SSH_HOST" "rm -f $dir/*"
done
for note in "$OUT"/*.json; do
	[ -e "$note" ] || { echo "no notes"; exit 0; }
	python3 -c 'import json,sys; n=json.load(open(sys.argv[1])); print(n["stamp"], n["verdict"].upper(), n["screen"], repr(n["title"]), "-", n["comment"])' "$note"
done
