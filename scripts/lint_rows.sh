#!/bin/sh
# lint_rows.sh - fail when a Feature screen builds its own table cell.
#
# A row is data and TGRowCell renders it. The allow list is the migration
# queue: one file per line, every one a screen that still creates or dequeues
# a UITableViewCell or paints textLabel/detailTextLabel itself. Remove a line
# when the screen moves to TGRowsViewController; never add one.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ALLOW="

"

allowed() {
	printf '%s\n' "$ALLOW" | grep -qx "$1"
}

hits=$(grep -rnE \
	'\[\[[A-Za-z_][A-Za-z0-9_]*Cell alloc\]|\[[A-Za-z_][A-Za-z0-9_]*Cell (cellWithStyle|cellWith)|dequeueReusableCellWithIdentifier|textLabel\.(font|textColor)|detailTextLabel\.(font|textColor)' \
	src/Features --include='*.m' --include='*.mm' --include='*.h' \
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

# The list only shrinks: a migrated screen still listed is an error too.
for file in $ALLOW; do
	printf '%s\n' "$hits" | grep -q "^$file:" && continue
	echo "$file: migrated, remove it from the allow list"
	status=1
done

if [ "$status" -eq 0 ]; then
	echo "  rows: clean (no cell building in src/Features)"
else
	printf '\n  A Feature screen builds its own table cell:\n'
	printf '  %s\n\n' "describe rows with TGRows and let TGRowCell/TGRowsViewController render them"
fi
exit "$status"
