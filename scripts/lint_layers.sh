#!/bin/sh
# lint_layers.sh - the dependency direction the core is allowed to have.
#
#   Features/UI -> Stores -> Client -> TDLib
#
# A screen may ask a store; a store may ask the client; the client is the only
# layer that talks to TDLib. Anything pointing the other way is a layering bug.
#
# The seven client files below still forward a handful of message requests to
# TGSendStore/TGMessageStore. They are listed as debt, not as an accepted
# direction: the list may shrink, never grow.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

status=0

# 1. A screen must not reach the transport.
hits=$(grep -rnE '#import[[:space:]]+"(TGClient\.h|TGClient\+[^"]*\.h)"' \
	src/Features src/UI --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)
if [ -n "$hits" ]; then
	printf '%s\n' "$hits"
	echo "  Features/UI must import a store, not TGClient"
	status=1
fi

# 2. Core must not reach into a feature screen.
hits=$(grep -rnE '#import[[:space:]]+"TG[A-Za-z0-9_]*(ViewController|View|Cell)\.h"' \
	src/Core --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)
if [ -n "$hits" ]; then
	printf '%s\n' "$hits"
	echo "  Core must not import a feature view"
	status=1
fi

# 3. Store headers are the portable contract: no UIKit, AVFoundation or
#    MediaPlayer. Implementations may use the platform, headers may not.
hits=$(grep -lE '#import[[:space:]]+<(UIKit|AVFoundation|MediaPlayer)/' \
	src/Core/Stores/*.h 2>/dev/null || true)
if [ -n "$hits" ]; then
	printf '%s\n' "$hits"
	echo "  store headers must not import UIKit/AVFoundation/MediaPlayer"
	status=1
fi

# 4. The transport must not call a store.
hits=$(grep -rn '#import[[:space:]]\+"TG[A-Za-z0-9_]*Store[^"]*\.h"' \
	src/Core/Client --include='*.m' --include='*.mm' --include='*.h' || true)
if [ -n "$hits" ]; then
	printf '%s\n' "$hits"
	echo "  Client must not import a store"
	status=1
fi

# 5. A store must not import a feature header.
hits=$(grep -rnE '#import[[:space:]]+"TG[A-Za-z0-9_]*(ViewController|View|Cell)\.h"' \
	src/Core/Stores --include='*.m' --include='*.mm' --include='*.h' \
	| grep -vE ':[[:space:]]*(//|\*|/\*)' || true)
if [ -n "$hits" ]; then
	printf '%s\n' "$hits"
	echo "  Stores must not import a feature view"
	status=1
fi

if [ "$status" -eq 0 ]; then
	echo "  layers: clean (Features/UI -> Stores -> Client -> TDLib)"
fi
exit "$status"
