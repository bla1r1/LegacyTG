#!/bin/bash
# tlottie, the official client's Lottie renderer (Rust, MIT, third_party/tlottie),
# as static libraries: build/armv7/libs/libtlottie.a, build/arm64/libs/libtlottie.a
# and build/host/libtlottie.a for the host tests.
#
# iOS builds are no_std with tlottie's own C runtime (malloc allocator, panic ->
# abort), so they ask nothing of the OS past libc and run on iOS 6. That needs
# nightly for -Z build-std; armv7 also needs our own target
# (third_party/tlottie/armv7-apple-ios6.json): Rust's only 32-bit iOS target is
# armv7s, whose VFPv4 the A4 and A5 lack and whose hard-float calls do not match
# the Apple ABI. Thumb-2 there because tools/machofix sets bit 0 on every pointer
# into __text. LTO is off: fat LTO on that target dropped the tlottie_* exports.
#
#   rustup toolchain install nightly --profile minimal --component rust-src
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/third_party/tlottie"
TARGET_DIR="$ROOT/build/tlottie"
FEATURES="cpu,c-api,no-std"
export CARGO_PROFILE_RELEASE_NOSTD_LTO=false

cd "$SRC"
rustup run nightly rustc --version >/dev/null 2>&1 ||
	{ echo "[-] nightly Rust missing: rustup toolchain install nightly --profile minimal --component rust-src" >&2; exit 1; }

ios() {
	local target=$1 arch=$2 min=$3 out
	IPHONEOS_DEPLOYMENT_TARGET=$min CARGO_TARGET_DIR="$TARGET_DIR" cargo +nightly build --locked \
		--profile release-nostd --target "$target" -Z build-std=core,alloc -Z json-target-spec \
		--no-default-features --features "$FEATURES"
	out="$TARGET_DIR/$(basename "$target" .json)/release-nostd/libtlottie.a"
	mkdir -p "$ROOT/build/$arch/libs"
	cp "$out" "$ROOT/build/$arch/libs/libtlottie.a"
}

ios ./armv7-apple-ios6.json armv7 6.0
ios aarch64-apple-ios arm64 7.0

CARGO_TARGET_DIR="$TARGET_DIR" cargo build --locked --release --features c-api
mkdir -p "$ROOT/build/host"
cp "$TARGET_DIR/release/libtlottie.a" "$ROOT/build/host/libtlottie.a"

ls -la "$ROOT"/build/{armv7,arm64}/libs/libtlottie.a "$ROOT/build/host/libtlottie.a"
