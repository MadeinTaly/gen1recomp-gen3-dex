#!/usr/bin/env python3
"""Turns the raw frames from tools/render_screen.lua into PNGs.

    python3 tools/rgb_to_png.py <dir> [width] [height]

One PNG per .rgb, plus `sheet.png` with all of them side by side, which is
the one worth opening: a backdrop is chosen by comparing, not by admiring.
"""
import os
import struct
import sys
import zlib


def png(path, w, h, rgb):
    raw = b"".join(b"\x00" + rgb[y * w * 3:(y + 1) * w * 3] for y in range(h))
    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body
                + struct.pack(">I", zlib.crc32(tag + body) & 0xffffffff))
    open(path, "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b""))


def main(directory, w, h):
    files = sorted(f for f in os.listdir(directory) if f.endswith(".rgb"))
    if not files:
        print("no frames in " + directory)
        return 1
    frames = []
    for f in files:
        data = open(os.path.join(directory, f), "rb").read()
        if len(data) != w * h * 3:
            print("%s is %d bytes, expected %d — wrong width/height?"
                  % (f, len(data), w * h * 3))
            return 1
        png(os.path.join(directory, f[:-4] + ".png"), w, h, data)
        frames.append((f[:-4], data))
        print("%s -> %s.png" % (f, f[:-4]))

    cols = min(4, len(frames))
    rows = (len(frames) + cols - 1) // cols
    sw, sh = cols * (w + 2), rows * (h + 2)
    sheet = bytearray(b"\x30" * (sw * sh * 3))
    for i, (_, data) in enumerate(frames):
        ox, oy = (i % cols) * (w + 2) + 1, (i // cols) * (h + 2) + 1
        for y in range(h):
            at = ((oy + y) * sw + ox) * 3
            sheet[at:at + w * 3] = data[y * w * 3:(y + 1) * w * 3]
    png(os.path.join(directory, "sheet.png"), sw, sh, bytes(sheet))
    print("sheet.png: " + ", ".join(n for n, _ in frames))
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    sys.exit(main(args[0] if args else "/tmp/dex",
                  int(args[1]) if len(args) > 1 else 160,
                  int(args[2]) if len(args) > 2 else 144))
