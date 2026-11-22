#!/bin/sh
# lint_ui_ownership.sh controls|presents [--update]
#
# Who may build UI in src/Features, checked against scripts/ui_ownership.txt.
#
#   controls  labels, buttons, fields, switches, segmented controls, sliders,
#             spinners and hand-rolled animations. A screen describes itself
#             and src/UI draws it; only a `canvas` file (chat, viewer, player,
#             camera, call, login) draws its own picture.
#   presents  how things open: modals, navigation controllers, bar buttons,
#             system alerts and sheets. Canvases too: they take the shared
#             bar, menus and modals like every other screen.
#
# The table holds the count each listed file still has. A file not in it must
# have none. A count may only fall: a file above its number fails, and so does
# one below it, so the table never keeps room for a new hit. --update lowers
# the numbers to what is there now and drops queue files that reached zero; it
# never raises a number or adds a file.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
TABLE=scripts/ui_ownership.txt

MODE=${1:-}
case "$MODE" in
controls)
	COL=2
	WHAT="builds its own controls or animations"
	FIX="describe it with TGRows/TGRowsViewController, or add the piece to src/UI and call that"
	PATTERN='\[(UILabel|UITextField|UITextView|UISwitch|UISegmentedControl|UISlider|UIStepper|UIActivityIndicatorView|UIButton) alloc\]|\[UIButton buttonWithType:|\[UIView (animateWithDuration|transitionWithView|transitionFromView)'
	;;
presents)
	COL=3
	WHAT="opens things its own way"
	FIX="bar buttons from TGBarItem by role, modals, menus and system pickers through TGPresent, alerts through TGAlertSheet, bottom sheets through TGSheet (src/UI/Controllers/TGPresent.h has the table)"
	PATTERN='presentViewController:|presentModalViewController:|\[(UINavigationController|UIBarButtonItem|UIActionSheet|UIAlertView|UIPopoverController) alloc\]|\[UIAlertController alertControllerWithTitle:'
	;;
*)
	echo "usage: $0 controls|presents [--update]" >&2
	exit 2
	;;
esac
UPDATE=0
[ "${2:-}" = "--update" ] && UPDATE=1

# file<TAB>count for every Feature source with a hit, comment lines skipped.
actual=$(find src/Features -name '*.m' -o -name '*.mm' -o -name '*.h' | sort | while IFS= read -r f; do
	n=$(grep -vE '^[[:space:]]*(//|\*|/\*)' "$f" | grep -oE "$PATTERN" | wc -l | tr -d ' ')
	[ "$n" -gt 0 ] && printf '%s\t%s\n' "$f" "$n"
done)

count_of() { printf '%s\n' "$actual" | awk -F'\t' -v f="$1" '$1 == f { print $2; found=1 } END { if (!found) print 0 }'; }

status=0
tmp=$(mktemp)
# Table rows: kind controls presents file [reason...]
while IFS= read -r line; do
	case "$line" in ''|'#'*) printf '%s\n' "$line" >>"$tmp"; continue ;; esac
	set -- $line
	kind=$1 file=$4
	listed=$(eval "echo \${$COL}")
	if [ ! -f "$file" ]; then
		echo "$TABLE: $file does not exist, remove its line"
		status=1
		continue
	fi
	if [ "$listed" = "-" ]; then
		if [ "$kind" != canvas ]; then
			echo "$TABLE: $file: '-' is for a canvas's controls only"
			status=1
		fi
		printf '%s\n' "$line" >>"$tmp"
		continue
	fi
	have=$(count_of "$file")
	if [ "$have" -gt "$listed" ]; then
		echo "$file: $have hits, the table allows $listed - it $WHAT"
		status=1
	elif [ "$have" -lt "$listed" ]; then
		if [ "$UPDATE" -eq 1 ]; then
			line=$(printf '%s\n' "$line" | awk -v c="$COL" -v n="$have" '{
				$c = n
				printf "%-7s%9s%9s  %s", $1, $2, $3, $4
				for (i = 5; i <= NF; i++) printf "%s%s", (i == 5 ? "  " : " "), $i
				print ""
			}')
		else
			echo "$file: down to $have from $listed, lower its number ($0 $MODE --update)"
			status=1
		fi
	fi
	printf '%s\n' "$line" >>"$tmp"
done <"$TABLE"

if [ "$UPDATE" -eq 1 ]; then
	# A queue file with nothing left on either column is done.
	awk '/^queue/ && $2 == "0" && $3 == "0" { next } { print }' "$tmp" >"$TABLE"
fi
rm -f "$tmp"

# Files with hits that the table does not list at all.
unlisted=$(printf '%s\n' "$actual" | while IFS="$(printf '\t')" read -r file n; do
	[ -n "$file" ] || continue
	awk -v f="$file" '$4 == f { found=1 } END { exit !found }' "$TABLE" && continue
	echo "$file: $n hits and no line in $TABLE - it $WHAT"
done)
if [ -n "$unlisted" ]; then
	printf '%s\n' "$unlisted"
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "  ui $MODE: clean against $TABLE"
else
	printf '\n  A Feature file %s:\n  %s\n\n' "$WHAT" "$FIX"
fi
exit "$status"
