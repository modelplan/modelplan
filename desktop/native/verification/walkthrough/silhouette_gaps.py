# SPDX-License-Identifier: MIT
"""Hairline-gap scan for a window capture that keeps its alpha (the walkthrough's *.window.png).

Owner test build 6 showed a light line inside the closed cockpit between the cap's rim and the title bar; the CI desktop
is black, so a screenshot cannot show it, but the window PNG's alpha can. The same rule runs in the browser spec
(desktop/tests/cockpit/png-alpha.mjs): from the first fully opaque row down to the last row that is still at least
`bottom_solid` opaque, any row whose central columns (the middle `core`, which skips the rounded shoulders) are not fully
opaque across `share` of that width is a gap. Pure standard library: the CI Mac has no imaging package.
"""
import struct
import zlib


def read_rgba(path):
    """(width, height, rows) of an 8-bit RGB or RGBA PNG; each row is the list of its alpha values (255 for RGB)."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG: %s" % path)
    pos, idat, header = 8, b"", None
    while pos < len(data):
        size, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + size]
        pos += 12 + size
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
    width, height, depth, colour, _, _, interlace = header
    if depth != 8 or colour not in (2, 6) or interlace:
        raise ValueError("expected a plain 8-bit RGB/RGBA PNG, got depth %d colour %d interlace %d" % (depth, colour, interlace))
    bpp = 4 if colour == 6 else 3
    stride = width * bpp
    raw, rows, prev, at = zlib.decompress(idat), [], bytearray(stride), 0
    for _ in range(height):
        kind, line, at = raw[at], bytearray(raw[at + 1:at + 1 + stride]), at + 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([line[x * bpp + 3] if bpp == 4 else 255 for x in range(width)])
        prev = line
    return width, height, rows


def interior_gaps(rows, share=0.2, core=0.6, solid=0.5, bottom_solid=0.9):
    """Rows (index, share) inside the silhouette that are not fully opaque across `share` of its central width."""
    width = len(rows[0]) if rows else 0
    painted = [x for row in rows for x in range(width) if row[x] >= 128]
    if not painted:
        return [(0, 1.0)]
    left, right = min(painted), max(painted)
    span = right - left + 1
    x0, x1 = int(left + span * (1 - core) / 2 + 0.999), int(right - span * (1 - core) / 2)
    columns = max(1, x1 - x0 + 1)

    def fraction(row, test):
        return sum(1 for x in range(x0, x1 + 1) if test(row[x])) / columns

    opaque = [fraction(row, lambda a: a == 255) for row in rows]
    top = next((y for y, f in enumerate(opaque) if f >= solid), None)
    bottom = max((y for y, f in enumerate(opaque) if f >= bottom_solid), default=None)
    if top is None or bottom is None:
        return [(0, 1.0)]
    found = []
    for y in range(top, bottom + 1):
        f = fraction(rows[y], lambda a: a < 255)
        if f >= share:
            found.append((y, round(f, 3)))
    return found


def check_window(path, **options):
    """Gap rows of the window PNG at `path`; empty when the silhouette is solid."""
    _, _, rows = read_rgba(path)
    return interior_gaps(rows, **options)
