#!/bin/sh
# lint_methods.sh - a method declared on one of our classes and implemented
# in no file.
#
# A class split over categories compiles with a declaration and no body: the
# compiler only warns for the primary @implementation, and only when the
# declaration sits in the primary @interface. -musicStripTapped was declared
# in the shared internal header, wired to a button and implemented nowhere,
# so the tap raised "unrecognized selector" on the device.
#
# Declarations come from every @interface block under src/ (class, category,
# extension); bodies from every @implementation of the same class or of a
# superclass. A selector that a macro stamps out (the TGTheme colour getters,
# the TGIcons glyphs) counts as implemented when the class's implementation
# files name it inside a macro call.
#
# There is no baseline: delete the declaration or write the method.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

python3 - <<'PY'
import os, re, sys, collections

def strip(src):
    # Comments and string literals out, line count kept.
    def blank(m):
        return re.sub(r'[^\n]', ' ', m.group(0))
    return re.sub(r'//[^\n]*|/\*.*?\*/|@?"(?:\\.|[^"\\\n])*"', blank, src, flags=re.S)

def selector(decl):
    # "- (void)foo:(int)a bar:(void (^)(int))b" -> "foo:bar:"
    text = decl[1:]
    while True:
        cut = re.sub(r'\([^()]*\)', ' ', text)
        if cut == text:
            break
        text = cut
    parts = re.findall(r'(\w+)\s*:', text)
    if parts:
        return ''.join(p + ':' for p in parts)
    word = re.match(r'\s*(\w+)', text)
    return word.group(1) if word else None

block = re.compile(r'^@(interface|implementation)\s+(\w+)[ \t]*(?::[ \t]*(\w+))?[^\n]*\n(.*?)^@end', re.S | re.M)
method = re.compile(r'^[ \t]*([-+][ \t]*\(.*?)(?=[;{])', re.S | re.M)

declared = collections.defaultdict(dict)   # class -> {(kind, selector): "file:line"}
implemented = collections.defaultdict(set)
parent = {}
bodies = collections.defaultdict(list)     # class -> stripped text of its .m files

for root, _, names in os.walk('src'):
    for name in sorted(names):
        if not name.endswith(('.h', '.m', '.mm')):
            continue
        path = os.path.join(root, name)
        src = strip(open(path, errors='replace').read())
        for m in block.finditer(src):
            what, cls, sup, body = m.groups()
            if what == 'interface' and sup:
                parent[cls] = sup
            if what == 'implementation':
                bodies[cls].append(src)
            base = src.count('\n', 0, m.start(4)) + 1
            for d in method.finditer(body):
                sel = selector(d.group(1))
                if not sel:
                    continue
                key = (d.group(1)[0], sel)
                if what == 'implementation':
                    implemented[cls].add(key)
                else:
                    line = base + body.count('\n', 0, d.start(1))
                    declared[cls].setdefault(key, f'{path}:{line}')

def has_body(cls, key):
    seen = set()
    while cls and cls not in seen:
        seen.add(cls)
        if key in implemented[cls]:
            return True
        # Stamped out by a macro: NAME appears as a macro argument.
        word = key[1].split(':')[0]
        if any(re.search(r'^[A-Z][A-Z0-9_]*\([^\n;{}]*\b%s\b' % re.escape(word), text, re.M)
               for text in bodies[cls]):
            return True
        cls = parent.get(cls)
    return False

bad = []
for cls in sorted(declared):
    if not bodies[cls]:
        continue    # a system class we only declare a category on, or a forward interface
    for key, where in sorted(declared[cls].items(), key=lambda kv: kv[1]):
        if not has_body(cls, key):
            bad.append(f'  {where}: {key[0]}[{cls} {key[1]}]')

if bad:
    print('\n'.join(bad))
    print(f'\n  {len(bad)} declared, implemented nowhere: delete the declaration or write the method\n')
    sys.exit(1)
print('  methods: clean (every declared method has a body)')
PY
