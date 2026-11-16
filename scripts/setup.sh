#!/bin/bash
# A fresh Mac to a working checkout: tools, iOS SDKs, dependencies, host tests, emulator.
#
#   scripts/setup.sh            everything (cold: ~1 h, mostly TDLib; reruns skip what is done)
#   scripts/setup.sh --no-emu   without the iPhone 4 emulator
#
# Then: make -j8 ipa-armv7, make -j8 -f tests/Makefile test, scripts/emu.sh test.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
die() { echo "[-] $*" >&2; exit 1; }

xcode-select -p >/dev/null 2>&1 && xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1 ||
	die "Xcode with the iOS SDK is needed: install Xcode, then sudo xcode-select -s /Applications/Xcode.app"
command -v brew >/dev/null || die "Homebrew is needed: https://brew.sh"

# Only what is missing; no upgrade of installed dependents (that pulls Qt and JDKs).
need=; for p in cmake gperf ccache ldid llvm; do brew list --versions "$p" >/dev/null || need+=" $p"; done
[ -z "$need" ] || HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 brew install $need

[ -d tdlib/td/td ] || git submodule update --init tdlib/td

# Secrets and prebuilt archives are gitignored; nothing here can fetch them.
missing=
[ -f vendor/include/tg_config.h ] || missing+="\n  vendor/include/tg_config.h   copy tg_config.h.example, fill api_id/api_hash from my.telegram.org"
for f in vendor/libs/libcrypto-universal.a vendor/libs/libssl-universal.a vendor/libs/WebP.framework/WebP third_party/opus/lib/libopus.a; do
	[ -f "$f" ] || missing+="\n  $f   from another checkout or a maintainer"
done
[ -z "$missing" ] || die "gitignored inputs missing:$(printf "$missing")"
# The example's keys build fine and fail only at sign-in, as API_ID_INVALID.
! grep -Eq '^#define[[:space:]]+TG_API_ID[[:space:]]+12345([^0-9]|$)' vendor/include/tg_config.h ||
	die "vendor/include/tg_config.h has the example's api_id 12345: put your api_id/api_hash from my.telegram.org"

scripts/build_all.sh --deps

echo "[+] host tests"
mkdir -p build/logs   # build_all.sh makes it only when a step actually runs
make -j"$(sysctl -n hw.logicalcpu)" -f tests/Makefile test > build/logs/setup-tests.log 2>&1 ||
	{ grep -E '^not ok' build/logs/setup-tests.log | head; die "host tests failed, build/logs/setup-tests.log"; }
grep -E '^# [0-9]+ passed' build/logs/setup-tests.log

if [ "${1:-}" != "--no-emu" ]; then
	# hw.optional.arm64, not uname: a shell under Rosetta says x86_64 on an M1.
	if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then scripts/emu.sh setup
	else echo "[!] emulator skipped: it builds on Apple Silicon only"; fi
fi
echo "[+] ready: make -j8 ipa-armv7 / make -j8 DEV=1 / scripts/emu.sh test"
