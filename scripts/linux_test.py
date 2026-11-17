#!/usr/bin/env python3
"""Run the host test suite on Linux, as far as Foundation reaches.

The macOS suite (make -f tests/Makefile test) links AppKit, CoreGraphics and
VideoToolbox. On Linux, GNUstep (Foundation and AppKit on libobjc2 and
libdispatch, the cairo backend under Xvfb; scripts/linux_setup.sh builds it
into build/gnustep) stands in, through the same tests/shim UIKit-to-AppKit
mapping the Mac run uses. Text is measured by cairo and FreeType rather than
Core Text, so a test that pins exact point widths can differ by a point.

Every source of the client binary (CLIENT_OBJC_SRCS and helpers in
tests/Makefile) is compiled once into build/linux-test/obj, again only when it
or a header it reads changed. Then each test file gets its own binary - a
main that #imports it, linked with the objects that compiled - and runs. A
test file that does not compile or link on Linux is reported as such, not
as a failure; a failing assertion is a failure.

    scripts/linux_test.py                 every client test file
    scripts/linux_test.py TGFooTests.m    those files
    scripts/linux_test.py -j 8            parallel compiles (default: CPUs)

Exit status 1 when an assertion fails or a test file crashes.
"""
import concurrent.futures, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
PREFIX = os.path.join(ROOT, 'build', 'gnustep')
OUT = os.path.join(ROOT, 'build', 'linux-test')
OBJ = os.path.join(OUT, 'obj')
BIN = os.path.join(OUT, 'bin')
DISPLAY = ':%d' % (90 + os.getpid() % 100)


def makefile_list(name):
    text = open('tests/Makefile').read()
    m = re.search(r'^%s\s*:=\s*((?:.*\\\n)*.*)$' % name, text, re.M)
    if not m:
        return []
    items = re.split(r'\s+', m.group(1).replace('\\\n', ' ').strip())
    out = []
    for item in items:
        item = item.replace('$(SRC)', 'src').replace('$(TESTS)', 'tests').replace('$(ROOT)/', '')
        if item and not item.startswith('$('):
            out.append(item)
    return out


def gnustep(flag):
    env = dict(os.environ, PATH=os.path.join(PREFIX, 'bin') + ':' + os.environ['PATH'])
    return subprocess.check_output(['gnustep-config', flag], env=env, text=True).split()


def flags():
    objc = [f for f in gnustep('--objc-flags') if f not in ('-MMD', '-MP', '-Wall', '-O2')]
    inc = ['-Itests/linux', '-Itests/shim', '-Ivendor/include', '-Isrc/Compat', '-Ibuild/linux-check']
    for d, _, _ in os.walk('src'):
        inc.append('-I' + d)
    inc += ['-Ithird_party', '-Ithird_party/nanosvg', '-Ivendor/libs', '-Ithird_party/libtgvoip', '-Itests']
    # `unix` is a predefined macro on Linux; the sources use it as a name.
    return objc + ['-fobjc-arc', '-fblocks', '-O0', '-g', '-w', '-Uunix', '-DDEBUG=1', '-DTG_DEV=1',
                   '-DTG_LINUX_HOST=1', '-include', 'tests/linux/prefix.h'] + inc


def obj_path(src):
    return os.path.join(OBJ, src + '.o')


def stale(src, obj):
    if not os.path.exists(obj):
        return True
    t = os.path.getmtime(obj)
    dep = obj[:-2] + '.d'
    if not os.path.exists(dep):
        return True
    for path in re.split(r'[\s\\]+', open(dep).read().split(':', 1)[-1]):
        if path and os.path.exists(path) and os.path.getmtime(path) > t:
            return True
    return False


