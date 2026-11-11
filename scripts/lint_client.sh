#!/bin/sh
# lint_client.sh - fail when a Feature or UI file reaches around the stores.
#
# Views talk to the domain stores in src/Core/Stores, never to TGClient or one
# of its duty headers. The allow list is the migration queue: one current
# importer per line. Remove a line when that screen moves; never add one.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ALLOW="
"

allowed() {
	printf '%s\n' "$ALLOW" | grep -qx "$1"
}

hits=$(grep -rnE \
	'#import[[:space:]]+"(TGClient\.h|TGClient\+[^"]*\.h)"' \
	src/Features src/UI --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)

status=0
if [ -n "$hits" ]; then
	while IFS= read -r hit; do
		file=${hit%%:*}
		allowed "$file" && continue
		printf '%s\n' "$hit"
		status=1
	done <<EOF
$hits
EOF
fi

# The list only shrinks: a migrated file still listed is an error too.
for file in $ALLOW; do
	printf '%s\n' "$hits" | grep -q "^$file:" && continue
	echo "$file: migrated, remove it from the allow list"
	status=1
done

if [ "$status" -eq 0 ]; then
	echo "  client: clean (screens use the stores, remaining importers are listed)"
else
	printf '\n  A Feature or UI file imports TGClient directly:\n'
	printf '  %s\n\n' "ask the domain store in src/Core/Stores for what the screen needs"
fi
exit "$status"
