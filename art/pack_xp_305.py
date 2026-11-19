#!/usr/bin/env python3
"""Crop, clean, and pack Ben's 3.0.5 XP art into power-of-two 32-bit TGAs."""
from pathlib import Path
from PIL import Image
import numpy as np
import json

SRC = Path("/workspace/nock/art/xp-3.0.5")
PNG = Path("/workspace/nock/art/png-3.0.5")
TGA = Path("/workspace/nock/Nock/Media/Textures")
PREV = Path("/workspace/nock/art/png-3.0.5/previews")
for p in (PNG, TGA, PREV):
    p.mkdir(parents=True, exist_ok=True)

def write_tga(img, path):
    img = img.convert("RGBA")
    w, h = img.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, (path, w, h)
    hdr = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    px = img.transpose(Image.FLIP_TOP_BOTTOM).tobytes("raw", "BGRA")
    Path(path).write_bytes(hdr + px)

def zero_rgb(arr):
    arr = arr.copy()
    arr[arr[:, :, 3] == 0, :3] = 0
    return arr

def checker(size, cell=16):
    w, h = size
    a = np.zeros((h, w, 3), dtype=np.uint8)
    a[:, :] = (160, 162, 168)
    yy, xx = np.indices((h, w))
    a[((xx // cell) + (yy // cell)) % 2 == 0] = (100, 102, 108)
    return Image.fromarray(a, "RGB").convert("RGBA")

def save(img, name):
    arr = zero_rgb(np.array(img.convert("RGBA")))
    im = Image.fromarray(arr, "RGBA")
    im.save(PNG / f"{name}.png")
    write_tga(im, TGA / f"{name}.tga")
    chk = checker(im.size)
    chk.alpha_composite(im)
    # scale previews that are huge
    prev = chk
    if prev.size[0] > 1024:
        r = 1024 / prev.size[0]
        prev = prev.resize((1024, max(1, int(prev.size[1] * r))), Image.Resampling.LANCZOS)
    prev.save(PREV / f"{name}.png")
    print(f"saved {name:12s} {im.size[0]:4d}x{im.size[1]:<4d}")
    return im

def place(src_arr, pot_w, pot_h, scale=None, x=0, y=None):
    """Scale src uniformly if scale given, paste into a transparent POT canvas."""
    im = Image.fromarray(src_arr, "RGBA")
    if scale and scale != 1:
        nw = max(1, int(round(im.size[0] * scale)))
        nh = max(1, int(round(im.size[1] * scale)))
        im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (pot_w, pot_h), (0, 0, 0, 0))
    if y is None:
        y = (pot_h - im.size[1]) // 2
    canvas.alpha_composite(im, dest=(int(x), int(y)))
    return canvas, im.size, (int(x), int(y))

# ---------------------------------------------------------------------------
# Shared crop for frame, bg, ticks (same canvas originally 2172x724, pre-aligned)
# Frame content a>=16: (13,227)-(2159,477) = 2146x250. A little pad for glows.
SX0, SY0, SX1, SY1 = 9, 223, 2163, 481  # 2154 x 258
SRC_W, SRC_H = SX1 - SX0, SY1 - SY0
POT_W, POT_H = 2048, 256
SCALE = POT_W / SRC_W  # 0.9508
# window (transparent opening) in source pixels
WIN = dict(L=163, T=334, R=2009, B=389)
# fill's own y in source (slightly under the gold trim)
FILL_Y0, FILL_Y1 = 325, 397

def pack_shared(name, punch_window=False):
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    arr = np.array(im)
    if punch_window:
        # Only punch leftover *inside* the open window, never gold highlights.
        L, T, R, B = WIN["L"], WIN["T"], WIN["R"], WIN["B"]
        sub = arr[T:B, L:R]
        # near-white or any stray mid-alpha dust in the hole
        near = (sub[:, :, 0] >= 230) & (sub[:, :, 1] >= 230) & (sub[:, :, 2] >= 230)
        # also fully transparent already; punch near-white leftovers only
        sub[near, 3] = 0
        sub[near, :3] = 0
        arr[T:B, L:R] = sub
    crop = arr[SY0:SY1, SX0:SX1]
    canvas, sz, orig = place(crop, POT_W, POT_H, scale=SCALE)
    save(canvas, f"xp_{name}" if name != "bg" else "xp_bg")
    return canvas, sz, orig

frame_im, frame_sz, frame_xy = pack_shared("frame", punch_window=True)
bg_im, _, _ = pack_shared("bg", punch_window=False)
ticks_im, _, _ = pack_shared("ticks", punch_window=False)

# Packed layout numbers (pixel space of 2048x256)
fx, fy = frame_xy
fw, fh = frame_sz  # ~2048 x 245
def src_to_tex(x, y):
    return fx + (x - SX0) * SCALE, fy + (y - SY0) * SCALE

winL, winT = src_to_tex(WIN["L"], WIN["T"])
winR, winB = src_to_tex(WIN["R"], WIN["B"])
fillT, fillB = src_to_tex(0, FILL_Y0)[1], src_to_tex(0, FILL_Y1)[1]

layout = {
    "frame_tex": [POT_W, POT_H],
    "content_xy": [fx, fy],
    "content_wh": [fw, fh],
    "scale": SCALE,
    "src_crop": [SX0, SY0, SX1, SY1],
    "window_px": [winL, winT, winR, winB],
    "window_uv": [winL / POT_W, winT / POT_H, winR / POT_W, winB / POT_H],
    "window_frac": [winL / POT_W, winT / POT_H, winR / POT_W, winB / POT_H],
    "fill_y_px": [fillT, fillB],
    "fill_y_frac": [fillT / POT_H, fillB / POT_H],
}

print("frame content", fw, fh, "at", fx, fy)
print("window px", winL, winT, winR, winB, "size", winR - winL, winB - winT)
print("fill y px", fillT, fillB, "h", fillB - fillT)

# ---------------------------------------------------------------------------
# Fill and rested: crop to the window X, keep their own Y, pack 2048x128
# No horizontal resample so TexCoord crop stays 1:1 with the waves.
FILL_POT_W, FILL_POT_H = 2048, 128

def pack_strip(name, y0, y1):
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    arr = np.array(im)
    # do NOT key sparkles / highlights
    L, R = WIN["L"], WIN["R"]
    crop = arr[y0:y1, L:R]  # 1846 x ~72
    # pad 2px vertically if we have room in source, already using fill y
    canvas = Image.new("RGBA", (FILL_POT_W, FILL_POT_H), (0, 0, 0, 0))
    # paste at (0, 0) so U runs 0..w/2048
    canvas.paste(Image.fromarray(crop, "RGBA"), (0, 0))
    save(canvas, f"xp_{name}" if name != "fill" else "xp_fill")
    w, h = crop.shape[1], crop.shape[0]
    return dict(u1=w / FILL_POT_W, v1=h / FILL_POT_H, px=(w, h))

fill_meta = pack_strip("fill", FILL_Y0, FILL_Y1)
rest_meta = pack_strip("rested", 324, 398)
layout["fill_tex"] = [FILL_POT_W, FILL_POT_H]
layout["fill_uv"] = [0, 0, fill_meta["u1"], fill_meta["v1"]]
layout["fill_px"] = list(fill_meta["px"])
layout["rested_uv"] = [0, 0, rest_meta["u1"], rest_meta["v1"]]
layout["rested_px"] = list(rest_meta["px"])
print("fill pack", fill_meta, "rested", rest_meta)

# ---------------------------------------------------------------------------
# Spark
spark = Image.open(SRC / "spark.png").convert("RGBA")
sa = np.array(spark.split()[-1])
ys, xs = np.where(sa >= 4)
pad = 16
x0, y0 = max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad)
x1, y1 = min(spark.size[0], int(xs.max()) + 1 + pad), min(spark.size[1], int(ys.max()) + 1 + pad)
scrop = np.array(spark)[y0:y1, x0:x1]
# 512x256 fits 518x331? content ~486x299 + 32 = 518x331, too tall for 256, too wide maybe for 512.
# Use 512x512, no upscale.
cw, ch = scrop.shape[1], scrop.shape[0]
print("spark crop", cw, ch, "from", x0, y0, x1, y1)
sp_scale = min(1.0, 512 / cw, 512 / ch)
spark_im, sp_sz, sp_xy = place(scrop, 512, 512, scale=sp_scale)
save(spark_im, "xp_spark")
layout["spark_tex"] = [512, 512]
layout["spark_content_uv"] = [
    sp_xy[0] / 512, sp_xy[1] / 512,
    (sp_xy[0] + sp_sz[0]) / 512, (sp_xy[1] + sp_sz[1]) / 512,
]
# The hot tip is on the right; we'll use the full content box in game.

# ---------------------------------------------------------------------------
# Badge
badge = Image.open(SRC / "badge.png").convert("RGBA")
ba = np.array(badge.split()[-1])
ys, xs = np.where(ba >= 4)
pad = 8
x0, y0 = max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad)
x1, y1 = min(badge.size[0], int(xs.max()) + 1 + pad), min(badge.size[1], int(ys.max()) + 1 + pad)
bcrop = np.array(badge)[y0:y1, x0:x1]
print("badge crop", bcrop.shape[1], bcrop.shape[0], "from", x0, y0, x1, y1)
# Fit in 1024x1024, uniform, no upscale if already smaller... it's 1170x1154-ish, slight downscale.
b_scale = min(1024 / bcrop.shape[1], 1024 / bcrop.shape[0])
badge_im, b_sz, b_xy = place(bcrop, 1024, 1024, scale=b_scale)
save(badge_im, "xp_badge")
layout["badge_tex"] = [1024, 1024]
layout["badge_content_uv"] = [
    b_xy[0] / 1024, b_xy[1] / 1024,
    (b_xy[0] + b_sz[0]) / 1024, (b_xy[1] + b_sz[1]) / 1024,
]