def compile_one(src, cflags):
    obj = obj_path(src)
    os.makedirs(os.path.dirname(obj), exist_ok=True)
    if not stale(src, obj):
        return src, True, ''
    cmd = ['clang'] + cflags + (['-std=c++14', '-stdlib=libc++'] if src.endswith(('.mm', '.cpp')) else []) + \
          ['-MMD', '-MF', obj[:-2] + '.d', '-c', src, '-o', obj]
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0 and os.path.exists(obj):
        os.remove(obj)
    first = next((l for l in p.stderr.splitlines() if 'error' in l), '')
    return src, p.returncode == 0, first


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-j')]
    jobs = os.cpu_count() or 4
    for a in sys.argv[1:]:
        if a.startswith('-j'):
            jobs = int(a[2:] or jobs)
    if not os.path.exists(os.path.join(PREFIX, 'lib', 'libgnustep-base.so')):
        sys.exit('no GNUstep in build/gnustep: run scripts/linux_setup.sh')
    # tg_config.h is private. Without it the example's values stand in, and
    # tg_api_key.h is generated from them as the Makefile does, so the key
    # round-trip test checks two files that agree.
    if not os.path.exists('vendor/include/tg_config.h'):
        os.makedirs('build/linux-check', exist_ok=True)
        config = 'build/linux-check/tg_config.h'
        example = open('vendor/include/tg_config.h.example').read()
        if not os.path.exists(config) or open(config).read() != example:
            open(config, 'w').write(example)
        key = 'build/linux-check/tg_api_key.h'
        if not os.path.exists(key) or os.path.getmtime(key) < os.path.getmtime(config) \
                or 'kTGApiIdMasked = 0,' in open(key).read():
            subprocess.check_call([sys.executable, 'scripts/gen_api_key.py', config, key])
    cflags = flags()
    sources = [s for s in makefile_list('CLIENT_OBJC_SRCS') + makefile_list('CLIENT_HELPER_SRCS')
               if os.path.exists(s)] + ['tests/linux/QuartzCoreShim.m', 'tests/linux/LinuxCompat.m']
    tests = makefile_list('CLIENT_TEST_SRCS')
    if args:
        tests = [t for t in tests if os.path.basename(t) in args or t in args]

    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        results = list(pool.map(lambda s: compile_one(s, cflags), sources))
    built = [s for s, ok, _ in results if ok]
    broken = {s: why for s, ok, why in results if not ok}
    print('  sources: %d compile on Linux, %d do not' % (len(built), len(broken)))

    # One archive, linked whole: Objective-C categories are only found at
    # run time, so the linker must not drop an object nothing names.
    lib = os.path.join(OUT, 'libclient.a')
    if os.path.exists(lib):
        os.remove(lib)
    subprocess.check_call(['ar', 'rcs', lib] + [obj_path(s) for s in built])
    libs = gnustep('--gui-libs') + ['-ldispatch', '-lcrypto', '-lssl', '-lwebp', '-lz', '-lopal',
                                    '-lgnustep-corebase', '-lc++', '-lc++abi', '-lm', '-ldl']

    os.makedirs(BIN, exist_ok=True)
    # GNUstep's backend talks to an X server even to measure text: one
    # virtual screen for the whole run.
    xvfb = subprocess.Popen(['Xvfb', DISPLAY, '-screen', '0', '640x480x24', '-nolisten', 'tcp'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # main_client.mm is one translation unit: a test file may lean on a
    # stand-in an earlier file declared. Such a file is built again with
    # every file before it, in the Mac order, and run alone.
    order = re.findall(r'#import "(\w+Tests\.mm?)"', open('tests/main_client.mm').read())

    def link(name, imports, tag):
        main_m = os.path.join(BIN, name + tag + '_main.mm')
        # NSApplication loads the drawing backend, which is what measures
        # text in GNUstep; the tests never open a window.
        open(main_m, 'w').write('#import <AppKit/AppKit.h>\n#import "TGTestRunner.h"\n%s'
                                'int main(void) { @autoreleasepool { [NSApplication sharedApplication]; '
                                'TGTestRunnerRun(); return _tg_failed > 0 ? 1 : 0; } }\n'
                                % ''.join('#import "%s"\n' % os.path.join(ROOT, i) for i in imports))
        exe = os.path.join(BIN, name)
        cmd = ['clang'] + cflags + ['-std=c++14', '-stdlib=libc++'] + \
              [main_m, '-Wl,--whole-archive', lib, '-Wl,--no-whole-archive'] + libs + ['-o', exe]
        return exe, subprocess.run(cmd, capture_output=True, text=True)

    def build_test(test):
        name = os.path.splitext(os.path.basename(test))[0]
        exe, p = link(name, [test], '')
        base = os.path.basename(test)
        if p.returncode != 0 and base in order:
            prefix = ['tests/' + t for t in order[:order.index(base) + 1]]
            exe, p = link(name, prefix, '_prefix')
        if p.returncode != 0:
            undefined = re.findall(r"undefined reference to `([^']+)'", p.stderr)
            err = next((l for l in p.stderr.splitlines() if ' error:' in l and 'linker command' not in l),
                       next((l for l in p.stderr.splitlines() if 'ld' in l and ('error' in l or 'multiple' in l)), ''))
            return name, 'unbuilt', (('needs ' + undefined[0]) if undefined else err)[:160]
        try:
            run = subprocess.run([exe], capture_output=True, text=True, timeout=120, cwd=ROOT,
                                 env=dict(os.environ, DISPLAY=DISPLAY, TG_TEST_CLASS=name))
        except subprocess.TimeoutExpired:
            return name, 'failed', 'timed out after 120 s'
        tally = re.search(r'# (\d+) passed, (\d+) failed', run.stdout)
        if run.returncode != 0 or not tally:
            fails = [l for l in (run.stdout + run.stderr).splitlines()
                     if l.startswith('not ok') or '# FAIL' in l or 'EXCEPTION' in l]
            detail = ' | '.join(fails[:4]) or (run.stderr.strip().splitlines() or ['crashed'])[-1]
            return name, 'failed', detail[:400]
        return name, 'passed', '%s passed' % tally.group(1)

    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        outcomes = list(pool.map(build_test, tests))
    counts = {'passed': 0, 'failed': 0, 'unbuilt': 0}
    for name, state, detail in sorted(outcomes):
        counts[state] += 1
        if state != 'passed' or '-v' in sys.argv:
            print('  %-8s %s: %s' % (state, name, detail))
    print('  test files: %(passed)d passed, %(failed)d failed, %(unbuilt)d do not build on Linux' % counts)
    if '-v' in sys.argv:
        for s, why in sorted(broken.items()):
            print('  no-linux %s: %s' % (s, why[:160]))
    xvfb.terminate()
    sys.exit(1 if counts['failed'] else 0)


if __name__ == '__main__':
    main()
