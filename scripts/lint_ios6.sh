#!/bin/sh
# lint_ios6.sh - two things that look right on iOS 7+ and are wrong on iOS 6.
#
# 1. A UILabel created with no backgroundColor in the 40 lines after it.
#    iOS 6 labels are opaque white by default, so the label is a white box
#    on any background that is not white. The audit of 2026-11-14 fixed 27.
# 2. -addObserverForName:object:queue:usingBlock: in a screen whose token is
#    thrown away. removeObserver:self does not remove a block observer, so
#    every opening of the screen leaves one behind (34 found). A screen uses
#    [TGObservers observe:owner:usingBlock:], or keeps the token.
#
# There is no baseline.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

python3 - <<'PY'
import os, re, sys

WINDOW = 40
label = re.compile(r'\[\[UILabel\s+alloc\]|\[UILabel\s+new\]')
bad = []

for root, _, names in os.walk('src'):
    for name in sorted(names):
        if not name.endswith(('.m', '.mm')):
            continue
        path = os.path.join(root, name)
        src = open(path, errors='replace').read()
        lines = src.split('\n')

        for i, line in enumerate(lines):
            if line.lstrip().startswith('//') or not label.search(line):
                continue
            if 'backgroundColor' not in '\n'.join(lines[i:i + WINDOW + 1]):
                bad.append(f'  {path}:{i + 1}: UILabel with no backgroundColor (white box on iOS 6)')

        if not root.startswith(('src/Features', 'src/UI')):
            continue    # stores and the app delegate live as long as the process
        for m in re.finditer(r'addObserverForName:', src):
            # The statement up to the call: kept means assigned, returned or
            # passed on as an argument.
            start = max(src.rfind(c, 0, m.start()) for c in ';{}') + 1
            head = src[start:m.start()]
            if re.search(r'=|\breturn\b|\w+:\s*\[[^\]]*$', head):
                continue
            n = src.count('\n', 0, m.start()) + 1
            bad.append(f'  {path}:{n}: block observer token not kept: use [TGObservers observe:owner:usingBlock:]')

if bad:
    print('\n'.join(sorted(bad)))
    print(f'\n  {len(bad)} iOS 6 hazards\n')
    sys.exit(1)
print('  ios6: clean (labels have a background, block observers are owned)')
PY
