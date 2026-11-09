#!/bin/sh
# lint_screens.sh - fail when a Feature screen owns a table instead of rows.
#
# A screen describes rows and a TGRowsViewController renders them. The allow
# list is the migration queue: one file per line, every one a screen that still
# subclasses UITableViewController/TGTableViewController/TGListViewController
# directly or implements tableView:cellForRowAtIndexPath: itself. Remove a
# line when the screen moves to TGRowsViewController; never add one.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ALLOW="
src/Features/Chat/Rendering/TGChatViewController+Cells.m
src/Features/ChatList/Core/TGChatListTable.m
src/Features/ChatList/TGChatListViewController.h
src/Features/Profile/TGProfileAppearanceViewController.m
src/Features/Settings/TGStorageViewController.m
"

allowed() {
	printf '%s\n' "$ALLOW" | grep -qx "$1"
}

# A class that owns the table. "Directly" means the superclass is one of the
# three, so a TGRowsViewController subclass is not a hit.
subclass_hits=$(grep -rnE \
	'^[[:space:]]*@interface[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*(UITableViewController|TGTableViewController|TGListViewController)([[:space:]]|$)' \
	src/Features --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)

# The method implementation. Its selector may wrap onto the next line, so the
# hit is the signature line, not the call sites elsewhere.
cell_hits=$(grep -rnE \
	'^[[:space:]]*-[[:space:]]*\(UITableViewCell[[:space:]]*\*\)[[:space:]]*tableView:' \
	src/Features --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)

hits=$(printf '%s\n%s\n' "$subclass_hits" "$cell_hits" | sed '/^$/d')

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
	echo "  screens: clean (no Feature screen owns a table)"
else
	printf '\n  A Feature screen still owns its table:\n'
	printf '  %s\n\n' "describe rows with TGRows and subclass TGRowsViewController"
fi
exit "$status"
