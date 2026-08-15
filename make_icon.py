#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 1024x1024 AppIcon(在 GitHub Actions macOS 环境运行, 需 Pillow)。
输出: HelloApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

S = 1024
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# 竖向深蓝渐变背景
top = (30, 44, 84)
bot = (8, 12, 24)
for y in range(S):
    t = y / (S - 1)
    r = int(top[0] + (bot[0] - top[0]) * t)
    g = int(top[1] + (bot[1] - top[1]) * t)
    b = int(top[2] + (bot[2] - top[2]) * t)
    d.line([(0, y), (S, y)], fill=(r, g, b, 255))

cx, cy = S // 2, S // 2

# 外圈金色光环
for i in range(40, 0, -2):
    alpha = int(60 * (1 - i / 40))
    d.ellipse([cx - 330 - i, cy - 330 - i, cx + 330 + i, cy + 330 + i],
              outline=(255, 213, 79, alpha), width=2)

# 金色圆环
d.ellipse([cx - 300, cy - 300, cx + 300, cy + 300], outline=(255, 213, 79, 255), width=16)
d.ellipse([cx - 272, cy - 272, cx + 272, cy + 272], outline=(255, 213, 79, 90), width=4)

# 剑(垂直,尖朝上)
# 剑刃(银白)
blade = [(cx - 26, cy - 230), (cx + 26, cy - 230), (cx + 26, cy + 140), (cx - 26, cy + 140)]
d.polygon(blade, fill=(236, 239, 241, 255))
# 剑尖
d.polygon([(cx - 26, cy - 230), (cx + 26, cy - 230), (cx, cy - 300)], fill=(236, 239, 241, 255))
# 剑刃中线(亮)
d.line([(cx, cy - 290), (cx, cy + 140)], fill=(255, 255, 255, 220), width=4)
# 护手(金)
d.rectangle([cx - 150, cy + 130, cx + 150, cy + 180], fill=(255, 213, 79, 255))
d.rectangle([cx - 150, cy + 168, cx + 150, cy + 180], fill=(180, 140, 30, 255))
# 剑柄(深皮革)
d.rectangle([cx - 22, cy + 180, cx + 22, cy + 280], fill=(55, 71, 79, 255))
# 剑首球(金)
d.ellipse([cx - 42, cy + 270, cx + 42, cy + 354], fill=(255, 213, 79, 255))

# 顶部文字 "幻域"
font = None
for fp in ["/System/Library/Fonts/PingFang.ttc",
           "/System/Library/Fonts/Hiragino Sans GB.ttc",
           "/Library/Fonts/Arial Unicode.ttf"]:
    if os.path.exists(fp):
        try:
            font = ImageFont.truetype(fp, 130)
            break
        except Exception:
            pass
if font is None:
    font = ImageFont.load_default()
try:
    d.text((cx, cy - 360), "幻域", fill=(255, 213, 79, 255), font=font, anchor="mm")
except Exception:
    d.text((cx - 130, cy - 430), "HY", fill=(255, 213, 79, 255), font=font)

out_dir = "HelloApp/Assets.xcassets/AppIcon.appiconset"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "AppIcon-1024.png")
img.save(out_path, "PNG")
print(f"[icon] saved {out_path}  size={img.size}")
