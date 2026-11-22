#!/usr/bin/env python3
"""lint_pages.py - every screen says which page kind it is (R1).

A Feature class whose superclass chain reaches TGRowsViewController (directly
or through TGPageViewController, TGBusinessBaseViewController,
TGFeatureListViewController, TGListViewController or another Feature screen)
names its kind: `pageKind`, `initWithPageKind:` or `templateWithKind:` in the
class's own files (Name.m, Name+*.m), or inherits one from its superclass.

The queue, scripts/pages_queue.txt, lists the classes that do not say yet.
It only shrinks: a queued class that now has a kind fails until its line goes
(`--update` rewrites the file), and a new class without a kind is never
queued by hand.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUEUE = os.path.join(ROOT, 'scripts', 'pages_queue.txt')
BASES = {'TGRowsViewController', 'TGGridRowsViewController',
         'TGPageViewController', 'TGListViewController'}
# Shared bases in src/UI or Features that are not screens themselves.
ABSTRACT = {'TGBusinessBaseViewController', 'TGFeatureListViewController'}
KIND = re.compile(r'\bpageKind\b|initWithPageKind:|templateWithKind:')
DECL = re.compile(r'^\s*@interface\s+([A-Za-z_]\w*)\s*:\s*([A-Za-z_]\w*)', re.M)
IMPL = re.compile(r'^\s*@implementation\s+([A-Za-z_]\w*)', re.M)
COMMENT = re.compile(r'//.*?$|/\*.*?\*/', re.S | re.M)


def sources(top):
    for base, _, files in os.walk(top):
        for name in files:
            if name.endswith(('.m', '.mm', '.h')):
                yield os.path.join(base, name)


def read(path):
    with open(path, encoding='utf-8', errors='replace') as f:
        return COMMENT.sub('', f.read())


def scan():
    parent, files = {}, {}
    for path in list(sources(os.path.join(ROOT, 'src'))):
        text = read(path)
        for cls, sup in DECL.findall(text):
            parent.setdefault(cls, sup)
        stem = os.path.basename(path).rsplit('.', 1)[0].split('+', 1)[0]
        files.setdefault(stem, []).append(text)
        # A class's methods also live in category files named after their
        # duty (Profile/Core/TGProfileLifecycle.m).
        for cls in IMPL.findall(text):
            if cls != stem:
                files.setdefault(cls, []).append(text)
    own = {c: any(KIND.search(t) for t in files.get(c, [])) for c in parent}

    def chain(cls):
        seen = []
        while cls in parent and cls not in seen:
            seen.append(cls)
            cls = parent[cls]
        return seen, cls

    screens = {}
    for cls in parent:
        if cls in BASES or cls in ABSTRACT:
            continue
        path_classes, root = chain(cls)
        reaches = root in BASES or any(c in BASES for c in path_classes[1:])
        if not reaches:
            continue
        feature = any(cls == os.path.basename(p).rsplit('.', 1)[0].split('+', 1)[0]
                      for p in sources(os.path.join(ROOT, 'src', 'Features')))
        if not feature:
            continue
        screens[cls] = any(own.get(c) for c in path_classes if c not in BASES)
    return screens


def main():
    update = '--update' in sys.argv
    screens = scan()
    missing = sorted(c for c, has in screens.items() if not has)
    queued = []
    if os.path.exists(QUEUE):
        with open(QUEUE) as f:
            queued = [l.strip() for l in f if l.strip() and not l.startswith('#')]
    if update:
        keep = [c for c in queued if c in missing]
        with open(QUEUE, 'w') as f:
            f.write('# Screens that do not say their page kind yet (R1). Read by\n'
                    '# scripts/lint_pages.sh. Only shrinks; never add a line.\n')
            for c in keep:
                f.write(c + '\n')
        print(f'lint_pages: queue {len(queued)} -> {len(keep)}')
        queued = keep
    status = 0
    for c in missing:
        if c not in queued:
            print(f'lint_pages: {c} has no page kind (set pageKind or initWithPageKind:)')
            status = 1
    for c in queued:
        if c not in missing:
            print(f'lint_pages: {c} now has a kind or is gone; '
                  'run scripts/lint_pages.sh --update')
            status = 1
    if not status:
        print(f'lint_pages: {len(screens) - len(missing)} of {len(screens)} screens '
              f'say their kind, {len(missing)} queued')
    return status


if __name__ == '__main__':
    sys.exit(main())
