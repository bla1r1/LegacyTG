#!/usr/bin/env python3
"""Read one official icon from official_ref/Images.xcassets.

  scripts/official_icon.py "Chat List/AddStoryIcon"

Prints `d w h` - an SVG path and its viewBox - on one line. Only the standard
library is used; Flate streams are expanded with zlib.

The PDFs are Figma exports: one page, a Flate content stream and a MediaBox
that is the icon's own box. Every painted path is copied with its `cm`
transform, and PDF's y-up user space is flipped into SVG's y-down space.
"""
import os
import re
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The official tree is not in git: TG_OFFICIAL_ASSETS, an agent worktree's
# official_ref/, or a checkout of the official source next to ours.
ASSETS = next((p for p in (
    os.environ.get('TG_OFFICIAL_ASSETS', ''),
    os.path.join(ROOT, 'official_ref', 'Images.xcassets'),
    os.path.join(ROOT, 'official', 'TelegramUI', 'Images.xcassets'),
) if p and os.path.isdir(p)), os.path.join(ROOT, 'official_ref', 'Images.xcassets'))

NUM = r'[-+]?(?:\d+\.\d*|\.\d+|\d+)'
TOKEN = re.compile(rb'[-+]?(?:\d+\.\d*|\.\d+|\d+)|[A-Za-z*\'"]+')


def find_file(spec):
    """`<Set>/<Name>` -> the first PDF in the .imageset."""
    if spec.lower().endswith('.pdf') and os.path.exists(spec):
        return spec
    set_name, _, icon_name = spec.partition('/')
    imageset = os.path.join(ASSETS, set_name, icon_name + '.imageset')
    if not os.path.isdir(imageset):
        sys.exit('no imageset ' + spec)
    for name in sorted(os.listdir(imageset)):
        if name.lower().endswith('.pdf'):
            return os.path.join(imageset, name)
    sys.exit('no PDF in ' + imageset)


def parse_objects(data):
    """number -> (dict bytes, decoded stream or None)."""
    objects = {}
    pos = 0
    while True:
        m = re.search(rb'(\d+)\s+(\d+)\s+obj\b', data[pos:])
        if not m:
            break
        start = pos + m.end()
        end = data.find(b'endobj', start)
        if end < 0:
            break
        body = data[start:end]
        stream = None
        sm = re.search(rb'stream\r?\n', body)
        if sm:
            dict_part = body[:sm.start()]
            stream_start = sm.end()
            endstream = body.find(b'endstream', stream_start)
            if endstream < 0:
                endstream = len(body)
            raw = body[stream_start:endstream]
            if raw.endswith(b'\r\n'):
                raw = raw[:-2]
            elif raw.endswith(b'\n') or raw.endswith(b'\r'):
                raw = raw[:-1]
            if b'/FlateDecode' in dict_part:
                try:
                    raw = zlib.decompress(raw)
                except zlib.error:
                    try:
                        raw = zlib.decompressobj().decompress(raw)
                    except zlib.error:
                        raw = b''
            stream = raw
            body = dict_part
        objects[int(m.group(1))] = (body, stream)
        pos = end + len(b'endobj')
    return objects


def media_box(objects, data):
    pattern = (rb'/MediaBox\s*\[\s*(' + NUM.encode() + rb')\s+(' +
               NUM.encode() + rb')\s+(' + NUM.encode() + rb')\s+(' +
               NUM.encode() + rb')\s*\]')
    for body, stream in objects.values():
        m = re.search(pattern, body)
        if m:
            return tuple(float(m.group(i)) for i in range(1, 5))
    m = re.search(pattern, data)
    if m:
        return tuple(float(m.group(i)) for i in range(1, 5))
    return (0.0, 0.0, 24.0, 24.0)


def content_streams(objects, data):
    """The page's /Contents stream, or every stream if there is no page."""
    for body, stream in objects.values():
        if not re.search(rb'/Type\s*/Page(?!s)', body):
            continue
        m = re.search(rb'/Contents\s*(\[[^\]]*\]|\d+\s+\d+\s+R)', body)
        if not m:
            continue
        refs = [int(x) for x in re.findall(rb'(\d+)\s+\d+\s+R', m.group(1))]
        out = [objects[r][1] for r in refs if r in objects and objects[r][1]]
        if out:
            return out
    return [s for _, s in objects.values() if s]


def mul(a, b):
    """PDF matrix product: a then b."""
    return (a[0] * b[0] + a[1] * b[2], a[0] * b[1] + a[1] * b[3],
            a[2] * b[0] + a[3] * b[2], a[2] * b[1] + a[3] * b[3],
            a[4] * b[0] + a[5] * b[2] + b[4], a[4] * b[1] + a[5] * b[3] + b[5])


def point(m, x, y):
    return (m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5])


def fmt(v):
    if abs(v) < 1e-6:
        v = 0.0
    s = ('%.4f' % v).rstrip('0').rstrip('.')
    return s or '0'


