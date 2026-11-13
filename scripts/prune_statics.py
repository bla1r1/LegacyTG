#!/usr/bin/env python3
"""prune_statics.py - static definitions their own file never reads.

A split leaves every part with the whole preamble of the file it came from,
and most of it is not used there: 836 dead definitions in 83 files when this
was written. A dead copy is not harmless. A copied cache is a second cache,
and a copied helper is edited in one file and not in the other eleven.

  scripts/prune_statics.py                 list them, exit 1 if there are any
  scripts/prune_statics.py --apply         remove them
  scripts/prune_statics.py --apply FILE... only these files

Only column-0 `static` functions, prototypes and variables are looked at, and
only removed when the name occurs nowhere else in the file outside comments
and string literals. Removing one can leave another unused, so it repeats.
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

fn_re=re.compile(r'^static\s+(?:inline\s+)?[A-Za-z_][\w\s\*<>,]*?[\s\*]([A-Za-z_]\w*)\s*\(')
var_re=re.compile(r'^static\s+(?!inline)[A-Za-z_][\w\s\*<>]*?[\s\*]([A-Za-z_]\w*)\s*(=\s*[^;{(]*)?;\s*(//.*)?$')
def strip(s):
    # blank out comments and string/char literals, keep length and newlines
    out=[];i=0;n=len(s)
    while i<n:
        c=s[i]
        if s.startswith('//',i):
            j=s.find('\n',i); j=n if j<0 else j; out.append(' '*(j-i)); i=j
        elif s.startswith('/*',i):
            j=s.find('*/',i+2); j=n if j<0 else j+2; out.append(re.sub(r'[^\n]',' ',s[i:j])); i=j
        elif c in '"\'':
            j=i+1
            while j<n and s[j]!=c and s[j]!='\n':
                j+= 2 if s[j]=='\\' else 1
            if j>=n or s[j]=='\n':      # an apostrophe in a #pragma, not a literal
                out.append(c); i+=1
            else:
                out.append(c+' '*(j-i-1)+c); i=j+1
        else: out.append(c); i+=1
    return ''.join(out)
def defs(lines, clean):
    """(name, first line, last line) incl. the doc comment above."""
    res=[];i=0
    while i<len(lines):
        m=fn_re.match(clean[i]); v=None if m else var_re.match(clean[i])
        if not m and not v: i+=1; continue
        if v: a=b=i; name=v.group(1)
        else:
            name=m.group(1); j=i; depth=0; seen=False; proto=False
            while j<len(lines):
                for ch in clean[j]:
                    if ch=='{': depth+=1; seen=True
                    elif ch=='}': depth-=1
                    elif ch==';' and not seen: proto=True
                if proto or (seen and depth==0): break
                j+=1
            a,b=i,j
            if not proto and not lines[b].startswith('}'): i=b+1; continue  # not a shape we trust
        k=a
        while k>0 and lines[k-1].lstrip().startswith('///'): k-=1
        res.append((name,k,b)); i=b+1
    return res


def prune_file(path, apply):
    """Names removed (or removable) from one file."""
    src = Path(path).read_text()
    removed = []
    while True:
        lines = src.split('\n')
        clean = strip(src).split('\n')
        if len(lines) != len(clean):
            sys.exit(f"{path}: cannot tell code from comments; left alone")
        text = '\n'.join(clean)
        byname = {}
        for d in defs(lines, clean):
            byname.setdefault(d[0], []).append(d)
        dead = []
        for name, group in byname.items():
            uses = len(re.findall(r'\b' + re.escape(name) + r'\b', text))
            if uses == len(group):          # only its own definition/prototype
                dead += group
        if not dead:
            break
        kill = set()
        for name, a, b in dead:
            kill.update(range(a, b + 1))
            removed.append(name)
            if b + 1 < len(lines) and not lines[b + 1].strip() and (a == 0 or not lines[a - 1].strip()):
                kill.add(b + 1)
        src = '\n'.join(l for i, l in enumerate(lines) if i not in kill)
    if removed and apply:
        Path(path).write_text(src)
    return removed


def source_files():
    out = []
    for root, _, names in os.walk(ROOT / 'src'):
        out += [os.path.join(root, n) for n in sorted(names) if n.endswith(('.m', '.mm'))]
    return sorted(out)


def main():
    apply = '--apply' in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith('--')] or source_files()
    total = 0
    for path in files:
        removed = prune_file(path, apply)
        if removed:
            total += len(removed)
            shown = os.path.relpath(path, ROOT)
            print(f"  {shown}: {' '.join(sorted(set(removed)))}")
    if total:
        print(f"  {total} unused static definitions" + (" removed" if apply else "; run scripts/prune_statics.py --apply"))
    sys.exit(1 if total and not apply else 0)


if __name__ == '__main__':
    main()
