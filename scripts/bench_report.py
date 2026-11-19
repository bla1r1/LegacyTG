#!/usr/bin/env python3
# bench_report.py DUMP BINARY [ARCH] - rank functions in a TGSampler dump.
# FOCUS=substring also lists what that function called.
#
# "self" is where the main thread was when sampled, "total" counts a function
# once per sample anywhere on the stack. App frames go through atos against
# the unstripped binary; system frames keep the name dladdr found on device.
import collections, subprocess, sys

dump, binary = sys.argv[1], sys.argv[2]
arch = sys.argv[3] if len(sys.argv) > 3 else "armv7"
app = binary.rsplit("/", 1)[-1]

samples, addrs = [], {}
for line in open(dump):
    parts = line.split()
    if not parts:
        continue
    if parts[0] == "S":
        samples.append([int(a, 16) for a in parts[1:]])
    elif parts[0] == "A":
        addrs[int(parts[1], 16)] = (int(parts[2], 16), parts[3], " ".join(parts[4:]))

names = {a: f"{img}`{sym}" for a, (base, img, sym) in addrs.items()}
by_base = collections.defaultdict(list)
for a, (base, img, sym) in addrs.items():
    if img == app:
        by_base[base].append(a)
for base, lst in by_base.items():
    # return addresses point after the call; -1 lands on the call's line
    out = subprocess.run(["atos", "-arch", arch, "-o", binary, "-l", hex(base)]
                         + [hex(max(a - 1, base)) for a in lst],
                         capture_output=True, text=True).stdout.splitlines()
    for a, sym in zip(lst, out):
        names[a] = sym.split(" (in ")[0] if " (in " in sym else sym

def name(a):
    n = names.get(a, hex(a))
    return n.split(") (")[0] + ")" if ") (" in n else n

self_c, total_c = collections.Counter(), collections.Counter()
for s in samples:
    self_c[name(s[0])] += 1
    for n in {name(a) for a in s}:
        total_c[n] += 1

n = len(samples) or 1
print(f"{len(samples)} samples ({len(samples) * 2} ms of main thread at 2 ms)")
print("\n-- self (top 25)")
for k, v in self_c.most_common(25):
    print(f"{100 * v / n:5.1f}%  {k}")
print("\n-- total, app code only (top 40)")
shown = 0
for k, v in total_c.most_common():
    if "LegacyTG`" in k or ("`" not in k and not k.startswith("0x")):
        print(f"{100 * v / n:5.1f}%  {k}")
        shown += 1
        if shown == 40:
            break

# FOCUS=name: what the matching function called, one level down, so a heavy
# "total" can be split without opening the dump by hand.
import os
focus = os.environ.get("FOCUS")
if focus:
    kids, hits = collections.Counter(), 0
    for s in samples:
        names_s = [name(a) for a in s]
        idx = next((i for i, x in enumerate(names_s) if focus in x), None)
        if idx is None:
            continue
        hits += 1
        kids[names_s[idx - 1] if idx > 0 else "(self)"] += 1
    print(f"\n-- inside {focus}: {100 * hits / n:.1f}% of samples")
    for k, v in kids.most_common(20):
        print(f"{100 * v / n:5.1f}%  {k}")
