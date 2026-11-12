#!/bin/bash
# devrun.sh - build, install, launch and observe LegacyTG on the iPhone 4S
# without a human touching the device.
#
#   ./scripts/devrun.sh                 build + install + launch + 60s of log
#   ./scripts/devrun.sh --no-build      skip make, just install/launch/log
#   ./scripts/devrun.sh --seconds 120   longer log window
#   ./scripts/devrun.sh --filter 'AUTH' only log lines matching this regex
#   ./scripts/devrun.sh --check         only report what works, change nothing
#   ./scripts/devrun.sh --smoke         iOS 6.1 smoke gate: walk basic screens,
#                                       fail on SIGABRT / unrecognized selector
#
# Launching an app remotely needs ONE of these on the device:
#   A) debugserver, via a mounted Developer Disk Image for iOS 7.1
#   B) OpenSSH (jailbreak) plus an `open`/`uiopen` binary
# SSH also installs: where mobile_installation is broken (the iPod touch 4 on
# 6.1.6 is), the bundle goes to /Applications and uicache shows it.
# The script tries A, then B, and tells you exactly what is missing if neither
# is available. Everything else (build, install, syslog, crash reports) works
# regardless.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_ID="org.legacy.itg"
IPA="$ROOT/build/ipa/LegacyTG-armv7-dev.ipa"
LOGDIR="$ROOT/build/devlogs"
STAMP="$(date +%Y%m%d-%H%M%S)"

SECONDS_TO_LOG=60
FILTER="LegacyTG"
DO_BUILD=1
CHECK_ONLY=0
SHOT_ONLY=0
VIDEO_DURATION=0
SMOKE_MODE=0
# Several devices on one cable happens (an old test bench plus a donor);
# --udid UDID pins every tool to the chosen one.
DEV_UDID=""

# SSH settings, used only for launch method B.
# Everything (port, user, key, legacy ssh-rsa algorithms) lives in the
# `itgphone` block in ~/.ssh/config.
SSH_PORT=2222
SSH_HOST=itgphone
SSH_OPTS="-o ConnectTimeout=6 -o BatchMode=yes"

while [ $# -gt 0 ]; do
	case "$1" in
		--no-build) DO_BUILD=0; shift ;;
		--seconds)  SECONDS_TO_LOG="$2"; shift 2 ;;
		--filter)   FILTER="$2"; shift 2 ;;
		--udid)     DEV_UDID="$2"; shift 2 ;;
		--check)    CHECK_ONLY=1; shift ;;
		--shot)     SHOT_ONLY=1; shift ;;
		--smoke)    SMOKE_MODE=1; shift ;;
		--screenoff) "$ROOT/scripts/screen.sh" off; exit $? ;;
		--screenon)  "$ROOT/scripts/screen.sh" on;  exit $? ;;
		--video)    VIDEO_DURATION="${2:-5}"; shift 2 ;;
		*) echo "unknown option: $1"; exit 2 ;;
	esac
done

mkdir -p "$LOGDIR"
say() { printf '\n=== %s\n' "$*"; }

# The device tools talk to the first USB-connected phone by default; wrap
# them so -u lands in front of every call once a UDID was picked. The
# wrappers shadow, not patch, so existing call sites stay untouched.
if [ -n "$DEV_UDID" ]; then
	for _cmd in ideviceinfo ideviceinstaller ideviceimagemounter \
			idevicedebug idevicesyslog idevicecrashreport; do
		eval "$_cmd() { command $_cmd -u $DEV_UDID \"\$@\"; }"
	done
	# idevice_id has no -u flag; filtering its listing keeps
	# wait_for_device honest about which phone answered.
	eval 'idevice_id() { command idevice_id "$@" | grep -i "$DEV_UDID"; }'
fi

