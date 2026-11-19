#!/usr/bin/env python3
"""Clean Ben's Gunsmith PNGs and pack them into power-of-two 32-bit TGAs.

Also derives the missing pieces (corners, rails, caps, wood, glow, ticks,
window plates) so the Gunsmith style does not fall back to Emerald art.
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw, ImageChops, ImageEnhance, ImageOps
import numpy as np

SRC = Path("/workspace/nock/gun-assets")
PNG = Path("/workspace/nock/art/png-gun")
PREV = Path("/workspace/nock/art/png-gun/previews")
TGA = Path("/workspace/nock/Nock/Media/Textures/gun")
EM = Path("/workspace/nock/Nock/Media/Textures")
MEDIA = Path("/workspace/nock/Nock/Media")
for p in (PNG, PREV, TGA):
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

def to_im(arr):
    return Image.fromarray(zero_rgb(arr.astype(np.uint8)), "RGBA")

def checker(size, cell=16):
    w, h = size
    a = np.zeros((h, w, 3), dtype=np.uint8)
    a[:, :] = (160, 162, 168)
    yy, xx = np.indices((h, w))
    a[((xx // cell) + (yy // cell)) % 2 == 0] = (100, 102, 108)
    return Image.fromarray(a, "RGB").convert("RGBA")

def save(img, name):
    im = to_im(np.array(img.convert("RGBA")))
    im.save(PNG / f"{name}.png")
    write_tga(im, TGA / f"{name}.tga")
    chk = checker(im.size)
    chk.alpha_composite(im)
    prev = chk
    if prev.size[0] > 1024 or prev.size[1] > 1024:
        r = min(1024 / prev.size[0], 1024 / prev.size[1])
        prev = prev.resize((max(1, int(prev.size[0] * r)), max(1, int(prev.size[1] * r))), Image.Resampling.LANCZOS)
    prev.save(PREV / f"{name}.png")
    print(f"saved {name:22s} {im.size[0]:4d}x{im.size[1]:<4d}")
    return im

def content_bbox(arr, a_min=16):
    a = arr[:, :, 3]
    ys, xs = np.where(a >= a_min)
    if len(xs) == 0:
        return (0, 0, arr.shape[1], arr.shape[0])
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1

def crop_content(im, pad=4, a_min=16):
    arr = np.array(im.convert("RGBA"))
    x0, y0, x1, y1 = content_bbox(arr, a_min)
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(arr.shape[1], x1 + pad); y1 = min(arr.shape[0], y1 + pad)
    return Image.fromarray(arr[y0:y1, x0:x1], "RGBA"), (x0, y0, x1, y1)

def place(im, pot_w, pot_h, x=None, y=None, scale=None):
    im = im.convert("RGBA")
    if scale and scale != 1:
        nw = max(1, int(round(im.size[0] * scale)))
        nh = max(1, int(round(im.size[1] * scale)))
        im = im.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (pot_w, pot_h), (0, 0, 0, 0))
    if x is None:
        x = (pot_w - im.size[0]) // 2
    if y is None:
        y = (pot_h - im.size[1]) // 2
    x = int(x); y = int(y)
    # clip if needed
    if im.size[0] > pot_w or im.size[1] > pot_h:
        scale2 = min(pot_w / im.size[0], pot_h / im.size[1])
        im = im.resize((max(1, int(im.size[0] * scale2)), max(1, int(im.size[1] * scale2))), Image.Resampling.LANCZOS)
        if x is None or x < 0:
            x = (pot_w - im.size[0]) // 2
        if y is None or y < 0:
            y = (pot_h - im.size[1]) // 2
    canvas.alpha_composite(im, dest=(max(0, x), max(0, y)))
    return canvas, im.size, (max(0, x), max(0, y))

def defringe(arr, grow=1):
    """Kill RGB on fully transparent pixels and fade fringe toward neighbors."""
    a = arr[:, :, 3].astype(np.int16)
    out = arr.copy()
    out[a == 0, :3] = 0
    # For very low-alpha edge pixels, pull RGB toward the nearest more-opaque neighbor
    # by a simple 3x3 average of higher-alpha pixels.
    h, w = a.shape
    if grow:
        kernel = np.array(Image.fromarray(a.astype(np.uint8), "L").filter(ImageFilter.MaxFilter(3)))
        fringe = (a > 0) & (a < 48) & (kernel > a)
        if fringe.any():
            # leave alpha, zero-ish rgb to avoid white halos
            out[fringe, :3] = (out[fringe, :3].astype(np.int16) * a[fringe, None] // 48).astype(np.uint8)
    return out

def matte_light_bg(arr, luma=210, sat=28, a_cut=200):
    """Knock out pale desaturated backgrounds (paper / residual white)."""
    out = arr.copy().astype(np.int16)
    r, g, b, a = out[:,:,0], out[:,:,1], out[:,:,2], out[:,:,3]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    pale = (mx >= luma) & ((mx - mn) <= sat)
    # only punch where it's mostly background, not a bright highlight on metal
    # highlights on brass have higher sat or sit next to dark wood
    out[pale & (a <= a_cut), 3] = 0
    # also knock near-white high-alpha leftover canvas
    white = (r >= 240) & (g >= 240) & (b >= 240)
    out[white, 3] = 0
    return defringe(np.clip(out, 0, 255).astype(np.uint8))

def remove_paper(arr):
    """Asset 3: a translucent off-white wash over the whole canvas."""
    # Known paper color ~ (247,247,247) at low-mid alpha.
    out = arr.copy().astype(np.float32)
    r, g, b, a = out[:,:,0], out[:,:,1], out[:,:,2], out[:,:,3]
    luma = 0.3*r + 0.59*g + 0.11*b
    sat = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)
    paper = (luma >= 200) & (sat <= 22)
    out[paper, 3] = 0
    # For mid-alpha pale pixels around the silhouette, un-matte against paper
    pale = (luma >= 180) & (sat <= 28) & (a < 180)
    out[pale, 3] = 0
    # Feather: lower alpha of remaining very light edge
    edge = (luma >= 190) & (sat <= 35) & (a > 0)
    out[edge, 3] = np.minimum(out[edge, 3], (out[edge, 3] * 0.15))
    out = np.clip(out, 0, 255).astype(np.uint8)
    return defringe(out)

def remove_checker(arr, cell_guess=(8, 10, 12, 16)):
    """Remove a baked Photoshop-style checker in the glow/smoke of the flare."""
    im = Image.fromarray(arr, "RGBA")
    # A strong blur of the image is the intended glow; the residual is the checker.
    blur = im.filter(ImageFilter.GaussianBlur(radius=5))
    ba = np.array(blur)
    a = arr.astype(np.int16)
    b = ba.astype(np.int16)
    resid = np.abs(a[:,:,:3] - b[:,:,:3]).mean(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)  # includes alpha; use rgb only
    sat = a[:,:,:3].max(axis=2) - a[:,:,:3].min(axis=2)
    # Core of the bullet/flare is high-sat orange — keep sharp.
    core = (sat > 80) & (a[:,:,0] > 140) & (a[:,:,3] > 180)
    # Checker/smoke is lower-frequency glow plus a grid residual.
    smoke = (a[:,:,3] > 8) & (~core) & (resid > 12)
    out = arr.copy()
    # In smoke, use the blurred RGB and a slightly softened alpha
    out[smoke, :3] = ba[smoke, :3]
    # Kill leftover hard grid at very low alpha
    out[arr[:,:,3] < 6] = 0
    # Second pass: pixels that still look like dark-green / light-tan checker cells
    r, g, bl, al = out[:,:,0], out[:,:,1], out[:,:,2], out[:,:,3]
    # typical checker leftovers: near-gray or olive squares
    grayish = (np.abs(r.astype(int)-g.astype(int)) < 25) & (np.abs(g.astype(int)-bl.astype(int)) < 30) & (al > 20) & (al < 200)
    # if they aren't strongly orange, fade them toward the blur
    orange = (r > g + 20) & (r > bl + 20)
    fix = grayish & (~orange) & (~core)
    out[fix, :3] = ba[fix, :3]
    out[fix, 3] = np.minimum(out[fix, 3], ba[fix, 3])
    return defringe(out)

def load(name):
    return Image.open(SRC / name).convert("RGBA")

# ---------------------------------------------------------------------------
print("== cleaning source assets")
pips = load("1-bullet-pips.png")
ring = to_im(defringe(np.array(load("2-ring-frame.png"))))
bar_filled = to_im(remove_paper(np.array(load("3-bar-frame-filled-silver.png"))))
flare_raw = load("4-bullet-flare.png")
flare = to_im(remove_checker(np.array(flare_raw)))
fire = to_im(defringe(np.array(load("5-fire-fill.png"))))
bar_empty = to_im(defringe(np.array(load("6-bar-frame-empty.png"))))
track = to_im(defringe(np.array(load("7-bar-track-dark.png"))))

# Save cleaned source crops for inspection
for name, im in [("clean_pips", pips), ("clean_ring", ring), ("clean_filled", bar_filled),
                 ("clean_flare", flare), ("clean_fire", fire), ("clean_empty", bar_empty),
                 ("clean_track", track)]:
    c, _ = crop_content(im, pad=8)
    c.save(PREV / f"{name}.png")
    print("preview", name, c.size)

# ---------------------------------------------------------------------------
# Helpers to cut pieces from the empty barrel frame
empty_arr = np.array(bar_empty)
ex0, ey0, ex1, ey1 = content_bbox(empty_arr, 20)
print("empty content", ex0, ey0, ex1, ey1, "size", ex1-ex0, ey1-ey0)
# barrel ends: left and right ~ 280px of the 2153-wide bar
end_w = 340
left_cap = Image.fromarray(empty_arr[ey0:ey1, ex0:ex0+end_w], "RGBA")
right_cap = Image.fromarray(empty_arr[ey0:ey1, ex1-end_w:ex1], "RGBA")
# mid trough (frame body without barrel ends) for wood / rails
mid = Image.fromarray(empty_arr[ey0:ey1, ex0+end_w:ex1-end_w], "RGBA")
# mountain crest at the center top of the empty bar
cx = (ex0 + ex1) // 2
crest = Image.fromarray(empty_arr[ey0:ey0+170, cx-160:cx+160], "RGBA")

# Wood sample: a stretch of the wooden barrel (between iron bands)
# From the empty bar, a horizontal strip of wood at mid-height, left of center
wood_y0 = ey0 + 80
wood_y1 = ey1 - 80
wood_x0 = ex0 + end_w + 40
wood_x1 = wood_x0 + 400
# clamp
wood_y0 = max(ey0, wood_y0); wood_y1 = min(ey1, wood_y1)
wood_sample = Image.fromarray(empty_arr[wood_y0:wood_y1, wood_x0:wood_x1], "RGBA")

# Silver fill from the cleaned filled bar, trough region.
filled_arr = np.array(bar_filled)
# trough is roughly the same y as the hole in #6. Measure opaque icy pixels.
fa = filled_arr
# icy: b >= r-5 and mid luma, high alpha, not brown (brown has r>b+20)
icy = (fa[:,:,3] > 180) & (fa[:,:,2] + 8 >= fa[:,:,0]) & (fa[:,:,2] > 120) & (fa[:,:,0] < 200)
ys, xs = np.where(icy)
if len(xs):
    print("silver trough", xs.min(), ys.min(), xs.max(), ys.max())
    silver = Image.fromarray(fa[ys.min():ys.max()+1, xs.min():xs.max()+1], "RGBA")
else:
    print("WARNING no silver trough detected, fallback crop")
    silver = Image.fromarray(fa[340:400, 320:1860], "RGBA")

# Fire fill crop
fire_c, fire_box = crop_content(fire, pad=2, a_min=20)
print("fire content", fire_c.size, fire_box)

# Track crop
track_c, track_box = crop_content(track, pad=2, a_min=20)
print("track content", track_c.size, track_box)

# Ring crop (keep inner hole transparent)
ring_c, ring_box = crop_content(ring, pad=4, a_min=16)
print("ring content", ring_c.size, ring_box)

# Flare crop
flare_c, flare_box = crop_content(flare, pad=6, a_min=10)
print("flare content", flare_c.size, flare_box)

# Pips: cut each, keep the most typical (index 0) and the slightly marked middle one
pips_arr = np.array(pips)
# segments from earlier analysis, with a little pad
pip_segs = [(223,243),(437,457),(649,669),(863,883),(1076,1095),
            (1289,1309),(1503,1523),(1714,1734),(1928,1948)]
pip_imgs = []
for x0,x1 in pip_segs:
    col = pips_arr[:, max(0,x0-6):x1+7]
    ys = np.where(col[:,:,3].max(axis=1) >= 16)[0]
    if len(ys)==0: continue
    y0, y1 = max(0, ys[0]-6), min(col.shape[0], ys[-1]+7)
    pip_imgs.append(Image.fromarray(col[y0:y1], "RGBA"))
print("cut pips", len(pip_imgs), "sizes", [p.size for p in pip_imgs[:3]])
pip0 = pip_imgs[0] if pip_imgs else pips

# ---------------------------------------------------------------------------
print("== packing game textures")

# xp_frame: empty barrel bar, 2048x256, similar content window to emerald
# Emerald frame content was ~2154x258 packed at scale 0.9508 into 2048x256.
frame_c, _ = crop_content(bar_empty, pad=6)
# scale to almost full 2048 width, vertically centered
scale = 2048 / frame_c.size[0]
# if height would exceed 256, limit
if frame_c.size[1] * scale > 248:
    scale = 248 / frame_c.size[1]
xp_frame, fr_sz, fr_pos = place(frame_c, 2048, 256, scale=scale)
save(xp_frame, "xp_frame")
# record UVs of the trough later from the packed image

# xp_bg: dark track, 2048x256, placed in the trough band (similar y to fill)
# We'll put the track in the vertical middle, full width.
# Track source is 2172 wide x ~114 tall.
tr_scale = 2048 / track_c.size[0]
xp_bg_canvas = Image.new("RGBA", (2048, 256), (0, 0, 0, 0))
tr_h = max(1, int(round(track_c.size[1] * tr_scale)))
tr_img = track_c.resize((2048, tr_h), Image.Resampling.LANCZOS)
# place to overlap the frame's trough: estimate after we know fr_pos
# Use a generous middle band, slightly below center like emerald (T=0.43)
tr_y = int(round(256 * 0.42))
# if the packed frame has a hole, align to it
fr_arr = np.array(xp_frame)
# find row with most transparent pixels in the middle x
mid_a = fr_arr[:, 400:1648, 3]
row_trans = (mid_a < 20).mean(axis=1)
# trough = band of high transparency between solid frame rails
# ignore fully empty top/bottom
useful = np.where(fr_arr[:,:,3].max(axis=1) > 40)[0]
if len(useful):
    # inside that, the most transparent rows
    band = row_trans.copy()
    band[:useful[0]] = 0; band[useful[-1]+1:] = 0
    # consecutive high-trans rows
    hi = np.where(band > 0.5)[0]
    if len(hi) >= 4:
        tr_y = hi[0] + ((hi[-1]-hi[0]+1) - tr_h) // 2
        print("track aligned to trough y", tr_y, "trough", hi[0], hi[-1])
xp_bg_canvas.alpha_composite(tr_img, dest=(0, max(0, tr_y)))
save(xp_bg_canvas, "xp_bg")

# xp_fill: fire, 2048x128 — put content in the top portion so a SetTexCoord
# of (0, uMax, 0, vMax) can crop tightly, matching how emerald was packed.
# We'll pack the fire strip to nearly full width and ~72-90px tall at the TOP
# (emerald used vMax=0.5625 = 72/128).
fi_c = fire_c
# fire is already a long thin strip ~2172x78
fi_w, fi_h = 2048, min(72, int(round(fi_c.size[1] * 2048 / fi_c.size[0])))
fi_img = fi_c.resize((fi_w, max(8, fi_h)), Image.Resampling.LANCZOS)
xp_fill = Image.new("RGBA", (2048, 128), (0, 0, 0, 0))
xp_fill.alpha_composite(fi_img, dest=(0, 0))
save(xp_fill, "xp_fill")
fill_u = 1.0
fill_v = fi_img.size[1] / 128.0
print("xp_fill UV", fill_u, fill_v)

# xp_rested: silver/ice fill, same packing
si_c, _ = crop_content(silver, pad=1)
# silver may already be a strip; scale to 2048 x ~72 at top
si_h = min(72, int(round(si_c.size[1] * 2048 / max(1, si_c.size[0]))))
si_img = si_c.resize((2048, max(8, si_h)), Image.Resampling.LANCZOS)
xp_rested = Image.new("RGBA", (2048, 128), (0, 0, 0, 0))
xp_rested.alpha_composite(si_img, dest=(0, 0))
save(xp_rested, "xp_rested")

# xp_spark: flare, 512x512, centered
sp, _, _ = place(flare_c, 512, 512)
save(sp, "xp_spark")

# xp_badge: ring, 1024x1024
bd, _, _ = place(ring_c, 1024, 1024)
save(bd, "xp_badge")

# xp_ticks: pips laid out along the trough like tick marks, 2048x256
ticks = Image.new("RGBA", (2048, 256), (0, 0, 0, 0))
# 9 pips evenly across the trough (emerald-like 0.07-0.93 window)
# use a slightly smaller pip
pip_r = pip0.resize((18, int(18 * pip0.size[1] / max(1, pip0.size[0]))), Image.Resampling.LANCZOS)
# place vertically on the track
tick_y = max(0, tr_y + tr_h // 2 - pip_r.size[1] // 2)
for i in range(9):
    tx = int(2048 * (0.08 + i * (0.84 / 8)) - pip_r.size[0] / 2)
    ticks.alpha_composite(pip_r, dest=(max(0, tx), tick_y))
save(ticks, "xp_ticks")

# bow / centerpiece: 2048x512, flare centered in the content band (y~118-500)
bow = Image.new("RGBA", (2048, 512), (0, 0, 0, 0))
# A subtle wide brass rail behind the flare, cropped from the empty bar's mid body
# Take a thin horizontal slice of the frame (the lower rail + hanging rings area)
rail_src = Image.fromarray(empty_arr[ey0:ey1, ex0:ex1], "RGBA")
# scale rail to 1800 x ~140, place in the lower-middle of the bow canvas (string area)
rail_w, rail_h = 1900, 150
rail = rail_src.resize((rail_w, rail_h), Image.Resampling.LANCZOS)
# Drop the center hole already in the art — good, the flare sits in/above it
rail_x, rail_y = (2048 - rail_w) // 2, 280
bow.alpha_composite(rail, dest=(rail_x, rail_y))
# Flare, fairly large, centered a bit above the rail (like the bow's central gem)
fl_target_h = 280
fl_scale = fl_target_h / flare_c.size[1]
fl_w = int(flare_c.size[0] * fl_scale)
fl_img = flare_c.resize((fl_w, fl_target_h), Image.Resampling.LANCZOS)
fl_x = (2048 - fl_w) // 2
fl_y = 130
bow.alpha_composite(fl_img, dest=(fl_x, fl_y))
save(bow, "bow")

# cap_fletch (left barrel) and cap_head (right barrel): 1024x512, vertically centered
# fletch is right-aligned in its texture (attaches to the plaque's left)
# head is left-aligned
def pack_cap(src, name, align):
    c, _ = crop_content(src, pad=4)
    # scale to height ~500, width fits 1020
    sc = min(500 / c.size[1], 1000 / c.size[0])
    canvas, sz, pos = place(c, 1024, 512, scale=sc, x=0 if align=="left" else None, y=None)
    if align == "right":
        canvas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
        im = c.resize((int(c.size[0]*sc), int(c.size[1]*sc)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(im, dest=(1024 - im.size[0] - 4, (512 - im.size[1]) // 2))
        pos = (1024 - im.size[0] - 4, (512 - im.size[1]) // 2)
        sz = im.size
    elif align == "left":
        canvas = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
        im = c.resize((int(c.size[0]*sc), int(c.size[1]*sc)), Image.Resampling.LANCZOS)
        canvas.alpha_composite(im, dest=(4, (512 - im.size[1]) // 2))
        pos = (4, (512 - im.size[1]) // 2)
        sz = im.size
    save(canvas, name)
    return canvas, sz, pos

pack_cap(left_cap, "cap_fletch", "right")
pack_cap(right_cap, "cap_head", "left")

# divider: a single pip, 256x32 (horizontal) — or a row of pips
div = Image.new("RGBA", (256, 32), (0, 0, 0, 0))
# one pip centered, scaled to ~28px tall
ph = 28
pw = int(pip0.size[0] * ph / pip0.size[1])
pip_div = pip0.resize((max(2, pw), ph), Image.Resampling.LANCZOS)
div.alpha_composite(pip_div, dest=((256 - pip_div.size[0]) // 2, (32 - ph) // 2))
save(div, "divider")

# divider_v used as key "divider_v" pointing at a vertical pip 16x64 in Media,
# but Theme also has divider_v = MEDIA divider.tga (16x64). We'll pack a 16x64
# vertical pip as well (Textures/gun/divider_v.tga) and a 64x256 edge-style one.
pip_v = pip0.rotate(90, expand=True, resample=Image.Resampling.LANCZOS)
dv, _, _ = place(pip_v, 16, 64)
# 16x64 is POT. Good.
save(Image.new("RGBA", (16, 64), (0,0,0,0)) if False else
     place(pip_v, 16, 64)[0], "divider_v")

# corner 128x128: L-shaped carved wood/iron from the ring's top-left quadrant
# Take the ring, keep the upper-left outer arc, mask into an L.
rc = np.array(ring_c)
rh, rw = rc.shape[:2]
# The ring is roughly circular; cut the top-left quadrant and fade the inner hole
# (already transparent). Scale the quadrant to 128.
q = ring_c.crop((0, 0, rw // 2, rh // 2))
# The quadrant has a curved L already (the ring). Rotate so the arms go right and down
# (top-left corner). The ring's top-left quadrant already points that way.
corner, _, _ = place(q, 128, 128)
save(corner, "corner")

# edge / ornament: a horizontal slice of the barrel (wood + brass + iron)
# Use a mid-body section of the empty bar, flattened to 256x64 / 512x64
body_strip = mid  # already a mid section
# Take a horizontal band of the mid section (the full height is the barrel)
bs, _ = crop_content(body_strip, pad=2)
# We want a tileable-ish rail: pick a 400px wide slice without the crest if possible
# mid includes the crest at its center. Take a side slice to the left of center.
bsa = np.array(bs)
# left third
slice_w = min(bsa.shape[1] // 3, 400)
rail_slice = Image.fromarray(bsa[:, :slice_w], "RGBA")
edge, _, _ = place(rail_slice, 256, 64, scale=min(256/rail_slice.size[0], 64/rail_slice.size[1]))
save(edge, "edge")
# vertical
save(edge.rotate(90, expand=True).resize((64, 256), Image.Resampling.LANCZOS), "edge_v")
# ornament with the mountain crest
cr, _ = crop_content(crest, pad=2)
orn, _, _ = place(cr, 256, 64)
save(orn, "edge_ornament")
ornw, _, _ = place(cr, 512, 64)
save(ornw, "edge_ornament512")

# barwood: tile the wood sample to 512x64
ws, _ = crop_content(wood_sample, pad=0)
# if the sample is mostly transparent in the hole, pick a denser row
wsa = np.array(ws)
# choose rows with high opacity
row_a = (wsa[:,:,3] > 80).mean(axis=1)
good = np.where(row_a > 0.7)[0]
if len(good) >= 8:
    ws = Image.fromarray(wsa[good[0]:good[-1]+1], "RGBA")
bw = ws.resize((512, 64), Image.Resampling.LANCZOS)
# if the source is narrower, tile
if ws.size[0] < 200:
    tiled = Image.new("RGBA", (512, 64), (0,0,0,0))
    piece = ws.resize((ws.size[0], 64), Image.Resampling.LANCZOS)
    x = 0
    while x < 512:
        tiled.paste(piece, (x, 0), piece)
        x += piece.size[0]
    bw = tiled
save(bw, "barwood")

# glow: soft fire-orange glow from the flare, 64x64
# Extract the bright point of the flare and blur
fl_a = np.array(flare_c)
# bright core
yy, xx = np.where(fl_a[:,:,3] > 200)
if len(xx):
    cx, cy = int(xx.mean()), int(yy.mean())
else:
    cx, cy = fl_a.shape[1]//2, fl_a.shape[0]//2
# crop a 200px window around the muzzle
g0 = max(0, cx-120); g1 = min(fl_a.shape[1], cx+120)
h0 = max(0, cy-120); h1 = min(fl_a.shape[0], cy+120)
core = Image.fromarray(fl_a[h0:h1, g0:g1], "RGBA")
glow = Image.new("RGBA", (64, 64), (0,0,0,0))
core_r = core.resize((64, 64), Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(2))
glow.alpha_composite(core_r)
save(glow, "glow")

# tile: a 64x64 dark wood/iron plate from the ring or bar wood
# Prefer a wood patch from the ring (curved, but we can take a flatter side)
ra = np.array(ring_c)
# right side wood of the ring, a 180x180 box in the mid-right
rw, rh = ra.shape[1], ra.shape[0]
tx0, ty0 = int(rw*0.72), int(rh*0.40)
tile_src = Image.fromarray(ra[ty0:ty0+160, tx0:tx0+160], "RGBA")
tile, _, _ = place(tile_src, 64, 64, scale=64/160)
# If too much transparency, just resize the crop
if np.array(tile)[:,:,3].mean() < 80:
    tile = tile_src.resize((64, 64), Image.Resampling.LANCZOS)
save(tile, "tile")

# bg 256x256 and title 512x128: dark wood plate with a brass edge
def wood_plate(w, h, with_crest=False):
    plate = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # tile barwood
    bw_img = bw if bw.size[0] else tile
    # actually use the 512x64 barwood tiled
    y = 0
    while y < h:
        x = 0
        row = bw.resize((bw.size[0], min(64, h-y)), Image.Resampling.LANCZOS) if False else bw
        # scale barwood height
        piece = bw.resize((w, 64), Image.Resampling.LANCZOS)
        plate.paste(piece, (0, y), piece)
        y += 60
    plate = ImageEnhance.Brightness(plate).enhance(0.75)
    # brass rim
    d = ImageDraw.Draw(plate)
    d.rectangle([0, 0, w-1, h-1], outline=(196, 150, 70, 255))
    d.rectangle([1, 1, w-2, h-2], outline=(80, 58, 28, 255))
    if with_crest:
        cr2, _ = crop_content(crest, pad=2)
        cr2 = cr2.resize((min(w-20, 220), min(h-10, 56)), Image.Resampling.LANCZOS)
        plate.alpha_composite(cr2, dest=((w-cr2.size[0])//2, 4))
    return plate
save(wood_plate(256, 256), "bg")
save(wood_plate(512, 128, with_crest=True), "title")

# badge / token 32x32: a tiny brass mountain or rivet from the crest
cr_s, _ = crop_content(crest, pad=2)
badge, _, _ = place(cr_s, 32, 32)
save(badge, "badge")
save(badge, "token")

# close 32x32: a brass-and-iron X on a rivet disc, derived from ring rivet colors
close = Image.new("RGBA", (32, 32), (0,0,0,0))
d = ImageDraw.Draw(close)
d.ellipse([1, 1, 30, 30], fill=(54, 40, 24, 255), outline=(196, 150, 70, 255))
d.ellipse([4, 4, 27, 27], fill=(80, 58, 32, 255), outline=(30, 22, 12, 255))
d.line([(9, 9), (22, 22)], fill=(230, 200, 120, 255), width=3)
d.line([(22, 9), (9, 22)], fill=(230, 200, 120, 255), width=3)
save(close, "close")
close_h = close.copy()
# hover: hotter
ch = ImageEnhance.Brightness(close_h).enhance(1.25)
save(ch, "close_hover")

# keybadge 64x32: small brass plate
kb = wood_plate(64, 32)
save(kb, "keybadge")

# paw: recolor the existing paw to warm iron/brass (keep silhouette, drop emerald)
paw_path = MEDIA / "paw.tga"
# read tga
def read_tga(path):
    data = Path(path).read_bytes()
    w = data[12] + data[13]*256
    h = data[14] + data[15]*256
    raw = data[18:18+w*h*4]
    im = Image.frombytes("RGBA", (w, h), raw, "raw", "BGRA")
    return im.transpose(Image.FLIP_TOP_BOTTOM)
if paw_path.exists():
    paw = read_tga(paw_path)
    pa = np.array(paw).astype(np.float32)
    # shift green toward warm brass
    r,g,b,a = pa[:,:,0], pa[:,:,1], pa[:,:,2], pa[:,:,3]
    lum = 0.3*r+0.59*g+0.11*b
    pa[:,:,0] = np.clip(lum * 1.15 + 20, 0, 255)
    pa[:,:,1] = np.clip(lum * 0.80 + 8, 0, 255)
    pa[:,:,2] = np.clip(lum * 0.40, 0, 255)
    pa[:,:,3] = a
    save(to_im(pa), "paw")
else:
    save(badge, "paw")

# reticle: crop the crosshair from the bottom of the ring
# The crosshair sits at the bottom center of the ring.
ra = np.array(ring)
# content of ring is roughly full image. The sight is at the bottom center.
# From the image, it's a circular sight with a glowing orange center.
# Search for a compact high-orange cluster in the lower third.
rimg = np.array(ring)
orange = (rimg[:,:,0] > 180) & (rimg[:,:,1] > 80) & (rimg[:,:,1] < 180) & (rimg[:,:,3] > 80)
# lower half
orange[:rimg.shape[0]//2] = False
ys, xs = np.where(orange)
if len(xs):
    cx, cy = int(np.median(xs)), int(np.median(ys))
    print("reticle center", cx, cy)
    box = 140
    ret = Image.fromarray(rimg[max(0,cy-box):cy+box, max(0,cx-box):cx+box], "RGBA")
    ret, _ = crop_content(ret, pad=4)
    reticle, _, _ = place(ret, 64, 64)
    save(reticle, "reticle")
else:
    save(glow, "reticle")

# crest: mountain crest 128x128
save(place(crest if crest.size[0] else cr_s, 128, 128)[0], "crest")

# moon: small brass disc 32x32 from a rivet/gem on the ring
# use the orange gem at the top of the ring
if len(xs):
    # top gem: orange in upper third
    orange2 = (rimg[:,:,0] > 180) & (rimg[:,:,1] > 80) & (rimg[:,:,3] > 80)
    orange2[rimg.shape[0]//3:] = False
    ys2, xs2 = np.where(orange2)
    if len(xs2):
        cx2, cy2 = int(np.median(xs2)), int(np.median(ys2))
        gem = Image.fromarray(rimg[cy2-40:cy2+40, cx2-40:cx2+40], "RGBA")
        save(place(gem, 32, 32)[0], "moon")
    else:
        save(badge, "moon")
else:
    save(badge, "moon")

# header 256x64: title-like plate
save(wood_plate(256, 64, with_crest=True), "header")

# mist / map 512x512: dark wood atmosphere, no emerald mist
mist = wood_plate(512, 512)
mist = ImageEnhance.Brightness(mist).enhance(0.55)
mist = mist.filter(ImageFilter.GaussianBlur(1.2))
save(mist, "mist")
# map: same plate with a faint crest
mp = wood_plate(512, 512, with_crest=True)
mp = ImageEnhance.Brightness(mp).enhance(0.7)
save(mp, "map")

# vine 64x64: a small brass flourish (a pip or a metal corner)
save(place(pip0, 64, 64)[0], "vine")

# bar.tga 512x128 fallback plate
save(wood_plate(512, 128), "bar")

# Write a small UV / placement sidecar the Lua style table can be synced from
# Measure packed xp_frame trough and fill UVs.
fr = np.array(Image.open(PNG / "xp_frame.png"))
fill = np.array(Image.open(PNG / "xp_fill.png"))
# fill content
_, _, fu1, fv1 = content_bbox(fill, 16)
# frame trough: high-transparency band
mid = fr[:, 300:1748, 3]
row_t = (mid < 24).mean(axis=1)
useful = np.where(fr[:,:,3].max(axis=1) > 40)[0]
if len(useful) and (row_t[useful[0]:useful[-1]+1] > 0.4).any():
    hi = np.where((row_t > 0.4) & (np.arange(256) >= useful[0]) & (np.arange(256) <= useful[-1]))[0]
    trough = (int(hi[0]), int(hi[-1])+1) if len(hi) else (110, 160)
else:
    trough = (110, 160)
# frame solid left/right (window)
col_a = fr[:,:,3].max(axis=0)
# first solid from left / last solid from right, then the inner hole
# window x: high trans in the middle rows of the trough
if trough[1] > trough[0]:
    band = fr[trough[0]:trough[1], :, 3]
    col_t = (band < 24).mean(axis=0)
    hole = np.where(col_t > 0.5)[0]
    win = (int(hole[0]), int(hole[-1])+1) if len(hole) else (140, 1900)
else:
    win = (140, 1900)

uv = {
    "xp_fill_u": fu1 / 2048.0,
    "xp_fill_v": fv1 / 128.0,
    "xp_win_l": win[0] / 2048.0,
    "xp_win_r": win[1] / 2048.0,
    "xp_win_t": trough[0] / 256.0,
    "xp_win_b": trough[1] / 256.0,
    "xp_fill_t": max(0, trough[0] - 8) / 256.0,
    "xp_fill_b": min(256, trough[1] + 8) / 256.0,
}
print("UV", uv)
Path("/workspace/nock/art/png-gun/uv.json").write_text(__import__("json").dumps(uv, indent=2))
print("== done")
