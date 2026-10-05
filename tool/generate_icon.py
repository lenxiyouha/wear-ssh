#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
圆表SSH (Wear SSH) 应用图标生成器
设计语言:
  - 深空蓝→青黑 对角渐变背景 (OLED 友好)
  - 一圈细环象征圆形表盘
  - 中央青色终端提示符 ">_" (SSH/终端身份)
  - 环上一颗绿色节点 = 已连接状态指示灯
输出:
  assets/icon/icon_source.png       1024 源图 (整体图标, 用于 legacy/round 图标)
  assets/icon/icon_foreground.png   1024 自适应图标前景 (透明底, 内容收进安全区)
  assets/icon/icon_background.png   1024 自适应图标背景 (纯渐变)
  assets/icon/preview_96.png        96 小预览 (README 用)
  android/app/src/main/res/drawable-nodpi/wear_bnr.png  400x400 Wear 横幅
"""
import math
import os

from PIL import Image, ImageDraw

SS = 4096          # 超采样绘制尺寸
OUT = 1024         # 图标输出尺寸

# ---- 配色 ----
BG_TOP = (13, 32, 56)        # 深蓝
BG_BOTTOM = (4, 8, 16)       # 近黑
GLOW = (10, 60, 82)          # 中心辉光 (青色调)
RING = (34, 211, 238, 90)    # 表环 青色 35% alpha
RING_HI = (34, 211, 238, 235)  # 环上高亮段
CYAN = (34, 211, 238)        # 终端符
GREEN = (52, 211, 153)       # 连接节点
NODE_RING = (6, 12, 22)      # 节点周围挖空描边


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def make_background(size):
    """对角渐变 + 中心青色辉光 (小图生成再放大, 保证平滑)"""
    small = 512
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = lerp(BG_TOP, BG_BOTTOM, t)
    img = img.resize((size, size), Image.LANCZOS)

    # 径向辉光 mask
    r_small = 256
    mask = Image.new("L", (r_small, r_small))
    mpx = mask.load()
    c = (r_small - 1) / 2.0
    for y in range(r_small):
        for x in range(r_small):
            d = math.hypot(x - c, y - c) / c
            v = max(0.0, 1.0 - d)
            mpx[x, y] = int(255 * (v ** 2) * 0.75)
    mask = mask.resize((size, size), Image.LANCZOS)
    glow = Image.new("RGB", (size, size), GLOW)
    img = Image.composite(glow, img, mask)
    return img


def I(v):
    return int(round(v))


def draw_ring(d, cx, cy, r, w):
    """表环: 底圈 35% 青 + 右上 1/4 高亮段, 亮暗交界处留缺口"""
    box = [I(cx - r), I(cy - r), I(cx + r), I(cy + r)]
    d.ellipse(box, outline=RING, width=I(w))
    # 高亮弧: 从 -78° 到 8° (右上角), PIL arc 角度顺时针, 0°=3点钟
    d.arc(box, start=-78, end=8, fill=RING_HI, width=I(w))


def draw_glyph(d, cx, cy, s):
    """终端提示符 >_  (s = 图标 1024 坐标系下的整体缩放系数)"""
    # 归一化设计坐标 (基于 1024 画布, 中心 512,512)
    chevron = [(280, 320), (555, 512), (280, 704)]
    underscore = [(640, 704), (790, 704)]
    lw = int(round(100 * s))

    def T(p):
        return (I(cx + (p[0] - 512) * s), I(cy + (p[1] - 512) * s))

    pts = [T(p) for p in chevron]
    d.line(pts, fill=CYAN, width=lw, joint="curve")
    for p in pts:  # 圆角端点
        d.ellipse([p[0] - lw // 2, p[1] - lw // 2,
                   p[0] + lw // 2, p[1] + lw // 2], fill=CYAN)
    u0, u1 = T(underscore[0]), T(underscore[1])
    d.line([u0, u1], fill=CYAN, width=lw)
    for p in (u0, u1):
        d.ellipse([p[0] - lw // 2, p[1] - lw // 2,
                   p[0] + lw // 2, p[1] + lw // 2], fill=CYAN)


def draw_node(d, cx, cy, r_ring, size, gap_color):
    """环上的绿色连接节点 (带挖空圈, 避免和环糊在一起)"""
    ang = math.radians(-45)  # 右上 45°
    nx = cx + r_ring * math.cos(ang)
    ny = cy + r_ring * math.sin(ang)
    if gap_color is not None:
        gap = size * 1.45
        d.ellipse([I(nx - gap), I(ny - gap), I(nx + gap), I(ny + gap)],
                  fill=gap_color)
    d.ellipse([I(nx - size), I(ny - size), I(nx + size), I(ny + size)],
              fill=GREEN)


def render(with_bg, safe_zone=False):
    """safe_zone=True: 内容缩到自适应图标安全区(约 62%); 用于前景层"""
    size = SS
    if with_bg:
        img = make_background(size)
    else:
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        # 给环/字加上轻微底色垫层, 保证透明底上也能看清
    draw = ImageDraw.Draw(img, "RGBA")
    k = size / 1024.0
    cx = cy = size / 2.0
    if safe_zone:
        r_ring = 285 * k          # 1024 坐标系里环半径 285 -> 落在安全区内
        w = 20 * k
        s = 0.78
        node = 34 * k
    else:
        r_ring = 430 * k
        w = 26 * k
        s = 1.0
        node = 46 * k

    draw_ring(draw, cx, cy, r_ring, w)
    draw_glyph(draw, cx, cy, s)
    draw_node(draw, cx, cy, r_ring, node,
              NODE_RING if with_bg else None)
    return img


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    icon_dir = os.path.join(root, "assets", "icon")
    res_dir = os.path.join(root, "android", "app", "src", "main", "res",
                           "drawable-nodpi")
    os.makedirs(icon_dir, exist_ok=True)
    os.makedirs(res_dir, exist_ok=True)

    # 1) 完整源图标 (背景 + 内容)
    full = render(with_bg=True, safe_zone=False).resize((OUT, OUT), Image.LANCZOS)
    full.save(os.path.join(icon_dir, "icon_source.png"))

    # 2) 自适应图标前景 (透明底, 内容收进安全区)
    fg = render(with_bg=False, safe_zone=True).resize((OUT, OUT), Image.LANCZOS)
    fg.save(os.path.join(icon_dir, "icon_foreground.png"))

    # 3) 自适应图标背景 (纯渐变)
    bg = make_background(OUT)
    bg.save(os.path.join(icon_dir, "icon_background.png"))

    # 4) README 小预览
    full.resize((96, 96), Image.LANCZOS).save(
        os.path.join(icon_dir, "preview_96.png"))

    # 5) Wear OS 横幅 400x400
    full.resize((400, 400), Image.LANCZOS).save(
        os.path.join(res_dir, "wear_bnr.png"))

    print("图标已生成:")
    for p in [f"assets/icon/icon_source.png", f"assets/icon/icon_foreground.png",
              f"assets/icon/icon_background.png", f"assets/icon/preview_96.png",
              f"android/app/src/main/res/drawable-nodpi/wear_bnr.png"]:
        print("  -", p)


if __name__ == "__main__":
    main()
