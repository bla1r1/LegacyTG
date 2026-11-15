#!/bin/sh
# lint_fields.sh - TDLib fields the app is handed and never reads.
#
# Data we had and did not draw is the commonest parity gap: "12 Comments"
# without its arrow, a track with no time, an online dot that never expires
# because userStatusOnline.expires is not read. This walks every object type
# reachable (four levels deep) from a request we send or an update we handle
# in td_api.tl, and lists each field whose name appears nowhere in src/ as a
# string literal.
#
# Every such field has a line in scripts/tdlib_fields.txt:
#   todo  <screen>  type.field  what official shows
#   skip  -         type.field  why we never will
#   open  -         type.field  (nobody has looked yet)
# The lint fails on a field missing from the list (a new TDLib field, or a
# type the app has started to reach) and on a line whose field the app now
# reads (drawn: delete the line). `--update` adds the missing ones as open
# and drops the stale ones; run it on purpose, then sort the new lines.
#
# A field read only through a computed key would show as unread; there is
# none today.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

python3 - "$@" <<'PY'
import re, glob, sys, collections

UPDATE = '--update' in sys.argv
LIST = 'scripts/tdlib_fields.txt'
tl = open('tdlib/td/td/generate/scheme/td_api.tl').read()
head, funcs = tl.split('---functions---')
cons, bytype, ret = {}, collections.defaultdict(list), {}
for line in head.splitlines():
    m = re.match(r'^(\w+)\s+(.*?)=\s*(\w+);', line)
    if m:
        cons[m.group(1)] = [a.split(':', 1) for a in m.group(2).split() if ':' in a]
        bytype[m.group(3)].append(m.group(1))
for line in funcs.splitlines():
    m = re.match(r'^(\w+)\s+(.*?)=\s*(\w+);', line)
    if m:
        ret[m.group(1)] = m.group(3)

src = '\n'.join(open(f, errors='ignore').read()
                for f in glob.glob('src/**/*.m', recursive=True) + glob.glob('src/**/*.mm', recursive=True))
read = set(re.findall(r'"([a-z][a-z0-9_]*)"', src))
roots = set(re.findall(r'@"@type"\s*:\s*@"(\w+)"', src)) | set(re.findall(r'"(update\w+)"', src))

# A type keeps the shallowest depth it was reached at, so a long first path
# cannot hide what a short one would have walked into.
seen, unread = {}, set()
def walk(c, depth):
    if c not in cons or depth > 3 or seen.get(c, 99) <= depth:
        return
    seen[c] = depth
    for name, typ in cons[c]:
        if name not in read:
            unread.add(c + '.' + name)
        # A field's type is a class (its constructors) or, written in lower
        # case, one constructor by name.
        t = re.sub(r'vector<|>', '', typ)
        for sub in bytype.get(t, []) + ([t] if t in cons else []):
            walk(sub, depth + 1)
for t in sorted(roots):
    if t in ret:
        for c in bytype.get(ret[t], []):
            walk(c, 0)
    elif t in cons:
        walk(t, 0)

lines, listed, bad = [], {}, []
for n, line in enumerate(open(LIST).read().splitlines(), 1):
    lines.append(line)
    if not line.strip() or line.startswith('#'):
        continue
    parts = line.split(None, 3)
    if len(parts) < 3 or parts[0] not in ('todo', 'skip', 'open'):
        bad.append('%s:%d: expected "todo|skip|open screen type.field note"' % (LIST, n))
        continue
    listed[parts[2]] = parts[0]

missing = sorted(unread - set(listed))
stale = sorted(f for f in listed if f not in unread)

if UPDATE:
    keep = [l for l in lines if not (l.split(None, 3)[2:3] and l.split(None, 3)[2] in stale)]
    keep += ['open  -  %s' % f for f in missing]
    open(LIST, 'w').write('\n'.join(keep) + '\n')
    print('  %d added as open, %d stale removed' % (len(missing), len(stale)))
    sys.exit(0)

for b in bad:
    print('  ' + b)
for f in missing:
    print('  %s: not read and not in %s' % (f, LIST))
for f in stale:
    print('  %s: read now - delete its line in %s' % (f, LIST))
count = collections.Counter(listed.values())
print('  fields: %d todo, %d open, %d skip' % (count['todo'], count['open'], count['skip']))
sys.exit(1 if bad or missing or stale else 0)
PY
