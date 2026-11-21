"""Nock 3.3.1: Emerald quiver counter art from Ben's painted quiver.

Source: art/quiver-3.3.1/source.png (already has a clean alpha channel; kept
out of the addon zip). Writes Nock/Media/Textures/pins/q_quiver.tga (256x256)
and prints where the arch gap is so the ammo count can sit there.

Run from the repo root:  python3 art/quiver_331.py
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "art" / "quiver-3.3.1" / "source.png"
OUT = ROOT / "Nock" / "Media" / "Textures" / "pins" / "q_quiver.tga"
PNG = ROOT / "art" / "quiver-3.3.1" / "q_quiver.png"
SIZE, MARGIN = 256, 4

def write_tga(img, path):
    img = img.convert("RGBA"); w, h = img.size
    hdr = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    px = img.transpose(Image.FLIP_TOP_BOTTOM).tobytes("raw", "BGRA")
    Path(path).write_bytes(hdr + px)

im = Image.open(SRC).convert("RGBA")
a = np.array(im)[..., 3]
ys, xs = np.where(a > 8)
im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
w, h = im.size
s = (SIZE - 2 * MARGIN) / max(w, h)
nw, nh = round(w * s), round(h * s)
small = im.resize((nw, nh), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=2))
canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ox, oy = (SIZE - nw) // 2, (SIZE - nh) // 2
canvas.alpha_composite(small, (ox, oy))
canvas.save(PNG)
write_tga(canvas, OUT)

# Arch gap: the widest transparent run between the legs in the bottom fifth.
al = np.array(canvas)[..., 3]
best = None
for y in range(int(SIZE * 0.80), int(SIZE * 0.95)):
    row = al[y]
    solid = np.where(row > 40)[0]
    if len(solid) < 2:
        continue
    gaps = np.diff(solid)
    i = int(gaps.argmax())
    if gaps[i] > 10:
        cx = (solid[i] + solid[i + 1]) / 2
        if best is None or gaps[i] > best[1]:
            best = (y, gaps[i], cx)
print("wrote", OUT, "art box", (ox, oy, nw, nh))
print("arch gap (y, width, centre x) in 256 px:", best)
