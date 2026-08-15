#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 1024x1024 AppIcon(纯标准库, 无需 Pillow)。
输出: HelloApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import os, struct, zlib, math

S = 1024
cx = cy = S // 2

# 1) 竖向深蓝渐变背景
top = (30, 44, 84)
bot = (8, 12, 24)
rows = []
for y in range(S):
    t = y / (S - 1)
    r = int(top[0] + (bot[0] - top[0]) * t)
    g = int(top[1] + (bot[1] - top[1]) * t)
    b = int(top[2] + (bot[2] - top[2]) * t)
    rows.append(bytearray(bytes([r, g, b, 255]) * S))


def setpx(x, y, r, g, b, a=255):
    if 0 <= x < S and 0 <= y < S:
        i = x * 4
        rows[y][i] = r
        rows[y][i + 1] = g
        rows[y][i + 2] = b
        rows[y][i + 3] = a


def fill_rect(x0, y0, x1, y1, col):
    for y in range(max(0, y0), min(S, y1)):
        for x in range(max(0, x0), min(S, x1)):
            setpx(x, y, *col)


def fill_circle(cxp, cyp, rad, col):
    for y in range(max(0, cyp - rad), min(S, cyp + rad)):
        for x in range(max(0, cxp - rad), min(S, cxp + rad)):
            if (x - cxp) ** 2 + (y - cyp) ** 2 <= rad * rad:
                setpx(x, y, *col)


gold = (255, 213, 79)
silver = (236, 239, 241)
dark = (55, 71, 79)

# 2) 金色光环(外圈柔光)
for y in range(S):
    for x in range(S):
        d = math.hypot(x - cx, y - cy)
        if 300 <= d <= 312:
            setpx(x, y, *gold)
        elif 270 <= d <= 274:
            setpx(x, y, gold[0], gold[1], gold[2], 110)

# 3) 剑刃(银白, 含三角剑尖)
# 剑尖: 从 (cx, cy-330) 收窄到 (cx-26, cy-230) / (cx+26, cy-230)
for y in range(cy - 330, cy - 230):
    half = int((y - (cy - 330)) / 100 * 26)
    for x in range(cx - half, cx + half):
        setpx(x, y, *silver)
# 剑身
fill_rect(cx - 26, cy - 230, cx + 26, cy + 140, silver)
# 剑刃高光中线
fill_rect(cx - 3, cy - 320, cx + 3, cy + 135, (255, 255, 255))

# 4) 护手(金)
fill_rect(cx - 150, cy + 130, cx + 150, cy + 180, gold)
fill_rect(cx - 150, cy + 168, cx + 150, cy + 178, (180, 140, 30))

# 5) 剑柄(深皮革)
fill_rect(cx - 22, cy + 180, cx + 22, cy + 280, dark)

# 6) 剑首球(金)
fill_circle(cx, cy + 312, 42, gold)

# 7) 写 PNG
def write_png(path):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    comp = zlib.compress(bytes(raw), 9)

    def chunk(typ, data):
        return (struct.pack(">I", len(data)) + typ + data +
                struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff))

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", S, S, 8, 6, 0, 0, 0)  # 8bit RGBA
    png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


out_dir = "HelloApp/Assets.xcassets/AppIcon.appiconset"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "AppIcon-1024.png")
write_png(out_path)
print(f"[icon] saved {out_path}  size={S}x{S}")

# 同步生成 Contents.json (iOS 14+ 单尺寸 1024 图标)
contents = {
    "images": [
        {
            "filename": "AppIcon-1024.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024"
        }
    ],
    "info": {"author": "xcode", "version": 1}
}
import json
cj_path = os.path.join(out_dir, "Contents.json")
with open(cj_path, "w", encoding="utf-8") as f:
    json.dump(contents, f, indent=2, ensure_ascii=False)
print(f"[icon] saved {cj_path}")
