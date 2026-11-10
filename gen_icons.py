#!/usr/bin/env python3
"""生成 ai-switch 应用图标: GPU 服务开关"""
import zlib, struct

def png_write(path, w, h, px):
    raw = b"".join(b"\x00" + b"".join(bytes(p) for p in px[y*w:(y+1)*w]) for y in range(h))
    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f: f.write(png)

def rounded(buf, w, x0, y0, x1, y1, r, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            c = color
            for (cx, cy) in ((x0+r, y0+r), (x1-r-1, y0+r), (x0+r, y1-r-1), (x1-r-1, y1-r-1)):
                dx, dy = x-cx, y-cy
                if x < x0+r and y < y0+r and dx*dx+dy*dy > r*r: c = None
                if x >= x1-r and y < y0+r and dx*dx+dy*dy > r*r: c = None
                if x < x0+r and y >= y1-r and dx*dx+dy*dy > r*r: c = None
                if x >= x1-r and y >= y1-r and dx*dx+dy*dy > r*r: c = None
            if c is not None and 0 <= x < w: buf[y*w+x] = c

def circle(buf, w, cx, cy, r, color):
    for y in range(cy-r, cy+r+1):
        for x in range(cx-r, cx+r+1):
            if (x-cx)**2 + (y-cy)**2 <= r*r and 0 <= x < w:
                buf[y*w+x] = color

def make(size, path):
    s = size / 256.0
    bg = (0x2f, 0x6b, 0xff)
    green = (0x00, 0xb4, 0x2a)
    white = (0xff, 0xff, 0xff)
    buf = [bg] * (size * size)
    rounded(buf, size, 0, 0, size, size, int(56*s), bg)
    # 开关轨道 (白色圆角横条)
    rounded(buf, size, int(52*s), int(96*s), int(204*s), int(160*s), int(32*s), white)
    # 开启状态的绿色旋钮 (右侧)
    circle(buf, size, int(168*s), int(128*s), int(40*s), green)
    # GPU 小标 (左上角小方块芯片)
    rounded(buf, size, int(30*s), int(28*s), int(74*s), int(72*s), int(10*s), white)
    rounded(buf, size, int(42*s), int(40*s), int(62*s), int(60*s), int(4*s), bg)
    png_write(path, size, size, buf)

make(256, "ai-switch/ICON_256.PNG")
make(128, "ai-switch/ICON.PNG")
make(256, "ai-switch/app/ui/images/icon_256.png")
make(64, "ai-switch/app/ui/images/icon_64.png")
print("icons done")
