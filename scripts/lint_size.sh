#!/bin/sh
# lint_size.sh - fail when a source file grows into a mastodon.
#
# A source file over 1800 lines is split by responsibility. There is no
# baseline and no allowlist: if it crosses the limit, split it.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
MAX=1800
status=0

fail() {
	printf '\n  %s\n  %s\n\n' "$1" "$2"
	status=1
}

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

find src -type f \( -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \) > "$tmp"
while read -r path; do
	lines=$(wc -l < "$path" | tr -d ' ')
	[ "$lines" -gt "$MAX" ] || continue
	fail "$path is $lines lines (limit $MAX)" \
		"split it by responsibility; main type outside, parts in a thematic subfolder"
done < "$tmp"

if [ "$status" -eq 0 ]; then
	echo "  file sizes: clean (limit $MAX)"
fi
exit "$status"