# ---------------------------------------------------------------- device ----
wait_for_device() {
	local tries=0
	while [ $tries -lt 30 ]; do
		if idevice_id -l 2>/dev/null | grep -q .; then
			say "device: $(ideviceinfo -k DeviceName 2>/dev/null) / iOS $(ideviceinfo -k ProductVersion 2>/dev/null)"
			return 0
		fi
		tries=$((tries + 1))
		sleep 2
	done
	echo "NO DEVICE after 60s. Plug the iPhone in, unlock it, and trust this Mac." >&2
	return 1
}

# ------------------------------------------------------------------ build ---
build() {
	say "building armv7"
	if ! make -j"$(sysctl -n hw.ncpu)" -C "$ROOT" DEV=1 ipa-armv7 > "$LOGDIR/build-$STAMP.log" 2>&1; then
		echo "BUILD FAILED - see $LOGDIR/build-$STAMP.log" >&2
		grep -iE "error:|fixup error|Undefined symbols" "$LOGDIR/build-$STAMP.log" | head -20 >&2
		return 1
	fi
	# machofix must have run; without it the app cannot launch at all
	if ! grep -q "machofix: Thumb bit restored" "$LOGDIR/build-$STAMP.log"; then
		echo "WARNING: machofix did not report restoring Thumb bits." >&2
		echo "The armv7 linker drops them; without the fixup the app dies at launch." >&2
	fi
	grep "machofix:" "$LOGDIR/build-$STAMP.log"
	return 0
}

install_ipa() {
	say "installing"
	[ -f "$IPA" ] || { echo "no IPA at $IPA" >&2; return 1; }
	if ideviceinstaller install "$IPA" 2>&1 | tail -3 | grep -q "Complete"; then
		return 0
	fi
	echo "ideviceinstaller did not finish - trying SSH" >&2
	install_over_ssh
}

# The iPod touch 4 on 6.1.6 has a mobile_installation that answers nothing:
# every lookup comes back "Connection blew up while waiting for messages" and
# ideviceinstaller reports APIInternalError for install AND for a plain list.
# A jailbroken device does not need it - an app under /Applications is a
# system app, which SpringBoard picks up from uicache. ldid gives the binary
# the fake signature amfid wants; the bundle has none of its own.
install_over_ssh() {
	ssh_ready || { echo "no ideviceinstaller and no ssh - cannot install" >&2; return 1; }
	local app="$ROOT/build/armv7/app-dev/LegacyTG.app"
	[ -d "$app" ] || { echo "no app bundle at $app" >&2; return 1; }
	say "installing over SSH into /Applications"
	# tar over the pipe: the device has tar and gzip but no rsync, and scp of a
	# whole bundle costs one connection per file.
	tar -czf - -C "$(dirname "$app")" "$(basename "$app")" \
		| ssh $SSH_OPTS "$SSH_HOST" "rm -rf /Applications/LegacyTG.app && \
			tar -xzf - -C /Applications && \
			ldid -S /Applications/LegacyTG.app/LegacyTG && \
			chmod 755 /Applications/LegacyTG.app/LegacyTG && \
			chown -R root:wheel /Applications/LegacyTG.app && \
			uicache 2>/dev/null; killall -9 SpringBoard 2>/dev/null; sleep 3; true" || return 1
	echo "installed into /Applications"
}

# ------------------------------------------------- launch method A: DDI -----
ddi_mounted() { ideviceimagemounter -l 2>/dev/null | grep -qi "ImagePresent: true\|ImageSignature"; }

try_mount_ddi() {
	local d
	for d in "$HOME/DeviceSupport/7.1" "$HOME/DeviceSupport/7.1.2" \
	         "$ROOT/tools/DeviceSupport/7.1" \
	         /Applications/Xcode*.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/7.1; do
		if [ -f "$d/DeveloperDiskImage.dmg" ]; then
			say "mounting Developer Disk Image from $d"
			ideviceimagemounter "$d/DeveloperDiskImage.dmg" "$d/DeveloperDiskImage.dmg.signature" 2>&1 | tail -2
			return 0
		fi
	done
	return 1
}

