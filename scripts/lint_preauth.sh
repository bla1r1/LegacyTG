#!/bin/sh
# lint_preauth.sh - what the login screens send before the user is signed in.
#
# Until authorizationStateReady TDLib answers 401 Unauthorized to every request
# that is not on its pre-authentication, authentication, pre-initialization or
# synchronous lists (Td::is_preauthentication_request and its neighbours in
# tdlib/td/td/telegram/Td.cpp). B38 was getCountry on the phone step: the
# Country row stayed empty on every fresh install.
#
# This starts from every store and TGClient call in src/Features/Auth and the
# login callbacks in AppDelegate's showLoginUI, follows [self ...] and the
# store/TGClient calls inside those methods four levels deep, and fails on any
# TDLib function they send that TDLib would refuse. A call that only ever runs
# signed in goes in ALLOW below with the reason.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT" || exit 1

python3 - <<'PY'
import re, glob, sys

# selector or file -> why it never runs signed out
ALLOW = {
    'setProfilePhotoAtPath': 'after registerUser answers ok; AuthManager sets State::Ok before it answers',
    'src/Features/Auth/TGQRViewController.m': 'the scanner opens only from Settings > Devices',
}

td = open('tdlib/td/td/telegram/Td.cpp').read()
td += open('tdlib/td/td/telegram/SynchronousRequests.cpp').read()
allowed = set()
for fn in ('is_preauthentication_request', 'is_authentication_request',
           'is_preinitialization_request', 'is_synchronous_request'):
    m = re.search(r'bool \w+::' + fn + r'\(.*?\{(.*?)\n\}', td, re.S)
    if not m:
        sys.exit('lint_preauth: %s not found in TDLib' % fn)
    allowed |= set(re.findall(r'td_api::(\w+)::ID', m.group(1)))

scheme = open('tdlib/td/td/generate/scheme/td_api.tl').read()
functions = set(re.findall(r'^(\w+)\s.*=\s*\w+;$',
                           scheme.split('---functions---', 1)[1], re.M))

# Every method body in the stores and the client, by its first keyword.
bodies = {}
for path in glob.glob('src/Core/Stores/*.m') + glob.glob('src/Core/Client/**/*.m', recursive=True) \
        + glob.glob('src/Core/Client/**/*.mm', recursive=True):
    text = open(path, errors='replace').read()
    for m in re.finditer(r'^[-+]\s*\([^)]*\)\s*(\w+)(.*?)^\}', text, re.M | re.S):
        bodies.setdefault(m.group(1), []).append(m.group(2))

CALL = re.compile(r'\[(?:\[\w+ shared\]|self|me|weakSelf|tg|client)\s+(\w+)')
TYPE = re.compile(r'@"@type"\s*:\s*@"(\w+)"')

def sends(sel, depth, seen):
    out = set()
    if sel in seen or depth > 4 or sel in ALLOW:
        return out
    seen.add(sel)
    for body in bodies.get(sel, []):
        out |= {t for t in TYPE.findall(body) if t in functions}
        for inner in CALL.findall(body):
            out |= sends(inner, depth + 1, seen)
    return out

entries = []
for path in sorted(glob.glob('src/Features/Auth/*.m')):
    if path in ALLOW:
        continue
    for i, line in enumerate(open(path, errors='replace'), 1):
        for sel in re.findall(r'\[\[(?:TG\w+Store|TGClient) shared\]\s+(\w+)', line):
            entries.append((sel, '%s:%d' % (path, i)))
app = open('src/App/AppDelegate.m').read()
login = re.search(r'- \(void\)showLoginUI \{(.*?)^\}', app, re.M | re.S).group(1)
for sel in re.findall(r'\[\[(?:TG\w+Store|TGClient) shared\]\s+(\w+)', login):
    entries.append((sel, 'src/App/AppDelegate.m showLoginUI'))

bad = 0
for sel, where in entries:
    if sel in ALLOW:
        continue
    for t in sorted(sends(sel, 0, set()) - allowed):
        print('  %s: %s sends %s, which TDLib refuses with 401 before sign-in' % (where, sel, t))
        bad += 1
print('  %d login calls checked' % len(entries))
sys.exit(1 if bad else 0)
PY
