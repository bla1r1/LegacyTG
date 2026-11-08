#!/usr/bin/env python3
"""split_source.py - mechanical splitter for LegacyTG source files.

Modes:
  plan <file>                 show classes, sections, static helpers
  classes <file>              split one file with several @implementation blocks
  sections <file> --base B    split one @implementation by #pragma mark

By default everything is a dry run. Add --apply to write files and update:
  Makefile, tests/Makefile and docs/**/*.md.

Examples:
  scripts/split_source.py plan src/Features/Business/TGBusinessViewController.m
  scripts/split_source.py classes src/Features/Business/TGBusinessViewController.m --apply
  scripts/split_source.py sections src/Core/Client/TGClient+Account.m \
      --base TGClient+Account --out src/Core/Client/Account \
      --headers src/Core/Client/TGClient+Account.h --umbrella src/Core/Client/TGClient.h --apply

The tool does not decide names for you in sections mode: pass --map
"Section title=CategoryName" or let it derive Base+PascalCase(title). It moves
static helpers into every section that uses them (static copies are safe).
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def lines(path: Path) -> list[str]:
    return path.read_text().splitlines()


def is_impl(line: str) -> re.Match | None:
    return re.match(r"^@implementation\s+([A-Za-z_]\w*)", line)


def is_iface(line: str) -> re.Match | None:
    return re.match(r"^@interface\s+([A-Za-z_]\w*)", line)


def blocks(text: list[str], start_re, end="^@end") -> list[tuple[str, int, int]]:
    """(name, start index, end index inclusive) for every block."""
    out = []
    i = 0
    while i < len(text):
        m = re.match(start_re, text[i])
        if not m:
            i += 1
            continue
        name = m.group(1)
        j = i
        if not re.search(r"@end\b", text[i]):
            j = i + 1
            while j < len(text) and not re.match(end, text[j].strip()):
                j += 1
        out.append((name, i, min(j, len(text) - 1)))
        i = j + 1
    return out


def imports(text: list[str]) -> list[str]:
    return [l for l in text if l.startswith(("#import", "#include"))]


def strip_interfaces(text: list[str]) -> list[str]:
    """Drop @interface ... @end blocks from a preamble."""
    out, i = [], 0
    while i < len(text):
        if is_iface(text[i]):
            if re.search(r"@end\b", text[i]):
                i += 1
                continue
            while i < len(text) and text[i].strip() != "@end":
                i += 1
            i += 1
            continue
        out.append(text[i])
        i += 1
    return out


def function_ranges(text: list[str], static: bool | None = None) -> list[tuple[str, int, int]]:
    """Top-level function definitions (name, start, end exclusive)."""
    out, i = [], 0
    while i < len(text):
        line = text[i]
        m = re.match(r"^(static\s+)?(.+?\b)([A-Za-z_]\w*)\s*\(", line)
        if (not m or not line or line[0].isspace() or
                line.startswith(("#", "//", "/*", "@", "typedef", "extern")) or
                m.group(3) in {"if", "for", "while", "switch", "return", "else"}):
            i += 1
            continue
        is_static = bool(m.group(1))
        if static is not None and is_static != static:
            i += 1
            continue
        name, start, depth, seen = m.group(3), i, 0, False
        j = i
        while j < len(text):
            l = text[j]
            if not seen:
                if "{" in l:
                    seen = True
                elif ";" in l:
                    break
            if seen:
                depth += l.count("{") - l.count("}")
                if depth == 0 and j > start:
                    out.append((name, start, j + 1))
                    i = j
                    break
            j += 1
        i += 1
    return out

def function_defs(text: list[str], static: bool | None = None) -> dict[str, list[str]]:
    return {name: text[a:b] for name, a, b in function_ranges(text, static)}


def strip_implementations(text: list[str]) -> list[str]:
    out, i = [], 0
    while i < len(text):
        if is_impl(text[i]):
            if re.search(r"@end\b", text[i]):
                i += 1
                continue
            while i < len(text) and text[i].strip() != "@end":
                i += 1
            i += 1
            continue
        out.append(text[i])
        i += 1
    return out


def static_defs(text: list[str]) -> dict[str, list[str]]:
    return function_defs(text, static=True)


def variable_ranges(text: list[str]) -> list[tuple[str, int, int]]:
    """Top-level variable definitions, including multiline initialisers."""
    out, i = [], 0
    while i < len(text):
        line = text[i]
        if (not line or line[0].isspace() or
                line.startswith(("#", "//", "/*", "@", "typedef", "enum", "struct", "static", "extern"))):
            i += 1
            continue
        head = line.split("=", 1)[0]
        if "=" in line and ";" in line[line.index("="):] and "(" not in head:
            start = i
            while i < len(text) and ";" not in text[i]:
                i += 1
            out.append((f"variable@{start}", start, min(i + 1, len(text))))
        i += 1
    return out


def section_ranges(text: list[str], start: int, end: int) -> list[tuple[str, int, int]]:
    marks = [i for i in range(start, end) if text[i].startswith("#pragma mark -")]
    if not marks:
        return []
    out = []
    for n, i in enumerate(marks):
        title = text[i].split("-", 1)[1].strip()
        stop = marks[n + 1] if n + 1 < len(marks) else end
        out.append((title, i, stop))
    return out


def pascal(title: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", title)
    return "".join(w[:1].upper() + w[1:] for w in words)


def plan(path: Path) -> None:
    text = lines(path)
    impls = blocks(text, r"^@implementation\s+([A-Za-z_]\w*)")
    print(f"{path}")
    print(f"  lines: {len(text)}")
    print(f"  implementations: {len(impls)}")
    for name, a, b in impls:
        print(f"    {name}: lines {a+1}-{b+1}")
    if len(impls) == 1:
        name, a, b = impls[0]
        secs = section_ranges(text, a + 1, b)
        if secs and secs[0][1] > a + 1:
            intro = text[a + 1:secs[0][1]]
            if any(l.strip() and not l.strip().startswith(("//", "/*", "*")) for l in intro):
                secs.insert(0, ("implementation", a + 1, secs[0][1]))
        print(f"  sections: {len(secs)}")
        for title, x, y in secs:
            print(f"    {title}: lines {x+1}-{y+1}")
    statics = static_defs(text)
    if statics:
        print("  static helpers:")
        for name, body in statics.items():
            uses = sum(1 for l in text if name in l)
            print(f"    {name}: {len(body)} lines, {uses} mentions")
    h = path.with_suffix(".h")
    if h.exists():
        print(f"  header: {h} ({len(lines(h))} lines)")


def rel(p: str | Path) -> str:
    q = Path(p)
    return str(q.relative_to(ROOT)) if q.is_absolute() and q.is_relative_to(ROOT) else str(p)


def update_refs(old_rel: str, new_paths: list[str], offsets: dict[int, tuple[str, int]]) -> None:
    """Replace paths in Makefiles/docs and rewrite docs line references."""
    new_paths = [rel(p) for p in new_paths]
    for name in ("Makefile", "tests/Makefile"):
        p = ROOT / name
        if not p.exists():
            continue
        src = p.read_text().splitlines()
        out, changed = [], False
        for line in src:
            if old_rel in line:
                indent = line[:len(line) - len(line.lstrip())]
                tail = " \\" if line.rstrip().endswith("\\") else ""
                out.extend(f"{indent}{path}{tail}" for path in new_paths)
                changed = True
            else:
                out.append(line)
        if changed:
            p.write_text("\n".join(out) + "\n")
    doc_old = old_rel[4:] if old_rel.startswith("src/") else old_rel
    for p in (ROOT / "docs").rglob("*.md"):
        t = p.read_text()
        pat = re.compile(re.escape(doc_old) + r":(\d+)")
        out, pos, changed = [], 0, False
        for m in pat.finditer(t):
            line = int(m.group(1))
            if line in offsets:
                target, newline = offsets[line]
                out += [t[pos:m.start()], f"{rel(target)}:{newline}"]
                pos, changed = m.end(), True
        if changed:
            out.append(t[pos:])
            p.write_text("".join(out))


def write_class_split(path: Path, outdir: Path, apply: bool, class_out: dict[str, str]) -> None:
    text = lines(path)
    impls = blocks(text, r"^@implementation\s+([A-Za-z_]\w*)")
    if len(impls) < 2:
        sys.exit("classes mode needs at least two @implementation blocks")
    depth = 0
    for line in text[:impls[0][1]]:
        if line.startswith("#if"):
            depth += 1
        elif line.startswith("#endif"):
            depth -= 1
    if depth > 0:
        sys.exit("refusing: a top-level #if block spans the implementations; split manually")
    header = path.with_suffix(".h")
    htext = lines(header) if header.exists() else []
    raw_pre = text[:impls[0][1]]
    shared = strip_implementations(text)
    m_all = blocks(text, r"^@interface\s+([A-Za-z_]\w*)")
    m_ifaces, extensions = [], {}
    for n, a, b in m_all:
        block = text[a:b + 1]
        if re.match(r"^@interface\s+\w+\s*:", block[0]):
            m_ifaces.append((n, a, b))
        else:
            extensions.setdefault(n, []).extend(block)
    h_ifaces = blocks(htext, r"^@interface\s+([A-Za-z_]\w*)")
    ifaces = ([(n, htext[a:b + 1]) for n, a, b in h_ifaces] +
              [(n, text[a:b + 1]) for n, a, b in m_ifaces])
    pre = strip_interfaces(shared)
    pre_imports = imports(pre)
    pre_no_imports = [l for l in pre if not l.startswith(("#import", "#include"))]
    fn_ranges = function_ranges(pre_no_imports, static=False)
    globals_ = {name: pre_no_imports[a:b] for name, a, b in fn_ranges}
    all_global_ranges = fn_ranges + variable_ranges(pre_no_imports)
    globals_lines = [l for a, b in [(a, b) for _, a, b in all_global_ranges] for l in pre_no_imports[a:b]]
    rest = [l for i, l in enumerate(pre_no_imports)
            if not any(a <= i < b for _, a, b in all_global_ranges)]
    header_pre = strip_interfaces(htext) if htext else []
    groups: dict[str, list[str]] = {}
    for name, a, b in impls:
        groups.setdefault(name, []).extend(text[a:b + 1])
    new_paths, offsets = [], {}
    print(f"{path}: {len(groups)} classes")
    for name, body in groups.items():
        iface = next((body for n, body in ifaces if n == name), None)
        dest = outdir / class_out.get(name, "")
        hout = dest / f"{name}.h"
        mout = dest / f"{name}.m"
        print(f"  {name}: {hout.relative_to(ROOT) if hout.is_relative_to(ROOT) else hout}, "
              f"{mout.relative_to(ROOT) if mout.is_relative_to(ROOT) else mout}")
        if not apply:
            continue
        dest.mkdir(parents=True, exist_ok=True)
        if iface:
            super_name = next((m.group(1) for l in iface
                               if (m := re.match(r"^@interface\s+\w+\s*:\s*(\w+)", l))), None)
            hlines = header_pre[:]
            if super_name in groups and super_name != name:
                hlines.append(f'#import "{super_name}.h"')
            others = [c for c in groups if c not in (name, super_name)]
            if others:
                hlines.append("@class " + ", ".join(others) + ";")
            hout.write_text("\n".join(hlines + [""] + iface) + "\n")
        mlines = pre_imports[:]
        if iface:
            mlines.append(f'#import "{name}.h"')
        for other in groups:
            if other != name:
                mlines.append(f'#import "{other}.h"')
        mlines += [""] + extensions.get(name, []) + [""] + rest + [""] + body
        mout.write_text("\n".join(mlines) + "\n")
        new_paths += [str(hout), str(mout)]
    if globals_:
        support = outdir / f"{path.stem}Support.m"
        print(f"  support: {support.relative_to(ROOT) if support.is_relative_to(ROOT) else support}")
        if apply:
            slines = pre_imports[:]
            first_header = next((p for p in new_paths if p.endswith(".h")), None)
            if first_header:
                slines.append(f'#import "{Path(first_header).name}"')
            slines += [""] + rest + [""] + globals_lines
            support.write_text("\n".join(slines) + "\n")
            new_paths.append(str(support))
    if not apply:
        return
    old_rel = rel(path)
    # docs line mapping: class implementation start -> new file implementation start
    for name, a, b in impls:
        dest = outdir / class_out.get(name, "")
        mout = dest / f"{name}.m"
        newline = next(i + 1 for i, l in enumerate(lines(mout))
                       if l.startswith("@implementation"))
        for oldline in range(a + 1, b + 2):
            offsets.setdefault(oldline, (rel(mout), newline + (oldline - (a + 1))))
    update_refs(old_rel, [p for p in new_paths if p.endswith((".m", ".mm", ".c"))], offsets)
    new_set = {Path(p) for p in new_paths}
    if path not in new_set and path.exists():
        path.unlink()
    if header and header not in new_set and header.exists():
        header.unlink()


def header_chunks(htext: list[str]) -> list[str]:
    start = next((i for i, l in enumerate(htext) if is_iface(l)), None)
    if start is None:
        return []
    end = next(i for i in range(start + 1, len(htext)) if htext[i].strip() == "@end")
    body = htext[start + 1:end]
    out, cur = [], None
    for line in body:
        if line.startswith("#pragma mark"):
            continue
        if re.match(r"^[-+]\s*\(", line) or line.startswith("@property"):
            if cur is not None:
                out.append(cur)
            cur = [line]
        elif cur is not None:
            cur.append(line)
    if cur is not None:
        out.append(cur)
    for i in range(len(out) - 1):
        move = []
        while out[i] and (not out[i][-1].strip() or out[i][-1].lstrip().startswith("//")):
            move.insert(0, out[i].pop())
        out[i + 1] = move + out[i + 1]
    return ["\n".join(c).strip() for c in out]


def sel_of(chunk: str) -> str | None:
    line = next((l for l in chunk.splitlines()
                 if re.match(r"^[-+]\s*\(", l) or l.startswith("@property")), "")
    m = re.match(r"^[-+]\s*\(\s*[^)]*\)\s*([A-Za-z_]\w*)", line)
    if m:
        return m.group(1)
    if line.startswith("@property"):
        names = re.findall(r"([A-Za-z_]\w*)\s*;", line)
        return names[-1] if names else None
    return None


def write_section_split(path: Path, base: str, outdir: Path, header: Path | None,
                       umbrella: Path | None, mapping: dict[str, str], apply: bool) -> None:
    text = lines(path)
    impls = blocks(text, r"^@implementation\s+([A-Za-z_]\w*)")
    if len(impls) != 1:
        sys.exit("sections mode needs exactly one @implementation")
    class_name, a, b = impls[0]
    secs = section_ranges(text, a + 1, b)
    if secs and secs[0][1] > a + 1:
        intro = text[a + 1:secs[0][1]]
        if any(l.strip() and not l.strip().startswith(("//", "/*", "*")) for l in intro):
            secs.insert(0, ("implementation", a + 1, secs[0][1]))
    if not secs:
        sys.exit("no #pragma mark - sections found")
    pre = strip_interfaces(text[:a] + text[b + 1:])
    pre_imports = imports(pre)
    if header and header.exists():
        pre_imports = [l for l in pre_imports if f'"{header.name}"' not in l]
    pre_no_imports = [l for l in pre if not l.startswith(("#import", "#include"))]
    fn_ranges = function_ranges(pre_no_imports, static=False)
    globals_ = {name: pre_no_imports[a:b] for name, a, b in fn_ranges}
    all_global_ranges = fn_ranges + variable_ranges(pre_no_imports)
    globals_lines = [l for a, b in [(a, b) for _, a, b in all_global_ranges] for l in pre_no_imports[a:b]]
    rest = [l for i, l in enumerate(pre_no_imports)
            if not any(a <= i < b for _, a, b in all_global_ranges)]
    statics = static_defs(text)
    pre_statics = {name: block for name, block in static_defs(rest).items()
                   if any("{" in line for line in block)}
    htext = lines(header) if header and header.exists() else []
    header_pre = strip_interfaces(htext) if htext else []
    chunks = header_chunks(htext) if htext else []
    used_chunks = set()
    new_paths, offsets = [], {}
    print(f"{path}: {class_name}, {len(secs)} sections")
    cat_base = pascal(base.split("+")[-1])
    for title, x, y in secs:
        suffix = mapping.get(title) or pascal(title)
        filename = f"{base}{suffix}"
        category = f"{cat_base}{suffix}"
        body = text[x:y]
        used_statics = []
        for name, block in statics.items():
            if name in pre_statics:
                continue
            defined_here = any(re.match(rf"^static\b.*\b{re.escape(name)}\s*\(", l) and "{" in l
                               for l in body)
            if defined_here:
                continue
            if re.search(rf"\b{re.escape(name)}\b", "\n".join(body)):
                used_statics.append(block)
        mout = outdir / f"{filename}.m"
        hout = outdir / f"{filename}.h" if chunks else None
        print(f"  {title!r} -> {filename} ({len(body)} lines)")
        if not apply:
            continue
        outdir.mkdir(parents=True, exist_ok=True)
        mlines = pre_imports[:]
        if hout:
            mlines.append(f'#import "{filename}.h"')
        if globals_lines:
            mlines.append(f'#import "{base}Support.h"')
        mlines += [""] + rest
        for block in used_statics:
            mlines += [""] + block
        mlines += [f"", f"@implementation {class_name} ({category})", ""] + body + ["", "@end"]
        mout.write_text("\n".join(mlines) + "\n")
        new_paths.append(str(mout))
        if hout and chunks:
            assigned = []
            for c in chunks:
                s = sel_of(c)
                if s and re.search(rf"^\s*[-+].*\b{re.escape(s)}\b", "\n".join(body), re.M):
                    assigned.append(c)
                    used_chunks.add(c)
            hout.write_text("\n".join(header_pre + [""] +
                                      [f"@interface {class_name} ({category})", ""] +
                                      assigned + ["", "@end"]) + "\n")
            new_paths.append(str(hout))
        for oldline in range(x + 1, y + 1):
            newline = next(i + 1 for i, l in enumerate(lines(mout))
                           if l.startswith("@implementation")) + (oldline - (x + 1))
            offsets.setdefault(oldline, (rel(mout), newline))
    support_paths = []
    if globals_lines:
        sup_m = outdir / f"{base}Support.m"
        sup_h = outdir / f"{base}Support.h"
        support_paths = [str(sup_h), str(sup_m)]
        if apply:
            decls = []
            for name, block in globals_.items():
                first = block[0]
                m = re.match(r"^(.*?)\b([A-Za-z_]\w*)\s*\((.*)\)", first)
                if m:
                    decls.append(f"{m.group(1).strip()} {m.group(2)}({m.group(3)});")
            sup_h.write_text("#import \"TGClient+Base.h\"\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n" +
                              "\n".join(decls) + "\n\n#ifdef __cplusplus\n}\n#endif\n")
            sup_m.write_text("\n".join(pre_imports + [f'#import "{base}Support.h"'] +
                                       [""] + rest + [""] + globals_lines) + "\n")
            new_paths += support_paths
    if not apply:
        return
    if chunks and used_chunks != set(chunks):
        missing = [c for c in chunks if c not in used_chunks]
        names = [sel_of(c) for c in missing]
        print(f"  warning: header methods not assigned: {names}", file=sys.stderr)
        base_name = base.split("+")[-1]
        misc = outdir / f"{base}Misc.h"
        category = f"{cat_base}Misc"
        misc.write_text("\n".join(header_pre + [""] +
                                  [f"@interface {class_name} ({category})", ""] +
                                  missing + ["", "@end"]) + "\n")
        new_paths.append(str(misc))
    old_rel = rel(path)
    update_refs(old_rel, [p for p in new_paths if p.endswith((".m", ".mm", ".c"))], offsets)
    path.unlink()
    if header:
        header.unlink()
    if umbrella and header:
        ut = umbrella.read_text()
        old_import = f'#import "{header.name}"'
        if old_import in ut:
            ut = ut.replace(old_import, "\n".join(f'#import "{Path(p).name}"' for p in new_paths if p.endswith(".h")))
            umbrella.write_text(ut)


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan")
    p.add_argument("file")
    c = sub.add_parser("classes")
    c.add_argument("file")
    c.add_argument("--out", default=None)
    c.add_argument("--class-out", action="append", default=[])
    c.add_argument("--apply", action="store_true")
    s = sub.add_parser("sections")
    s.add_argument("file")
    s.add_argument("--base", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--headers", default=None)
    s.add_argument("--umbrella", default=None)
    s.add_argument("--map", action="append", default=[])
    s.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    path = Path(args.file)
    if not path.is_absolute():
        path = ROOT / path
    if args.cmd == "plan":
        plan(path)
    elif args.cmd == "classes":
        out = Path(args.out) if args.out else path.parent
        if not out.is_absolute():
            out = ROOT / out
        class_out = dict(item.split("=", 1) for item in args.class_out)
        write_class_split(path, out, args.apply, class_out)
    else:
        mapping = dict(item.split("=", 1) for item in args.map)
        out = Path(args.out)
        if not out.is_absolute():
            out = ROOT / out
        header = Path(args.headers) if args.headers else None
        umbrella = Path(args.umbrella) if args.umbrella else None
        write_section_split(path, args.base, out, header, umbrella, mapping, args.apply)


if __name__ == "__main__":
    main()
