#!/bin/bash
# iPhone 4 / iOS 6.1.3 emulator (LightTouch over qemu-ios) for armv7 checks on a Mac.
#
#   scripts/emu.sh setup           build the emulator into ~/lt-emu and prepare the device (~5 min, once)
#   scripts/emu.sh test [SECONDS]  make ipa-armv7, install, open LegacyTG, report (default 240 s)
#   scripts/emu.sh install IPA     boot, install, shut down
#   scripts/emu.sh open [SECONDS]  boot, unlock, open LegacyTG, screenshots + syslog in ~/lt-emu/out
#   scripts/emu.sh prepare         (re)make the device from the IPSW; also the cure for "needs recovery"
#   scripts/emu.sh gui             the emulator window, by hand
#
# Covers the Vintage tier only (armv7, iOS 6): no arm64, no iOS 8-12, no timing. It does not
# replace the real-device check. Never kill a running session: the NAND is left dirty and the
# next boot hangs in recovery; --seconds always ends in a clean shutdown.
# LT_W moves the work folder (default ~/lt-emu).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W=${LT_W:-$HOME/lt-emu}
OUT=$W/out
EMU_REPO=https://github.com/1lifedo1thing/iOS-Emulator.git
EMU_COMMIT=ca5ac1f6afdcb4b051908ad59158b5bb7e6263ae      # vendors blake-lucas/LightTouch + qemu-ios
USBMUXD_REPO=https://github.com/samhenrigold/usbmuxd.git
USBMUXD_COMMIT=5cb90897479b9021a69db9698fea071ef7b2eceb  # LightTouch's pin (build-mobile-deps.py)
IPSW_URL=https://secure-appldnld.apple.com/iOS6.1/091-2610.20130319.Bedr4/iPhone3,1_6.1.3_10B329_Restore.ipsw
IPSW_SHA1=f8c53328656f2708e1d2bcb793f12ae46dd4eb23
IPSW=$W/iPhone3,1_6.1.3_10B329_Restore.ipsw

