#!/bin/bash
# linux_setup.sh - a Linux host that runs the host tests (scripts/linux_test.py).
#
# Ubuntu's GNUstep packages sit on GCC's libobjc, which has no ARC and rejects
# clang's GNUstep ABI, so this builds the stack clang expects into
# build/gnustep: libobjc2, libdispatch, gnustep-make, -base (Foundation),
# -gui and -back (AppKit drawing on cairo, run under Xvfb), -corebase
# (CoreFoundation) and -opal (CoreGraphics, CoreText). About 15 min on 8 cores.
# Pinned tags; libs-corebase and libs-opal have no releases, so their head.
set -eu
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
P=$ROOT/build/gnustep
SRC=$ROOT/build/gnustep-src
mkdir -p "$SRC" "$P"
export CC=clang CXX=clang++
FLAGS=(CPPFLAGS="-I$P/include" LDFLAGS="-L$P/lib -Wl,-rpath,$P/lib")
JOBS=$(nproc)

if command -v apt-get >/dev/null; then
	SUDO=; [ "$(id -u)" = 0 ] || SUDO=sudo
	$SUDO apt-get install -y -q clang lld cmake ninja-build git xvfb \
		libc++-dev libc++abi-dev libffi-dev libxml2-dev libgnutls28-dev \
		libicu-dev libcurl4-openssl-dev zlib1g-dev libssl-dev libwebp-dev \
		libtiff-dev libjpeg-dev libpng-dev libgif-dev libcairo2-dev \
		libfreetype-dev libfontconfig-dev libx11-dev libxt-dev libxext-dev \
		libxrender-dev libxft-dev libxmu-dev liblcms2-dev
fi

fetch() { # repo tag-or-empty
	local dir=$SRC/$(basename "$1" .git)
	[ -d "$dir" ] && return
	if [ -n "$2" ]; then
		git clone -q --depth 1 --branch "$2" --recurse-submodules "$1" "$dir"
	else
		git clone -q --depth 1 "$1" "$dir"
	fi
}

gnumake() { # dir configure-args...
	local dir=$SRC/$1; shift
	( cd "$dir" && . "$P/share/GNUstep/Makefiles/GNUstep.sh" &&
	  ./configure --prefix="$P" "$@" "${FLAGS[@]}" >/dev/null &&
	  make -s -j"$JOBS" >/dev/null && make -s install >/dev/null )
}

step() { echo "== $1"; }

step libobjc2
fetch https://github.com/gnustep/libobjc2.git v2.2.1
[ -f "$P/lib/libobjc.so" ] || {
	cmake -S "$SRC/libobjc2" -B "$SRC/libobjc2/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX="$P" -DTESTS=OFF -DGNUSTEP_INSTALL_TYPE=NONE >/dev/null
	ninja -C "$SRC/libobjc2/build" install >/dev/null; }

step libdispatch
fetch https://github.com/swiftlang/swift-corelibs-libdispatch.git swift-5.10-RELEASE
[ -f "$P/lib/libdispatch.so" ] || {
	cmake -S "$SRC/swift-corelibs-libdispatch" -B "$SRC/swift-corelibs-libdispatch/build" -G Ninja \
		-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$P" -DINSTALL_PRIVATE_HEADERS=ON \
		-DBUILD_TESTING=OFF >/dev/null
	ninja -C "$SRC/swift-corelibs-libdispatch/build" install >/dev/null; }

step gnustep-make
fetch https://github.com/gnustep/tools-make.git make-2_9_2
[ -f "$P/share/GNUstep/Makefiles/GNUstep.sh" ] || {
	( cd "$SRC/tools-make" && ./configure --prefix="$P" --with-layout=fhs \
		--with-library-combo=ng-gnu-gnu --enable-objc-arc --with-objc-lib-flag=-lobjc \
		"${FLAGS[@]}" >/dev/null && make -s install >/dev/null ); }

step gnustep-base
fetch https://github.com/gnustep/libs-base.git base-1_30_0
ls "$P"/lib/libgnustep-base.so* >/dev/null 2>&1 || gnumake libs-base

step gnustep-gui
fetch https://github.com/gnustep/libs-gui.git gui-0_32_0
ls "$P"/lib/libgnustep-gui.so* >/dev/null 2>&1 || gnumake libs-gui

step gnustep-back
fetch https://github.com/gnustep/libs-back.git back-0_32_0
find "$P" -name 'libgnustep-back*' | grep -q . || gnumake libs-back --enable-server=x11 --enable-graphics=cairo

step corebase
fetch https://github.com/gnustep/libs-corebase.git ""
ls "$P"/lib/libgnustep-corebase.so* >/dev/null 2>&1 || gnumake libs-corebase

step opal
fetch https://github.com/gnustep/libs-opal.git ""
ls "$P"/lib/libopal.so* >/dev/null 2>&1 || ( cd "$SRC/libs-opal" &&
	. "$P/share/GNUstep/Makefiles/GNUstep.sh" && make -s -j"$JOBS" >/dev/null && make -s install >/dev/null )

echo "done: python3 scripts/linux_test.py"