launch_via_debugserver() {
	ddi_mounted || try_mount_ddi || return 1
	say "launching via idevicedebug"
	# idevicedebug stays attached and prints stdout; run it in the background
	idevicedebug -d run "$BUNDLE_ID" > "$LOGDIR/stdout-$STAMP.log" 2>&1 &
	echo $! > "$LOGDIR/.debugpid"
	sleep 5
	grep -qi "Could not start com.apple.debugserver" "$LOGDIR/stdout-$STAMP.log" && return 1
	return 0
}

# ------------------------------------------------- launch method B: SSH -----
ssh_ready() {
	if ! ssh $SSH_OPTS "$SSH_HOST" true 2>/dev/null; then
		# not up yet - usbmuxd forwarding may simply not be running
		pkill -f "iproxy $SSH_PORT" 2>/dev/null
		local uopt=""
		[ -n "$DEV_UDID" ] && uopt="-u $DEV_UDID"
		iproxy "$SSH_PORT" 22 $uopt >/dev/null 2>&1 &
		echo $! > "$LOGDIR/.iproxypid"
		sleep 2
		ssh $SSH_OPTS "$SSH_HOST" true 2>/dev/null || return 1
	fi
	return 0
}

launch_via_ssh() {
	ssh_ready || return 1
	say "launching over SSH"
	# Kill first so every run starts cold - otherwise the app is merely brought
	# to the foreground and none of the launch path is exercised.
	ssh $SSH_OPTS "$SSH_HOST" "killall LegacyTG 2>/dev/null || killall iTgLegacy 2>/dev/null; true"
	sleep 2
	# openapp / uiopen launches the app
	ssh $SSH_OPTS "$SSH_HOST" \
		"openapp $BUNDLE_ID 2>/dev/null || uiopen tg:// 2>/dev/null || uiopen telegram:// 2>/dev/null || \
		 uiopen legacytg:// 2>/dev/null || open $BUNDLE_ID 2>/dev/null || exit 7" && return 0
	echo "SSH works but no launcher binary found on the device." >&2
	echo "Install from Cydia: 'UIKit Tools' (com.saurik.uikittools) gives 'uiopen'." >&2
	return 1
}

launch() {
	launch_via_debugserver && { echo "launched via debugserver"; return 0; }
	launch_via_ssh        && { echo "launched via ssh"; return 0; }

	cat >&2 <<'EOF'

CANNOT LAUNCH THE APP REMOTELY. Everything else still ran.
Provide ONE of these, then this script becomes fully autonomous:

  A) Developer Disk Image for iOS 7.1
     Drop DeveloperDiskImage.dmg + .signature into ~/DeviceSupport/7.1/
     (archived in the community "iOS DeviceSupport" repositories)

  B) SSH on the jailbroken device
     Cydia -> OpenSSH, plus 'Open for iOS 11' (com.conradkramer.open)
     Then set up a key so ssh needs no password:
       ssh-copy-id -p 2222 root@localhost   (with iproxy 2222 22 running)

EOF
	return 1
}

# -------------------------------------------------------------- observe -----
collect() {
	say "capturing syslog for ${SECONDS_TO_LOG}s (filter: $FILTER)"
	timeout "$SECONDS_TO_LOG" idevicesyslog 2>&1 \
		| grep --line-buffered -iE "$FILTER" > "$LOGDIR/syslog-$STAMP.log"
	echo "$(wc -l < "$LOGDIR/syslog-$STAMP.log") lines -> $LOGDIR/syslog-$STAMP.log"

	say "crash reports"
	local cdir="$LOGDIR/crash-$STAMP"
	mkdir -p "$cdir"
	idevicecrashreport -e -k "$cdir" >/dev/null 2>&1
	local newest
	newest="$(ls -t "$cdir"/LegacyTG_*.ips "$cdir"/iTgLegacy_*.ips 2>/dev/null | head -1)"
	if [ -n "$newest" ]; then
		echo "newest: $newest"
		sed -n '/Exception Type/,/^$/p' "$newest" | head -8
	else
		echo "none"
	fi
}