# Fractions of the *displayed frame* (the whole 2048x256 tex, including letterbox)
layout["winL"] = winL / POT_W
layout["winR"] = winR / POT_W
layout["winT"] = winT / POT_H
layout["winB"] = winB / POT_H
layout["fillT"] = fillT / POT_H
layout["fillB"] = fillB / POT_H

# Lua snippet
lua = f'''-- 3.0.5 packed XP textures (2048x256 frame/bg/ticks, 2048x128 fill/rested).
-- Insets are fractions of the on-screen frame (the full 2048x256 texture).
local XP_WIN_L, XP_WIN_R = {layout["winL"]:.6f}, {layout["winR"]:.6f}
local XP_WIN_T, XP_WIN_B = {layout["winT"]:.6f}, {layout["winB"]:.6f}
local XP_FILL_T, XP_FILL_B = {layout["fillT"]:.6f}, {layout["fillB"]:.6f}
local XP_FILL_U, XP_FILL_V = {fill_meta["u1"]:.6f}, {fill_meta["v1"]:.6f}
local XP_REST_U, XP_REST_V = {rest_meta["u1"]:.6f}, {rest_meta["v1"]:.6f}
local XP_SPARK_U0, XP_SPARK_V0, XP_SPARK_U1, XP_SPARK_V1 = {layout["spark_content_uv"][0]:.6f}, {layout["spark_content_uv"][1]:.6f}, {layout["spark_content_uv"][2]:.6f}, {layout["spark_content_uv"][3]:.6f}
local XP_BADGE_U0, XP_BADGE_V0, XP_BADGE_U1, XP_BADGE_V1 = {layout["badge_content_uv"][0]:.6f}, {layout["badge_content_uv"][1]:.6f}, {layout["badge_content_uv"][2]:.6f}, {layout["badge_content_uv"][3]:.6f}
'''
(PNG / "layout.lua").write_text(lua)
(PNG / "layout.json").write_text(json.dumps(layout, indent=2))
print(lua)

