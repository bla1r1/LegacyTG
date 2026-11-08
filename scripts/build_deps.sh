#!/bin/bash
# OpenSSL slices from the prebuilt universal archives in vendor/libs:
#   build/libs/lib{crypto,ssl}.a           armv7+arm64, what build_tdlib.sh links
#   build/{armv7,arm64}/libs/lib{crypto,ssl}.a   thin, what the app links
# armv7 TDLib uses the assembly OpenSSL from build_openssl.sh instead.
set -e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN="${ROOT_DIR}/vendor/libs"
mkdir -p "${ROOT_DIR}/build/libs" "${ROOT_DIR}/build/armv7/libs" "${ROOT_DIR}/build/arm64/libs"

for lib in crypto ssl; do
	src="${IN}/lib${lib}-universal.a"
	[ -f "${src}" ] || { echo "[-] ${src} missing"; exit 1; }
	lipo "${src}" -extract armv7 -extract arm64 -output "${ROOT_DIR}/build/libs/lib${lib}.a"
	lipo "${src}" -thin armv7 -output "${ROOT_DIR}/build/armv7/libs/lib${lib}.a"
	lipo "${src}" -thin arm64 -output "${ROOT_DIR}/build/arm64/libs/lib${lib}.a"
done
ls -lh "${ROOT_DIR}"/build/libs/*.a "${ROOT_DIR}"/build/arm*/libs/lib{crypto,ssl}.a