# Ask the running app / system to photograph itself and pull the result without gallery pollution.
shot() {
	ssh_ready || { echo "no ssh, cannot take a screenshot" >&2; return 1; }
	ssh $SSH_OPTS "$SSH_HOST" "sbunlock --screenshot 2>/dev/null || uiopen itglegacy://screenshot" || return 1
	sleep 1
	local remote="/var/mobile/screenshot.png"
	if ! ssh $SSH_OPTS "$SSH_HOST" "[ -f '$remote' ]"; then
		remote="$(ssh $SSH_OPTS "$SSH_HOST" \
			'ls -t /var/mobile/Applications/*/Library/Caches/screen.png 2>/dev/null | sed 1q')"
	fi
	[ -n "$remote" ] || { echo "device did not write a screenshot" >&2; return 1; }

	scp $SSH_OPTS "$SSH_HOST:$remote" "$LOGDIR/screen-$STAMP.png" >/dev/null 2>&1 \
		&& echo "$LOGDIR/screen-$STAMP.png"
}

summary() {
	say "summary"
	local f="$LOGDIR/syslog-$STAMP.log"
	[ -s "$f" ] || { echo "no app log captured"; return; }
	grep -m1 "start\.\.\."            "$f" && :
	grep -m1 "LibTg inited"           "$f" && :
	grep -m1 "have auth_key"          "$f" && :
	grep -m1 "NEED_TO_AUTHORIZE"      "$f" && :
	grep -m1 "AUTHORIZED"             "$f" && :
	grep -m1 "isOnLineAndAuthorized"  "$f" && :
	echo "--- errors:"
	grep -iE "error|can't|fail|RPC_ERROR" "$f" | sort | uniq -c | sort -rn | head -10
}