# Composite preview at native packed scale, 45% fill / 65% rest
comp = checker((POT_W, POT_H), 32)
comp.alpha_composite(bg_im)
# rest and fill in window, cropped
frac_f, frac_r = 0.45, 0.65
wx0, wy0 = int(round(winL)), int(round(fillT))
ww, fhgt = int(round(winR - winL)), int(round(fillB - fillT))

def strip_piece(png_name, frac, uv):
    im = Image.open(PNG / f"{png_name}.png")
    u1, v1 = uv
    src_w, src_h = int(round(u1 * FILL_POT_W * frac)), int(round(v1 * FILL_POT_H))
    sl = im.crop((0, 0, max(1, src_w), max(1, src_h)))
    return sl.resize((max(1, int(round(ww * frac))), fhgt), Image.Resampling.LANCZOS)

comp.alpha_composite(strip_piece("xp_rested", frac_r, (rest_meta["u1"], rest_meta["v1"])), dest=(wx0, wy0))
comp.alpha_composite(strip_piece("xp_fill", frac_f, (fill_meta["u1"], fill_meta["v1"])), dest=(wx0, wy0))
comp.alpha_composite(ticks_im)
comp.alpha_composite(frame_im)
# spark at fill edge
spk = Image.open(PNG / "xp_spark.png")
u0,v0,u1,v1 = layout["spark_content_uv"]
spk_c = spk.crop((int(u0*512), int(v0*512), int(u1*512), int(v1*512)))
spk_h = int(fhgt * 2.2)
spk_w = int(spk_c.size[0] * spk_h / spk_c.size[1])
spk_c = spk_c.resize((spk_w, spk_h), Image.Resampling.LANCZOS)
sx = wx0 + int(round(ww * frac_f)) - spk_w // 5
sy = wy0 + fhgt // 2 - spk_h // 2
comp.alpha_composite(spk_c, dest=(sx, sy))
comp.save(PREV / "xp_composite.png")
# tighter mid
comp.crop((0, 0, POT_W, POT_H)).resize((1024, 128), Image.Resampling.LANCZOS).save(PREV / "xp_composite_wide.png")
# left + badge
badge_prev = Image.open(PNG / "xp_badge.png")
bu0,bv0,bu1,bv1 = layout["badge_content_uv"]
bd = badge_prev.crop((int(bu0*1024), int(bv0*1024), int(bu1*1024), int(bv1*1024)))
bd = bd.resize((320, 320), Image.Resampling.LANCZOS)
left = Image.new("RGBA", (900, 400), (0, 0, 0, 0))
ch = checker((900, 400), 20)
ch.alpha_composite(comp.crop((0, 0, 700, POT_H)).resize((700, int(700*POT_H/POT_W)), Image.Resampling.LANCZOS), dest=(200, 200-int(700*POT_H/POT_W)//2))
# badge
ch.alpha_composite(bd, dest=(20, 40))
ch.save(PREV / "xp_with_badge.png")
print("previews written")
