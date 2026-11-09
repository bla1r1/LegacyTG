#!/bin/sh
#
# lint_icons.sh - no feature draws its own icon.
#
# An icon is a path in TGIconPaths (scripts/icon_picks.txt), asked for by name.
# A function or method outside src/Views/Icons that returns a UIImage and builds
# a vector shape - CGContextMoveToPoint / AddLineToPoint / AddArc or
# UIBezierPath - is a second drawing of a glyph. The allow list below is the
# drawings that are not icons: button plates, bubbles, theme previews, the
# camera shutter, avatars and patterns. One per line, `path:function`.
#
# Usage: scripts/lint_icons.sh
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

ALLOW="
src/Core/Style/TGTheme+Drawing.m:skeuomorphicBarImageWithColor
src/Core/Style/TGTheme+Drawing.m:skeuomorphicButtonImageWithColor
src/Core/Style/TGTheme+Drawing.m:skeuomorphicWellImageWithHeight
src/Core/Style/TGTheme+Drawing.m:skeuomorphicSliderTrackImageFilled
src/Core/Style/TGTheme+Drawing.m:skeuomorphicSliderThumbWithRadius
src/Core/Style/TGTheme+Drawing.m:skeuomorphicSwitchTrackImageOn
src/Core/Style/TGTheme+Drawing.m:skeuomorphicSwitchThumbImage
src/Core/Style/TGTheme+Drawing.m:skeuomorphicInputBarImageWithHeight
src/Core/Style/TGTheme+Drawing.m:chromePlateImageWithColour
src/Features/Calls/TGCallViewController.m:TGCallCircleImage
src/Features/Calls/Views/TGCallMiniBar.m:TGCallCircleImage
src/Features/Chat/Composer/TGChatViewController+Media.m:mapCardForLatitude
src/Features/Chat/Rendering/TGChatViewController+Cells.m:TGBubbleBackImage
src/Features/Chat/Views/TGAttachSheet.m:tickForPosition
src/Features/Chat/Views/TGMessageCardView.m:TGRoundImage
src/Features/Profile/Core/TGProfileAvatars.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/Core/TGProfileData.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/Core/TGProfileDetails.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/Core/TGProfileHeader.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/Core/TGProfileLifecycle.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/Core/TGProfileTable.m:TGProfileCompositeSimilarAvatars
src/Features/Profile/TGProfileAppearanceViewController.m:TGAppearanceSwatch
src/Features/Profile/TGProfileAppearanceViewController.m:TGAppearanceAvatar
src/Features/Profile/TGProfileViewController+Actions.m:TGSolidImage
src/Features/Settings/TGBackgroundEditorViewController.m:swatchImageForPreset
src/Features/Settings/TGBackgroundsViewController.m:TGBackgroundThumbnail
src/UI/Rows/TGChatPreviewRowCell.m:TGAppearancePatternImage
src/UI/Rows/TGChatPreviewRowCell.m:TGAppearancePreviewImage
src/UI/Rows/TGThemeCardsRowCell.m:TGAppearancePatternImage
src/UI/Rows/TGThemeCardsRowCell.m:TGAppearanceThemeCardImage
src/UI/Rows/TGThemeCardsRowCell.m:TGThemeCardImage
src/Features/Settings/TGStorageViewController.m:dotOfColour
src/Features/Stories/TGStoryCameraViewController.m:TGStoryShutterImage
"

status=0
files=$(find src -type f \( -name '*.m' -o -name '*.mm' \) | sort)
for f in $files; do
	case "$f" in
		src/Views/Icons/*) continue ;;
	esac
	ALLOW="$ALLOW" awk -v file="$f" '
	function report(line, name) {
		if (index(ENVIRON["ALLOW"], "\n" file ":" name "\n") == 0) {
			printf "%s:%d: %s draws a glyph; add it to TGIconPaths and ask TGIcons\n", file, line, name
			bad = 1
		}
	}
	BEGIN { infunc = 0; depth = 0; pending = 0; violation = 0; bad = 0 }
	{
		line = $0
		if (!infunc) {
			name = ""
			if (match(line, /\(UIImage[ \t]*\*\)[ \t]*[A-Za-z_][A-Za-z0-9_]*/)) {
				s = substr(line, RSTART, RLENGTH)
				sub(/^\(UIImage[ \t]*\*\)[ \t]*/, "", s)
				name = s
			} else if (match(line, /UIImage[ \t]*\*[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
				s = substr(line, RSTART, RLENGTH)
				sub(/^UIImage[ \t]*\*[ \t]*/, "", s)
				sub(/[ \t]*\($/, "", s)
				name = s
			} else if (pending && match(line, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) {
				s = substr(line, RSTART, RLENGTH)
				sub(/[ \t]*\($/, "", s)
				sub(/^[ \t]*/, "", s)
				name = s
			}
			if (name != "") {
				infunc = 1
				depth = 0
				start = NR
				violation = 0
				pending = 0
			} else if (match(line, /UIImage[ \t]*\*/)) {
				pending = 1
			}
		}
		if (infunc) {
			if (line ~ /CGContextMoveToPoint|CGContextAddLineToPoint|CGContextAddArc|UIBezierPath/)
				violation = 1
			n = gsub(/\{/, "{", line)
			depth += n
			n = gsub(/\}/, "}", line)
			depth -= n
			if (depth <= 0 && (line ~ /\}/)) {
				if (violation)
					report(start, name)
				infunc = 0
			}
		}
	}
	END { exit bad ? 1 : 0 }
	' "$f" || status=1
done

if [ "$status" -ne 0 ]; then
	echo "lint_icons: feature files still draw glyphs" >&2
else
	echo "lint_icons: every glyph comes from TGIconPaths"
fi
exit "$status"