def to_path(stream, box):
    """Content stream -> one SVG path in the MediaBox's viewBox."""
    min_x, min_y, max_x, max_y = box

    def emit(pt):
        # PDF y grows up; SVG y grows down.
        return (fmt(pt[0] - min_x), fmt(max_y - pt[1]))

    ctm = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
    stack = []
    operands = []
    path = []
    out = []
    current = (0.0, 0.0)
    subpath_start = (0.0, 0.0)
    box_min = [1e9, 1e9]
    box_max = [-1e9, -1e9]
    clips = []
    paint_rect = False
    pts = []

    def mark(pt):
        pts.append(pt)
        box_min[0] = min(box_min[0], pt[0])
        box_min[1] = min(box_min[1], pt[1])
        box_max[0] = max(box_max[0], pt[0])
        box_max[1] = max(box_max[1], pt[1])

    def close_subpath():
        path.append('Z')

    def flush():
        if not path:
            return
        d = ''.join(path)
        minx, miny, maxx, maxy = box_min[0], box_min[1], box_max[0], box_max[1]
        quad = bool(pts) and all(
                ((abs(p[0] - minx) < 1e-4 or abs(p[0] - maxx) < 1e-4) and
                 (abs(p[1] - miny) < 1e-4 or abs(p[1] - maxy) < 1e-4))
                for p in pts)
        # Quartz exports a filled shape as a clipping path followed by a
        # rectangle that covers it and is then filled. The visible result is
        # the clip, so emit that instead of the rectangle. Several clips can
        # stack; the smallest non-rectangular one inside the paint is the
        # glyph's own outline.
        if paint_rect or quad:
            candidate = None
            for cd, cbox, crect in clips:
                if crect:
                    continue
                if paint_rect_covers((box_min[0], box_min[1], box_max[0], box_max[1]),
                                     cbox):
                    area = (cbox[2] - cbox[0]) * (cbox[3] - cbox[1])
                    if candidate is None or area < candidate[0]:
                        candidate = (area, cd)
            if candidate:
                d = candidate[1]
        out.append(d)

    def paint_rect_covers(rect, inner):
        return (rect[0] <= inner[0] + 0.01 and rect[1] <= inner[1] + 0.01 and
                rect[2] >= inner[2] - 0.01 and rect[3] >= inner[3] - 0.01)

    for m in TOKEN.finditer(stream):
        token = m.group(0)
        try:
            operands.append(float(token))
            continue
        except ValueError:
            pass
        op = token.decode('latin-1')

        if op == 'q':
            stack.append((ctm, list(clips)))
        elif op == 'Q':
            if stack:
                ctm, clips = stack.pop()
                clips = list(clips)
        elif op == 'cm' and len(operands) >= 6:
            ctm = mul(tuple(operands[-6:]), ctm)
        elif op == 'm' and len(operands) >= 2:
            current = (operands[-2], operands[-1])
            subpath_start = current
            p = point(ctm, *current)
            mark(p)
            path.append('M%s %s' % emit(p))
        elif op == 'l' and len(operands) >= 2:
            current = (operands[-2], operands[-1])
            p = point(ctm, *current)
            mark(p)
            path.append('L%s %s' % emit(p))
        elif op == 'c' and len(operands) >= 6:
            x1, y1, x2, y2, x3, y3 = operands[-6:]
            p1 = point(ctm, x1, y1)
            p2 = point(ctm, x2, y2)
            p3 = point(ctm, x3, y3)
            mark(p1)
            mark(p2)
            mark(p3)
            path.append('C%s %s %s %s %s %s' % (emit(p1) + emit(p2) + emit(p3)))
            current = (x3, y3)
        elif op == 'v' and len(operands) >= 4:
            x2, y2, x3, y3 = operands[-4:]
            p1 = point(ctm, *current)
            p2 = point(ctm, x2, y2)
            p3 = point(ctm, x3, y3)
            mark(p1)
            mark(p2)
            mark(p3)
            path.append('C%s %s %s %s %s %s' % (emit(p1) + emit(p2) + emit(p3)))
            current = (x3, y3)
        elif op == 'y' and len(operands) >= 4:
            x1, y1, x3, y3 = operands[-4:]
            p1 = point(ctm, x1, y1)
            p3 = point(ctm, x3, y3)
            mark(p1)
            mark(p3)
            path.append('C%s %s %s %s %s %s' % (emit(p1) + emit(p3) + emit(p3)))
            current = (x3, y3)
        elif op == 'h':
            close_subpath()
            current = subpath_start
        elif op == 're' and len(operands) >= 4:
            x, y, w, h = operands[-4:]
            corners = [point(ctm, x, y), point(ctm, x + w, y),
                       point(ctm, x + w, y + h), point(ctm, x, y + h)]
            for c in corners:
                mark(c)
            path.append('M%s %s' % emit(corners[0]))
            for c in corners[1:]:
                path.append('L%s %s' % emit(c))
            close_subpath()
            current = (x, y)
            subpath_start = current
            paint_rect = True
        elif op in ('W', 'W*'):
            cd = ''.join(path) or None
            if cd:
                clips.append((cd, (box_min[0], box_min[1], box_max[0], box_max[1]),
                              paint_rect))
        elif op in ('f', 'F', 'f*', 'B', 'B*', 'b', 'b*', 'S', 's', 'n'):
            if op != 'n':
                flush()
            path = []
            box_min = [1e9, 1e9]
            box_max = [-1e9, -1e9]
            paint_rect = False
            pts = []
        operands = []
    flush()
    return ''.join(out)


def icon_path(spec):
    path = find_file(spec)
    with open(path, 'rb') as handle:
        data = handle.read()
    objects = parse_objects(data)
    box = media_box(objects, data)
    streams = content_streams(objects, data)
    d = ''.join(to_path(s, box) for s in streams)
    # A move followed only by a close paints nothing; Quartz leaves one where
    # a clip path's first subpath was empty.
    d = re.sub(r'M[-+0-9. ]+Z', '', d)
    if not d:
        sys.exit('no path in ' + path)
    return d, box[2] - box[0], box[3] - box[1]


def main(argv):
    if len(argv) != 2:
        sys.exit('usage: official_icon.py "<Set>/<Name>"')
    d, w, h = icon_path(argv[1])
    print('%s %s %s' % (d, fmt(w), fmt(h)))


if __name__ == '__main__':
    main(sys.argv)
