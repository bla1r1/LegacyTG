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


def digests(path):
    data = open(path, "rb").read()
    return len(data), hashlib.md5(data).hexdigest(), hashlib.sha256(data).hexdigest()


def changelog_html():
    text = open(os.path.join(ROOT, "CHANGELOG.md")).read()
    out = []
    for block in re.split(r"^## ", text, flags=re.M)[1:]:
        lines = block.strip().splitlines()
        out.append("<h2>%s</h2>\n<ul>" % html.escape(lines[0].strip()))
        for line in lines[1:]:
            if line.startswith("- "):
                item = html.escape(line[2:].strip())
                item = re.sub(r"`([^`]+)`", r"<code>\1</code>", item)
                out.append("<li>%s</li>" % item)
        out.append("</ul>")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repo")
    parser.add_argument("deb")
    parser.add_argument("--keep", type=int, default=1,
                        help="newest debs to keep in debs/ (one: Cydia offers the latest)")
    args = parser.parse_args()

    debs = os.path.join(args.repo, "debs")
    os.makedirs(debs, exist_ok=True)
    shutil.copy2(args.deb, debs)
    found = sorted((f for f in os.listdir(debs) if f.endswith(".deb")),
                   key=lambda f: os.path.getmtime(os.path.join(debs, f)), reverse=True)
    for old in found[args.keep:]:
        os.remove(os.path.join(debs, old))

    stanzas = []
    for name in found[:args.keep]:
        path = os.path.join(debs, name)
        size, md5, sha = digests(path)
        control = deb_control(path).strip()
        stanzas.append("%s\nFilename: debs/%s\nSize: %d\nMD5sum: %s\nSHA256: %s\n"
                       % (control, name, size, md5, sha))
    packages = "\n".join(stanzas).encode()
    open(os.path.join(args.repo, "Packages"), "wb").write(packages)
    with gzip.GzipFile(os.path.join(args.repo, "Packages.gz"), "wb", mtime=0) as f:
        f.write(packages)
    open(os.path.join(args.repo, "Packages.bz2"), "wb").write(bz2.compress(packages))

    version = re.search(r"^Version: (.+)$", stanzas[0], re.M).group(1)
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

    # The landing page says which version the repository serves.
    landing = os.path.join(args.repo, "index.html")
    if os.path.exists(landing):
        short, _, build = version.partition("-")
        text = open(landing).read()
        text = re.sub(r"<!--version-->.*?<!--/version-->",
                      "<!--version-->Version %s (%s)<!--/version-->" % (short, build),
                      text, flags=re.S)
        open(landing, "w").write(text)

    page = os.path.join(args.repo, "depiction", PKG, "index.html")
    text = open(page).read()
    start = text.index("<h2>Changelog</h2>") + len("<h2>Changelog</h2>")
    end = text.index("</body>")
    open(page, "w").write(text[:start] + "\n" + changelog_html() + "\n" + text[end:])
    print("repo at %s: %s" % (version, ", ".join(found[:args.keep])))


if __name__ == "__main__":
    sys.exit(main())
