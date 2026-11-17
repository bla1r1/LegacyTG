#!/bin/bash
# linux_check.sh - compile-check sources for armv7 and arm64 on a Linux host.
#
# No Xcode or ld64 on Linux, so this stops at -fsyntax-only: it catches what
# the compiler catches (types, selectors, unguarded iOS 7+ API) and nothing
# the linker or a device would. SDKs come from scripts/setup_sdk.sh
# (theos/sdks in build/sdks); TDLib headers from the tdlib/td submodule.
#
#   scripts/linux_check.sh                 files changed against HEAD
#   scripts/linux_check.sh FILE...         those files
#   scripts/linux_check.sh --all           every .m/.mm under src/
#   ARCHS=armv7 scripts/linux_check.sh     one arch
set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT" || exit 1

SDK=""
for s in iPhoneOS12.4 iPhoneOS9.3 iPhoneOS15.6; do
  [ -d "build/sdks/$s.sdk" ] && { SDK="build/sdks/$s.sdk"; break; }
done
[ -n "$SDK" ] || { echo "no iOS SDK in build/sdks: run bash scripts/setup_sdk.sh"; exit 2; }
[ -f tdlib/td/td/generate/scheme/td_api.tl ] || git submodule update --init --depth 1 tdlib/td

# tg_api_key.h is generated from the private tg_config.h; a zero stub is
# enough to type-check the code that includes it.
STUB=build/linux-check
mkdir -p "$STUB"
[ -f vendor/include/tg_api_key.h ] || [ -f "$STUB/tg_api_key.h" ] || cat > "$STUB/tg_api_key.h" <<'H'
#define TG_API_HASH_LEN 32
static const int kTGApiIdMasked = 0, kTGApiIdMask = 0;
static const unsigned char kTGApiHashMasked[TG_API_HASH_LEN] = {0}, kTGApiHashMask[TG_API_HASH_LEN] = {0};
H
CXXINC=$(ls -d build/sdks/*/usr/include/c++/v1 2>/dev/null | head -1)
INC=(-Ivendor/include -Isrc/Compat -I"$STUB")
while IFS= read -r d; do INC+=("-I$d"); done < <(find src -type d)
INC+=(-Ithird_party -Ithird_party/nanosvg -Ithird_party/libvpx/include -Ithird_party/nestegg/include
      -Ithird_party/ogg -Ithird_party/ogg/ogg -Ithird_party/opus/include -Ithird_party/opus/include/opus
      -Ithird_party/opusenc -Ithird_party/opusfile -Itdlib/td -Itdlib/include -Ivendor/libs -Fvendor/libs)

if [ "${1:-}" = "--all" ]; then
  mapfile -t FILES < <(find src -name '*.m' -o -name '*.mm')
elif [ $# -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <( { git diff --name-only HEAD; git ls-files --others --exclude-standard; } \
                        | grep -E '^src/.*\.(m|mm)$' | sort -u)
fi
[ ${#FILES[@]} -gt 0 ] || { echo "  linux_check: nothing to check"; exit 0; }

fail=0
for arch in ${ARCHS:-armv7 arm64}; do
  case $arch in
    armv7) T=(-target armv7-apple-ios6.0 -mthumb) ;;
    arm64) T=(-target arm64-apple-ios7.0) ;;
  esac
  for f in "${FILES[@]}"; do
    [ -f "$f" ] || continue
    X=(); case $f in *.mm) X=(-std=c++11 -isystem "$CXXINC") ;; esac
    if ! out=$(clang "${T[@]}" -isysroot "$SDK" -fsyntax-only -fobjc-arc -DTG_DEV=1 \
          -Wunguarded-availability -Wno-macro-redefined -Wno-incompatible-pointer-types \
          -Wno-deprecated-declarations -Wno-unused-command-line-argument \
          -fno-objc-arc-exceptions \
          "${X[@]}" "${INC[@]}" "$f" 2>&1); then
      echo "$out" | grep -E 'error' | head -20; echo "  FAIL $arch $f"; fail=1
    fi
  done
done
[ $fail = 0 ] && echo "  linux_check: ${#FILES[@]} file(s) compile for ${ARCHS:-armv7 arm64}"
exit $fail
