#!/bin/bash
# libvpx 1.17.0 for video stickers (.webm VP9 with alpha): VP9 decoder only, no
# VP8, no encoder. NEON through intrinsics; --disable-neon-asm because the .S
# files are ARM mode and machofix sets the Thumb bit on every pointer into __text.
# Output: build/{armv7,arm64}/libs/libvpx.a. Headers stay in third_party/libvpx.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=v1.17.0
SRC="$ROOT/build/src/libvpx"
SDK="$ROOT/build/sdks/iPhoneOS15.6.sdk"
[ -d "$SDK" ] || { echo "[-] $SDK missing: run scripts/setup_sdk.sh"; exit 1; }
[ -d "$SRC" ] || git clone --depth 1 --branch "$VERSION" https://chromium.googlesource.com/webm/libvpx "$SRC"

# configure ignores --libc on darwin and asks `xcrun --sdk iphoneos` for the
# sysroot; Xcode's current SDK has no armv7 libSystem, so answer with ours.
SHIM="$ROOT/build/libvpx-xcrun"
mkdir -p "$SHIM"
cat > "$SHIM/xcrun" <<EOF
#!/bin/sh
case "\$*" in
	*--show-sdk-path*) echo "$SDK" ;;
	*--show-sdk-version*) echo 15.6 ;;
	*) exec /usr/bin/xcrun "\$@" ;;
esac
EOF
chmod +x "$SHIM/xcrun"
export PATH="$SHIM:$PATH"

for arch in armv7 arm64; do
	OBJ="$ROOT/build/$arch/libvpx-obj"
	rm -rf "$OBJ"; mkdir -p "$OBJ" "$ROOT/build/$arch/libs"; cd "$OBJ"
	"$SRC/configure" --target="$arch-darwin-gcc" --libc="$SDK" \
		--disable-neon-asm --disable-examples --disable-tools --disable-unit-tests --disable-docs \
		--disable-vp8 --disable-vp9-encoder --enable-vp9-decoder \
		--enable-static --disable-shared > configure.log
	make -j"$(sysctl -n hw.logicalcpu)" libvpx.a > make.log
	cp -f libvpx.a "$ROOT/build/$arch/libs/libvpx.a"
done
lipo -info "$ROOT/build/armv7/libs/libvpx.a" "$ROOT/build/arm64/libs/libvpx.a"
