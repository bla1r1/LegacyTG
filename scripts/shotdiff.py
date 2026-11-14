#!/usr/bin/env python3
"""shotdiff.py BEFORE AFTER - compare two folders of shots from shots.sh.

Every name in both folders is compared pixel by pixel below the status bar
(its clock always differs). A pixel counts when a channel moves more than the
threshold, so the render server's dithering does not. Prints
"same" or the changed pixel count and row span; exits 1 when any differ.

No PIL on this Mac: sips turns each PNG into a BMP, read here directly.
"""
import argparse
import os
import struct
import subprocess
import sys
import tempfile


def load(png, tmp):
    bmp = os.path.join(tmp, os.path.basename(png) + ".bmp")
    subprocess.run(["sips", "-s", "format", "bmp", png, "--out", bmp],
                   check=True, capture_output=True)
    data = open(bmp, "rb").read()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    depth = struct.unpack_from("<H", data, 28)[0] // 8
    stride = (width * depth + 3) & ~3
    rows = []
    for y in range(abs(height)):
        row = (abs(height) - 1 - y) if height > 0 else y
        start = offset + row * stride
        rows.append(data[start:start + width * depth])
    return width, depth, rows


def compare(a, b, top, threshold):
    width, depth, rows_a = a
    _, _, rows_b = b
    if len(rows_a) != len(rows_b):
        return None, None
    changed, span = 0, []
    for y in range(top, len(rows_a)):
        ra, rb = rows_a[y], rows_b[y]
        if ra == rb:
            continue
        n = sum(1 for i in range(0, width * depth, depth)
                if max(abs(ra[i + k] - rb[i + k]) for k in range(3)) > threshold)
        if n:
            changed += n
            span.append(y)
    return changed, span


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("--top", type=int, default=40,
                        help="pixel rows to skip: the status bar (40 on a 2x phone)")
    parser.add_argument("--threshold", type=int, default=24)
    args = parser.parse_args()

    names = sorted(set(os.listdir(args.before)) & set(os.listdir(args.after)))
    names = [n for n in names if n.endswith(".png")]
    if not names:
        print("no shots in common")
        return 2
    differ = 0
    with tempfile.TemporaryDirectory() as tmp:
        for side in ("a", "b"):
            os.makedirs(os.path.join(tmp, side))
        for name in names:
            a = load(os.path.join(args.before, name), os.path.join(tmp, "a"))
            b = load(os.path.join(args.after, name), os.path.join(tmp, "b"))
            changed, span = compare(a, b, args.top, args.threshold)
            if changed is None:
                print(f"{name}: different sizes")
                differ += 1
            elif changed:
                print(f"{name}: {changed} px, rows {span[0]}-{span[-1]}")
                differ += 1
            else:
                print(f"{name}: same")
    return 1 if differ else 0


if __name__ == "__main__":
    sys.exit(main())
