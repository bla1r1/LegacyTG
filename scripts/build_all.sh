#!/bin/bash
# Everything from an empty build/ to the three release IPAs and their SHA-256.
#
#   scripts/build_all.sh           release IPAs (DEV=0)
#   scripts/build_all.sh --deps    dependencies only, no app
#
# Needs Xcode and: brew install cmake gperf ccache ldid llvm
# Each step is skipped when its output already exists; delete that output
# (or all of build/) to redo it. A cold run is roughly 30-60 min, TDLib twice.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/scripts"
B="$ROOT/build"
cd "$ROOT"

for tool in cmake gperf ccache ldid git perl /opt/homebrew/opt/llvm/bin/llvm-ar; do
	command -v "$tool" >/dev/null || { echo "[-] $tool not found (brew install cmake gperf ccache ldid llvm)"; exit 1; }
done
[ -d "$ROOT/tdlib/td/td" ] || git submodule update --init tdlib/td
[ -f "$ROOT/vendor/include/tg_config.h" ] || { echo "[-] vendor/include/tg_config.h missing: copy tg_config.h.example and fill api_id/api_hash"; exit 1; }
for f in vendor/libs/libcrypto-universal.a vendor/libs/libssl-universal.a vendor/libs/WebP.framework/WebP third_party/opus/lib/libopus.a; do
	[ -f "$ROOT/$f" ] || { echo "[-] $f missing: it is gitignored and has to come from a previous checkout"; exit 1; }
done

step() { # step <output that marks it done> <command...>
	local out="$1"; shift
	if [ -e "$out" ]; then echo "[=] $(basename "$out") present, skipping: $*"; return; fi
	echo "[+] $*"
	local log="$B/logs/$(basename "$1" .sh).log"
	mkdir -p "$B/logs"
	"$@" > "$log" 2>&1 || { echo "[-] failed, see $log"; tail -20 "$log"; exit 1; }
}

mkdir -p "$B"
make -s "$B/tools/machofix"   # build_tdlib_dylib.sh runs it on the dylib
step "$B/sdks/iPhoneOS15.6.sdk"                 "$S/setup_sdk.sh"
step "$B/libs/libcrypto.a"                      "$S/build_deps.sh"
step "$B/armv7/openssl/libcrypto.a"             "$S/build_openssl.sh"
step "$B/arm64/libs/libvpx.a"                   "$S/build_libvpx.sh"
step "$B/armv7/ffmpeg/lib/libavcodec.a"         "$S/build_ffmpeg.sh"
step "$B/tdlib/lib/libtdcore.a"                 "$S/build_tdlib.sh"
step "$B/arm64/tdlib64/libtdcore.a"             "$S/repack_arm64_libs.sh"
step "$B/armv7/tdlib/lib/libtdjson.dylib"       "$S/build_tdlib_dylib.sh" --install

[ "${1:-}" = "--deps" ] && { echo "[+] dependencies ready"; exit 0; }

mkdir -p "$B/logs"
# check_release.sh links armv7 itself; run it first so the IPAs below are the last ones written.
echo "[+] release check"
"$S/check_release.sh" > "$B/logs/check-release.log" 2>&1 || { echo "[-] see $B/logs/check-release.log"; grep -m5 -E 'error:|FOUND' "$B/logs/check-release.log"; exit 1; }
tail -1 "$B/logs/check-release.log"
echo "[+] make ipa (DEV=0)"
make -j"$(sysctl -n hw.logicalcpu)" DEV=0 ipa > "$B/logs/make-ipa.log" 2>&1 || { echo "[-] see $B/logs/make-ipa.log"; grep -m5 -E 'error:' "$B/logs/make-ipa.log"; exit 1; }

cd "$B/ipa"
for f in LegacyTG-armv7.ipa LegacyTG-arm64.ipa LegacyTG.ipa; do
	v="$(unzip -p "$f" Payload/LegacyTG.app/Info.plist | plutil -extract CFBundleShortVersionString raw -)"
	echo "    $f  $(du -h "$f" | cut -f1)  v$v"
done
shasum -a 256 LegacyTG-armv7.ipa LegacyTG-arm64.ipa LegacyTG.ipa | tee SHA256SUMS