die() { echo "[-] $*" >&2; exit 1; }
# hw.optional.arm64, not uname: a shell under Rosetta says x86_64 on an M1.
arm_mac() { [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; }
env_() { arm_mac || die "Apple Silicon Mac only (upstream LightTouch builds its macOS engine for arm64)"
	[ -f "$W/env.sh" ] || die "emulator not built: scripts/emu.sh setup"; . "$W/env.sh"; }
# awk reads to the end: an early exit closes the pipe, lighttouch panics on the broken pipe
# and pipefail takes the whole script down with it.
dev_id() { lighttouch list | awk '/n90ap 10B329/ && !/needs recovery/ && !id {sub(/^\*/,"",$1); id=$1} END {print id}'; }

build() {
	arm_mac || die "Apple Silicon Mac only (upstream LightTouch builds its macOS engine for arm64)"
	mkdir -p "$W"
	# Only what is missing, and no upgrade of installed dependents: a plain `brew install`
	# went on to pull Qt, WebEngine and three JDKs.
	local need= p
	for p in ninja meson jq pkgconf glib pixman libslirp nettle openssl@3 libusb libimobiledevice \
		libplist libusbmuxd python@3.13 autoconf automake libtool; do
		brew list --versions "$p" >/dev/null || need+=" $p"
	done
	[ -z "$need" ] || HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 brew install $need
	command -v cargo >/dev/null || [ -x "$HOME/.cargo/bin/cargo" ] ||
		curl -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
	export PATH=$HOME/.cargo/bin:$PATH
	local py; py=$(brew --prefix python@3.13)/bin/python3.13

	local src=$W/src
	[ -d "$src/.git" ] || git clone -q "$EMU_REPO" "$src"
	git -C "$src" checkout -q --detach "$EMU_COMMIT"
	local q=$src/EXTERNAL/qemu-ios-main/qemu-ios-main l=$src/EXTERNAL/LightTouch-main/LightTouch-main
	# The repo is kept on Windows, so the exec bits are gone; configure and meson need them.
	find "$q" "$l" -type f \( -name '*.sh' -o -name '*.py' -o -name configure -o -path '*/scripts/*' \) -exec chmod +x {} +

	# --archive-revision: the chmod above counts as uncommitted changes to build-engine.py.
	[ -f "$W/engine/libqemu-arm.dylib" ] || { rm -rf "$W/engine"
		echo "[+] engine (~4 min)"
		"$py" "$l/macOS/build-engine.py" --qemu-source "$q" --output "$W/engine" --python "$py" \
			--openssl-prefix "$(brew --prefix openssl@3)" --jobs 2 --archive-revision "$EMU_COMMIT" \
			|| { tail -40 "$W"/engine/step-*.log; die "engine build failed, logs in $W/engine"; }; }

	echo "[+] lighttouch, firmwarekit"
	(cd "$l" && CARGO_TARGET_DIR=$W/cargo cargo build -q --release -p lighttouch -p lighttouch-firmware)

	# USB bridge for installs and syslog: the pinned fork with LightTouch's two patches, against
	# Homebrew's libimobiledevice (Linux builds its own stack; iOS 6 needs none of its iOS 1 SSL patch).
	local m=$W/mobile
	[ -x "$m/usbmuxd-qemu" ] || { echo "[+] usbmuxd-qemu"; mkdir -p "$m"
		[ -d "$m/usbmuxd-source" ] || git clone -q "$USBMUXD_REPO" "$m/usbmuxd-source"
		( cd "$m/usbmuxd-source" && git checkout -q --detach "$USBMUXD_COMMIT"
		  for p in usbmuxd-private-qemu-config usbmuxd-linux-standard-headers; do
			[ -f ".$p" ] || { patch -p1 < "$l/Linux/packaging/patches/$p.patch" && touch ".$p"; }
		  done
		  export PKG_CONFIG_PATH=$(brew --prefix)/lib/pkgconfig:$(brew --prefix openssl@3)/lib/pkgconfig
		  { NOCONFIGURE=1 ./autogen.sh && ./configure --without-systemd && make -j4; } > ../build.log 2>&1 ||
			{ tail -20 ../build.log; exit 1; } )
		cp "$m/usbmuxd-source/src/usbmuxd" "$m/usbmuxd-qemu"; }

	cat > "$W/env.sh" <<EOF
export LIGHTTOUCH_ENGINE=$W/engine/libqemu-arm.dylib
export LIGHTTOUCH_GUEST_TOOLS=$src/resources/guest-tools
export LIGHTTOUCH_FIRMWAREKIT=$W/cargo/release/firmwarekit
export LIGHTTOUCH_USBMUXD=$m/usbmuxd-qemu
export LIGHTTOUCH_DATA=$W/data
export PATH=$W/cargo/release:\$PATH
EOF
}

prepare() {
	env_
	[ -f "$IPSW" ] || { echo "[+] IPSW from Apple (940 MB)"; curl -L --fail -o "$IPSW.part" "$IPSW_URL" && mv "$IPSW.part" "$IPSW"; }
	echo "$IPSW_SHA1  $IPSW" | shasum -a 1 -c >/dev/null || die "IPSW checksum mismatch: delete $IPSW and retry"
	lighttouch prepare n90ap-10B329 --ipsw "$IPSW" --name iPhone4-613
}

install_() {
	env_; local id; id=$(dev_id); [ -n "$id" ] || die "no usable device: scripts/emu.sh prepare"
	mkdir -p "$OUT"
	lighttouch run "$id" --seconds 120 --no-audio --install "$1" > "$OUT/install.log" 2>&1 || true
	grep -E 'services: installed' "$OUT/install.log" || { tail -15 "$OUT/install.log"; die "install failed, $OUT/install.log"; }
}

open_() {
	env_; local secs=${1:-240} id; id=$(dev_id); [ -n "$id" ] || die "no usable device: scripts/emu.sh prepare"
	mkdir -p "$OUT"; rm -f "$OUT"/shot-* "$OUT/run.log" "$OUT/syslog.txt" "$OUT/.ended"
	# Timed input: unlock at 65 s, page 2 at 72 s, third icon (LegacyTG on a clean device) at 76 s.
	# Coordinates are 0..1 of the 640x960 screen.
	python3 -I - "$OUT" "$secs" > "$OUT/open.script" <<'EOF'
import json, sys
out, secs = sys.argv[1], int(sys.argv[2])
L = []
def touch(t, ph, x, y): L.append((t, {"cmd": "touch", "contacts": [{"id": 1, "phase": ph, "x": x, "y": y}]}))
L += [(62, {"cmd": "button", "button": 0, "down": True}), (62.2, {"cmd": "button", "button": 0, "down": False})]
touch(65, 0, 0.15, 0.89)
for i in range(1, 15): touch(65 + i * .05, 1, 0.15 + i * .05, 0.89)
touch(65.8, 2, 0.85, 0.89)
touch(72, 0, 0.85, 0.5)
for i in range(1, 12): touch(72 + i * .04, 1, 0.85 - i * .06, 0.5)
touch(72.5, 2, 0.2, 0.5)
touch(76, 0, 0.62, 0.125); touch(76.15, 2, 0.62, 0.125)
touch(95, 0, 0.20, 0.33); touch(95.15, 2, 0.20, 0.33)
for t in [68, 74, 90, 98, 105]:
	if t < secs - 5: L.append((t, {"cmd": "screenshot", "path": f"{out}/shot-{t:03d}.bmp"}))
for t, c in L: print(t, json.dumps(c))
EOF
	# Syslog over the run's own USB bridge (it prints "usb bridge at ..."); stopped when the run ends.
	( s=; for _ in $(seq 120); do
		s=$(grep -o '/[^ ]*/lighttouch-usb-[^ ]*/mux.sock' "$OUT/run.log" 2>/dev/null | head -1 || true)
		[ -n "$s" ] && break; sleep 1; done
	  [ -n "$s" ] || exit 0
	  for _ in $(seq 30); do sleep 5; USBMUXD_SOCKET_ADDRESS=UNIX:$s idevice_id -l | grep -q . && break; done
	  USBMUXD_SOCKET_ADDRESS=UNIX:$s idevicesyslog > "$OUT/syslog.txt" 2>&1 & p=$!
	  # .ended too: a run that dies without its "exit clean=" line left this waiting forever.
	  until grep -q 'exit clean=' "$OUT/run.log" || [ -f "$OUT/.ended" ]; do sleep 2; done
	  kill $p 2>/dev/null || true ) &
	echo "[+] running ${secs} s (boot ~50 s, LegacyTG opens at ~76 s)"
	lighttouch run "$id" --seconds "$secs" --no-audio --network direct --services --script "$OUT/open.script" > "$OUT/run.log" 2>&1 || true
	touch "$OUT/.ended"
	wait
	local f; for f in "$OUT"/shot-*.bmp; do [ -f "$f" ] && sips -s format png "$f" --out "${f%.bmp}.png" >/dev/null && rm "$f"; done
	grep -q 'exit clean=true' "$OUT/run.log" || echo "[!] session did not end clean, see $OUT/run.log"
}

report() {
	echo "--- LegacyTG"
	grep -E 'LegacyTG\[' "$OUT/syslog.txt" 2>/dev/null | grep -E 'AUTH STATE|connectionState|ERROR|signed in' | cut -c17- || echo "(no LegacyTG lines in syslog)"
	grep -E 'LegacyTG.*(crash|Terminating)|missing entitlement' "$OUT/syslog.txt" 2>/dev/null | cut -c17- || true
	echo "--- shots: $(ls "$OUT"/shot-*.png 2>/dev/null | wc -l | tr -d ' ') in $OUT, syslog $OUT/syslog.txt"
}

case "${1:-}" in
setup)   build; [ -n "$(env_; dev_id)" ] || prepare; echo "[+] emulator ready: scripts/emu.sh test" ;;
prepare) prepare ;;
install) [ -f "${2:-}" ] || die "usage: scripts/emu.sh install App.ipa"; install_ "$2" ;;
open)    open_ "${2:-240}"; report ;;
test)    echo "[+] make ipa-armv7"; make -C "$ROOT" -j"$(sysctl -n hw.logicalcpu)" ipa-armv7 > "$ROOT/build/emu-ipa.log" 2>&1 ||
		{ grep -m5 'error:' "$ROOT/build/emu-ipa.log"; die "build failed, build/emu-ipa.log"; }
	 install_ "$ROOT/build/ipa/LegacyTG-armv7.ipa"; open_ "${2:-240}"; report ;;
gui)     env_; lighttouch ;;
*)       sed -n 2,14p "$0"; exit 2 ;;
esac
