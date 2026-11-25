#!/usr/bin/env python3
"""update_repo.py REPO_DIR DEB [--keep N] - put a deb into the Cydia repository.

REPO_DIR is a checkout of the gh-pages branch. The deb is copied to debs/,
older debs beyond the newest N (default 1) are removed, and Packages,
Packages.gz, Packages.bz2 and Release are written again. The depiction page's
changelog is rebuilt from CHANGELOG.md, so the page and the app's own notes
say the same thing, and the landing page's version line follows the newest
deb. Nothing is committed or pushed.
"""
import argparse
import bz2
import gzip
import hashlib
import html
import io
import os
import re
import shutil
import sys
import tarfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PKG = "org.legacy.itg"


def deb_control(path):
    """The control file of a deb, read from its ar members."""
    data = open(path, "rb").read()
    assert data[:8] == b"!<arch>\n", "not an ar archive"
    pos = 8
    while pos < len(data):
        name = data[pos:pos + 16].decode().strip().rstrip("/")
        size = int(data[pos + 48:pos + 58].decode().strip())
        body = data[pos + 60:pos + 60 + size]
        pos += 60 + size + (size % 2)
        if name.startswith("control.tar"):
            with tarfile.open(fileobj=io.BytesIO(body)) as tar:
                member = next(m for m in tar.getmembers()
                              if m.name.lstrip("./") == "control")
                return tar.extractfile(member).read().decode()
    raise SystemExit("no control in " + path)


def deb_field(control, field):
    match = re.search(r"^%s:\s*(.+)$" % re.escape(field), control, re.M)
    return match.group(1).strip() if match else ""


def deb_version(path):
    """1.4-4 -> (1, 4, 4), for ordering debs newest first."""
    version = deb_field(deb_control(path), "Version")
    return tuple(int(n) for n in re.findall(r"\d+", version))


def digests(path):
    data = open(path, "rb").read()
    return len(data), hashlib.md5(data).hexdigest(), hashlib.sha256(data).hexdigest()


def changelog_html():
    text = open(os.path.join(ROOT, "CHANGELOG.md")).read()
    blocks = re.split(r"^## ", text, flags=re.M)[1:]
    out = []
    for idx, block in enumerate(blocks):
        lines = block.strip().splitlines()
        title = html.escape(lines[0].strip())
        items = []
        for line in lines[1:]:
            if line.startswith("- "):
                item = html.escape(line[2:].strip())
                item = re.sub(r"`([^`]+)`", r"<code>\1</code>", item)
                items.append("<li>%s</li>" % item)
        body = "<ul>\n%s\n</ul>" % "\n".join(items)
        if idx == 0:
            out.append("<h3>%s</h3>\n%s" % (title, body))
        else:
            out.append("<details><summary>%s</summary>\n%s\n</details>" % (title, body))
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo")
    parser.add_argument("debs", nargs="*", help=".deb file(s) to copy into debs/ before indexing")
    parser.add_argument("--keep", type=int, default=1,
                        help="newest debs to keep per package in debs/ (default 1)")
    args = parser.parse_args()

    debs_dir = os.path.join(args.repo, "debs")
    os.makedirs(debs_dir, exist_ok=True)
    for deb_path in args.debs:
        shutil.copy2(deb_path, debs_dir)

    # Group by Package ID so keeping N versions of one package never deletes
    # other packages (e.g. AppSync Unified) in the same repository.
    by_pkg = {}
    for name in os.listdir(debs_dir):
        if not name.endswith(".deb"):
            continue
        full = os.path.join(debs_dir, name)
        pkg_id = deb_field(deb_control(full), "Package") or name
        by_pkg.setdefault(pkg_id, []).append(name)

    kept = []
    for pkg_id in sorted(by_pkg.keys()):
        versions = sorted(by_pkg[pkg_id],
                          key=lambda f: deb_version(os.path.join(debs_dir, f)),
                          reverse=True)
        for old in versions[args.keep:]:
            os.remove(os.path.join(debs_dir, old))
        kept.extend((pkg_id, f) for f in versions[:args.keep])

    if not kept:
        raise SystemExit("no .deb files found in " + debs_dir)

    stanzas = []
    pkg_versions = {}
    for pkg_id, name in kept:
        path = os.path.join(debs_dir, name)
        size, md5, sha = digests(path)
        control = deb_control(path).strip()
        if pkg_id not in pkg_versions:
            pkg_versions[pkg_id] = deb_field(control, "Version")
        stanzas.append("%s\nFilename: debs/%s\nSize: %d\nMD5sum: %s\nSHA256: %s\n"
                       % (control, name, size, md5, sha))
    packages = "\n".join(stanzas).encode()
    open(os.path.join(args.repo, "Packages"), "wb").write(packages)
    with gzip.GzipFile(os.path.join(args.repo, "Packages.gz"), "wb", mtime=0) as f:
        f.write(packages)
    open(os.path.join(args.repo, "Packages.bz2"), "wb").write(bz2.compress(packages))

    version = pkg_versions.get(PKG) or next(iter(pkg_versions.values()))
    release = ["Origin: LegacyTG", "Label: LegacyTG", "Suite: stable",
               "Version: " + version, "Codename: ios", "Architectures: iphoneos-arm",
               "Components: main",
               "Description: LegacyTG: Telegram for iOS 6.0-12.5.7 on old iPhones and iPads.",
               "MD5Sum:"]
    index = ["Packages", "Packages.bz2", "Packages.gz"]
    for name in index:
        size, md5, _ = digests(os.path.join(args.repo, name))
        release.append(" %s %d %s" % (md5, size, name))
    release.append("SHA256:")
    for name in index:
        size, _, sha = digests(os.path.join(args.repo, name))
        release.append(" %s %d %s" % (sha, size, name))
    open(os.path.join(args.repo, "Release"), "w").write("\n".join(release) + "\n")

    # The landing page(s) say which version of LegacyTG the repository serves.
    for landing in [os.path.join(args.repo, "index.html"),
                    os.path.join(args.repo, "ru", "index.html")]:
        if os.path.exists(landing) and PKG in pkg_versions:
            short, _, build = version.partition("-")
            text = open(landing).read()
            text = re.sub(r"<!--version-->.*?<!--/version-->",
                          "<!--version-->Version %s (%s)<!--/version-->" % (short, build),
                          text, flags=re.S)
            open(landing, "w").write(text)

    for page in [os.path.join(args.repo, "depiction", PKG, "index.html"),
                 os.path.join(args.repo, "depiction", PKG, "ru", "index.html")]:
        if os.path.exists(page) and PKG in pkg_versions:
            text = open(page).read()
            if "<!--changelog-->" in text and "<!--/changelog-->" in text:
                text = re.sub(
                    r"<!--changelog-->.*?<!--/changelog-->",
                    "<!--changelog-->\n%s\n<!--/changelog-->" % changelog_html(),
                    text, count=1, flags=re.S)
                open(page, "w").write(text)
            else:
                start = text.index("<h2>Changelog</h2>") + len("<h2>Changelog</h2>")
                end = text.index("</body>")
                open(page, "w").write(text[:start] + "\n" + changelog_html() + "\n" + text[end:])
    print("repo at %s (%d package(s)): %s" % (
        version, len(by_pkg), ", ".join(name for _, name in kept)))


if __name__ == "__main__":
    sys.exit(main())