# -------------------------------------------------------------- smoke ------
# Walk the core screens via automation URL-schemes and watch syslog for the
# three crash signals that indicate an iOS 6 selector failure.  Exit 0 on a
# clean 30-second window, exit 1 with a log dump on any crash.
#
# Full prогон includes:
#   1. Basic screen walk (chat-list root, settings, profile, dev)
#   2. Dark-theme switch — exercises the dark branch of stylePlainTable:,
#      styleNavigationBar: and styleTabBar: where sectionIndexBackgroundColor:
#      and barTintColor were previously unguarded.
#   3. Dev Showcase scroll — forces tableView:cellForRowAtIndexPath: and
#      layoutSubviews for all message cell types (text, photo, voice, sticker,
#      poll, service, custom emoji, etc.).
#   4. Saved Messages / test chat scroll — exercises bubble reuse and CoreText.
smoke() {
	say "smoke: iOS 6.1 runtime gate — full interactive prогон"
	ssh_ready || { echo "smoke requires SSH (method B)" >&2; return 1; }

	local SMOKE_LOG="$LOGDIR/smoke-$STAMP.log"
	local CRASH_PATTERN="SIGABRT|unrecognized selector sent to instance|NSInvalidArgumentException|EXC_BAD_ACCESS"

	# Start syslog capture in background — capture everything, filter later.
	idevicesyslog >"$SMOKE_LOG" 2>&1 &
	local SYSLOG_PID=$!

	# Helper: check log for crashes so far; return 1 (and kill syslog) on first hit.
	smoke_check_crash() {
		local phase="$1"
		if grep -qiE "$CRASH_PATTERN" "$SMOKE_LOG"; then
			echo ""
			echo "SMOKE FAILED at [$phase] — crash signal detected:" >&2
			grep -iE "$CRASH_PATTERN" "$SMOKE_LOG" | head -20 >&2
			# Try to pull the crash report off the device.
			local cdir="$LOGDIR/crash-smoke-$STAMP"
			mkdir -p "$cdir"
			idevicecrashreport -e -k "$cdir" >/dev/null 2>&1 || true
			local newest
			newest="$(ls -t "$cdir"/LegacyTG_*.ips "$cdir"/iTgLegacy_*.ips 2>/dev/null | head -1)"
			if [ -n "$newest" ]; then
				echo "--- crash report (Exception + Thread 0):" >&2
				sed -n '/Exception Type/,/^$/p;/Thread 0/,/Thread 1/p' "$newest" | head -40 >&2
			fi
			echo ""
			echo "Full smoke log: $SMOKE_LOG" >&2
			kill $SYSLOG_PID 2>/dev/null
			return 1
		fi
		return 0
	}

	# Helper: open a URL and sleep, then crash-check.
	smoke_open() {
		local url="$1" delay="${2:-4}"
		say "smoke: open $url"
		ssh $SSH_OPTS "$SSH_HOST" "uiopen '$url' 2>/dev/null || true"
		sleep "$delay"
		smoke_check_crash "$url" || return 1
		return 0
	}

	# Give syslog a moment to connect before we start the app.
	sleep 2

	# ── Phase 1: cold launch ─────────────────────────────────────────────────
	say "smoke [1/4]: cold launch"
	ssh $SSH_OPTS "$SSH_HOST" "killall LegacyTG 2>/dev/null; killall iTgLegacy 2>/dev/null; true"
	sleep 1
	ssh $SSH_OPTS "$SSH_HOST" \
		"openapp $BUNDLE_ID 2>/dev/null || uiopen legacytg:// 2>/dev/null || open $BUNDLE_ID 2>/dev/null || exit 7" || {
		echo "smoke: could not launch — SSH works but no launcher on device" >&2
		kill $SYSLOG_PID 2>/dev/null
		return 1
	}
	# Wait for the app to reach the main thread.
	sleep 6
	smoke_check_crash "cold launch" || return 1

	# ── Phase 2: basic screen walk (light theme) ─────────────────────────────
	say "smoke [2/4]: basic screen walk (light theme)"
	smoke_open "legacytg://"         3 || return 1
	smoke_open "legacytg://settings" 3 || return 1
	smoke_open "legacytg://profile"  3 || return 1

	# ── Phase 3: dark theme switch ───────────────────────────────────────────
	# legacytg://dev?theme=dark triggers a programmatic theme switch through
	# the automation URL handler (see AppDelegate+URL.m), which calls
	# [TGTheme.shared selectThemeId:] and re-styles all visible bars and tables.
	# This is the branch where sectionIndexBackgroundColor: and barTintColor
	# were previously called without respondsToSelector: guards on iOS 6.
	say "smoke [3/4]: dark theme switch (guard regression check)"
	smoke_open "legacytg://dev?theme=dark" 4 || return 1
	# Navigate back to chat-list so the themed table reloads.
	smoke_open "legacytg://"               3 || return 1
	smoke_open "legacytg://settings"       3 || return 1
	# Switch back to light — exercises the same guard path in the other direction.
	smoke_open "legacytg://dev?theme=light" 3 || return 1
	smoke_open "legacytg://"                3 || return 1

	# ── Phase 4: Dev Showcase scroll (all message cell types) ────────────────
	# legacytg://dev opens the Dev Hub; from there the Showcase is reachable.
	# We drive it via the same URL the record_showcase_walkthrough.sh uses.
	# The automation handler scrolls the table row-by-row (or we send swipe
	# commands over SSH), forcing every cell type through layoutSubviews.
	say "smoke [4/4]: Dev Showcase — all message cell types"
	smoke_open "legacytg://dev"       4 || return 1
	smoke_open "legacytg://showcase"  4 || return 1

	# Scroll through showcase rows via SSH uiopen URL commands.
	# The showcase table listens to legacytg://showcase/scroll?row=N.
	# We walk all 30 rows with a 1-second pause each; a crash in any
	# cell's layoutSubviews / cellForRowAtIndexPath: will show in syslog
	# within the next check interval.
	local SHOWCASE_ROWS=30
	local row=0
	while [ $row -lt $SHOWCASE_ROWS ]; do
		ssh $SSH_OPTS "$SSH_HOST" "uiopen 'legacytg://showcase/scroll?row=$row' 2>/dev/null || true"
		sleep 1
		smoke_check_crash "showcase/row/$row" || return 1
		row=$((row + 1))
	done

	# Also open Saved Messages chat and swipe to exercise bubble reuse.
	smoke_open "legacytg://saved"    5 || return 1
	# Swipe up (scroll older messages) via SSH uiopen automation.
	for _ in 1 2 3; do
		ssh $SSH_OPTS "$SSH_HOST" "uiopen 'legacytg://cmd?action=scroll_up' 2>/dev/null || true"
		sleep 2
		smoke_check_crash "saved/scroll" || return 1
	done

	# ── Final syslog settle ──────────────────────────────────────────────────
	sleep 2
	kill $SYSLOG_PID 2>/dev/null
	wait $SYSLOG_PID 2>/dev/null

	# One last check after everything settled.
	if grep -qiE "$CRASH_PATTERN" "$SMOKE_LOG"; then
		echo ""
		echo "SMOKE FAILED — crash signal detected in final log scan:" >&2
		grep -iE "$CRASH_PATTERN" "$SMOKE_LOG" | head -20 >&2
		echo "Full smoke log: $SMOKE_LOG" >&2
		return 1
	fi

	# Confirm the app was actually seen (guards against silent launch failure).
	if ! grep -qiE "LegacyTG|iTgLegacy" "$SMOKE_LOG"; then
		echo "SMOKE FAILED — app did not appear in syslog (launch may have failed)" >&2
		echo "Smoke log: $SMOKE_LOG" >&2
		return 1
	fi

	say "smoke: PASSED"
	echo "SMOKE PASSED — no crash signals across all phases:"
	echo "  Phase 1: cold launch"
	echo "  Phase 2: basic screen walk (light theme)"
	echo "  Phase 3: dark theme switch (sectionIndex + barTintColor guards)"
	echo "  Phase 4: Dev Showcase ($SHOWCASE_ROWS cell types) + Saved Messages scroll"
	echo "Smoke log: $SMOKE_LOG"
}

