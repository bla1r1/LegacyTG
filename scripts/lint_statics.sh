#!/bin/sh
# lint_statics.sh - fail on what a careless split leaves behind.
#
# 1. A static definition the file never reads (scripts/prune_statics.py).
# 2. The same stateful static, word for word, in two files: a file-level
#    mutable `static` variable, or a static function that keeps a
#    function-local `static`. Each copy has its own state, so a "shared"
#    cache is as many caches as there are files (the emoji panel had 12, and
#    its account-switch purge emptied one that held nothing).
#
# There is no baseline: move the definition to one file and declare it in the
# folder's internal header.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1
status=0

python3 scripts/prune_statics.py || status=1

python3 - <<'PY' || status=1
import os, re, sys, collections
sys.path.insert(0, 'scripts')
from prune_statics import strip, defs

local_static = re.compile(r'^\s+static\s+(?!const\b)', re.M)
mutable_var = re.compile(r'^static\s+(?!const\b)(?!inline\b)(?:(?!\bconst\b).)*;\s*$')
seen = collections.defaultdict(list)
for root, _, names in os.walk('src'):
    for name in sorted(names):
        if not name.endswith(('.m', '.mm')):
            continue
        path = os.path.join(root, name)
        src = open(path).read()
        lines, clean = src.split('\n'), strip(src).split('\n')
        if len(lines) != len(clean):
            continue
        for ident, a, b in defs(lines, clean):
            code = [l for l in clean[a:b + 1] if l.strip()]
            body = '\n'.join(l.strip() for l in code)
            if not code:
                continue
            one_line = len(code) == 1
            stateful = (mutable_var.match(code[0]) and '(' not in code[0] if one_line
                        else local_static.search('\n'.join(code[1:])))
            if stateful:
                seen[body].append((path, ident))
bad = 0
for body, places in seen.items():
    files = sorted({p for p, _ in places})
    if len(files) < 2:
        continue
    bad += 1
    print(f"\n  {places[0][1]} keeps its own state in {len(files)} files:")
    for f in files:
        print(f"    {f}")
if bad:
    print("\n  one definition, declared in the folder's internal header\n")
sys.exit(1 if bad else 0)
PY

if [ "$status" -eq 0 ]; then
	echo "  statics: clean (no unused copies, no duplicated state)"
fi
exit "$status"
