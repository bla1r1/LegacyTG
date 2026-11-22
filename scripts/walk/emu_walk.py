#!/usr/bin/env python3
"""Plan for scripts/emu.sh walk: the walk file into a devwalk.txt for the app
and a lighttouch input script that unlocks, opens LegacyTG and shoots each step.

  emu_walk.py sections FILE              section names, one per line
  emu_walk.py plan FILE SECTION OUTDIR   writes OUTDIR/devwalk.txt and
                                         OUTDIR/walk.script, prints the seconds
                                         the session needs

devwalk.txt counts from the app's launch, the script from the emulator's
boot; WALK_LAUNCH is the gap between the two (the icon is tapped at 76 s).
The emulator is slow and its launch time drifts by a few seconds, so a shot
waits WALK_SHOT s after its step and the next step is WALK_STEP s later.
"""
import json, os, sys

LAUNCH = float(os.environ.get("WALK_LAUNCH", 80))   # boot second the app starts
FIRST = float(os.environ.get("WALK_FIRST", 30))     # chats loaded on the emulator
STEP = float(os.environ.get("WALK_STEP", 9))
SHOT = float(os.environ.get("WALK_SHOT", 6))
GAP = 0.7                                           # between routes of one step


def read(path):
    sections, current = {}, None
    order = []
    for raw in open(path, encoding="utf-8"):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            sections[current] = []
            order.append(current)
            continue
        if current is None:
            sys.exit(f"{path}: step before any [section]: {line}")
        name, *routes = line.split()
        if not routes:
            sys.exit(f"{path}: step {name} has no route")
        sections[current].append((name, routes))
    return order, sections


def plan(steps, out):
    walk, script = [], []

    def touch(t, ph, x, y):
        script.append((t, {"cmd": "touch", "contacts": [{"id": 1, "phase": ph, "x": x, "y": y}]}))

    # Unlock, page two, the LegacyTG icon: the same timeline as `emu.sh test-fast`.
    script.append((62, {"cmd": "button", "button": 0, "down": True}))
    script.append((62.2, {"cmd": "button", "button": 0, "down": False}))
    touch(65, 0, 0.15, 0.89)
    for i in range(1, 15):
        touch(65 + i * .05, 1, 0.15 + i * .05, 0.89)
    touch(65.8, 2, 0.85, 0.89)
    touch(72, 0, 0.85, 0.5)
    for i in range(1, 12):
        touch(72 + i * .04, 1, 0.85 - i * .06, 0.5)
    touch(72.5, 2, 0.2, 0.5)
    touch(76, 0, 0.62, 0.125)
    touch(76.15, 2, 0.62, 0.125)

    for i, (name, routes) in enumerate(steps):
        t = FIRST + i * STEP
        # Whatever the step before left open goes first.
        walk.append((t - 1.0, "itglegacy://reset"))
        for k, route in enumerate(routes):
            walk.append((t + k * GAP, "itglegacy://" + route))
        script.append((LAUNCH + t + SHOT,
                       {"cmd": "screenshot", "path": f"{out}/{i + 1:02d}-{name}.bmp"}))

    secs = int(LAUNCH + FIRST + len(steps) * STEP + 10)
    with open(os.path.join(out, "devwalk.txt"), "w") as f:
        for t, url in walk:
            f.write(f"{t:.1f} {url}\n")
    with open(os.path.join(out, "walk.script"), "w") as f:
        for t, cmd in sorted(script, key=lambda e: e[0]):
            f.write(f"{t} {json.dumps(cmd)}\n")
    return secs


def main(argv):
    if len(argv) >= 2 and argv[0] == "sections":
        print("\n".join(read(argv[1])[0]))
        return
    if len(argv) == 4 and argv[0] == "plan":
        order, sections = read(argv[1])
        if argv[2] not in sections:
            sys.exit(f"no section {argv[2]}; have {' '.join(order)}")
        print(plan(sections[argv[2]], argv[3]))
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