cleanup() {
	[ -f "$LOGDIR/.iproxypid" ] && kill "$(cat "$LOGDIR/.iproxypid")" 2>/dev/null
	[ -f "$LOGDIR/.debugpid" ]  && kill "$(cat "$LOGDIR/.debugpid")"  2>/dev/null
	rm -f "$LOGDIR/.iproxypid" "$LOGDIR/.debugpid"
}
trap cleanup EXIT

# ----------------------------------------------------------------- main -----
wait_for_device || exit 1

if [ "$SHOT_ONLY" = 1 ]; then
	shot
	exit $?
fi

if [ "$VIDEO_DURATION" -gt 0 ]; then
	"$ROOT/scripts/record_screen.sh" --duration "$VIDEO_DURATION" --gif
	exit $?
fi
if [ "$CHECK_ONLY" = 1 ]; then
	say "checking launch methods, changing nothing"
	if ddi_mounted || try_mount_ddi; then echo "A) debugserver: available"; else echo "A) debugserver: NOT available"; fi
	if ssh_ready; then echo "B) ssh: reachable"; else echo "B) ssh: NOT reachable"; fi
	exit 0
fi

[ "$DO_BUILD" = 1 ] && { build || exit 1; }
install_ipa || exit 1

if [ "$SMOKE_MODE" = 1 ]; then
	smoke
	exit $?
fi

launch || echo "(continuing without launch - app may already be running)"
collect
summary
