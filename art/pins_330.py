"""Nock 3.3.0: map pin icons and quiver widget art (SVG -> TGA).

Run from the repo root:  python3 art/pins_330.py
Writes PNG masters to art/pins-3.3/ and TGAs to Nock/Media/Textures/pins/.
"""
import asyncio
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]
PNG = ROOT / "art" / "pins-3.3"
OUT = ROOT / "Nock" / "Media" / "Textures" / "pins"

def write_tga(img, path):
    img = img.convert("RGBA"); w, h = img.size
    hdr = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 8])
    px = img.transpose(Image.FLIP_TOP_BOTTOM).tobytes("raw", "BGRA")
    Path(path).write_bytes(hdr + px)

CREAM = "#fff3d2"

def pin(rim, glyph, defs=""):
    # 64x64 badge: dark disc, coloured rim, cream glyph.
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
<defs><radialGradient id="d" cx=".42" cy=".36" r=".7"><stop offset="0" stop-color="#2a241a"/><stop offset="1" stop-color="#070605"/></radialGradient>{defs}</defs>
<circle cx="32" cy="33" r="29" fill="#000" opacity=".55"/>
<circle cx="32" cy="32" r="27" fill="url(#d)"/>
<circle cx="32" cy="32" r="27" fill="none" stroke="#000" stroke-width="5.5"/>
<circle cx="32" cy="32" r="27" fill="none" stroke="{rim}" stroke-width="3.6"/>
<circle cx="32" cy="32" r="23.6" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="1"/>
<g stroke-linecap="round" stroke-linejoin="round">{glyph}</g></svg>'''

TRAINER = f'''<g transform="rotate(-40 32 32)">
<path d="M22 13 Q44 32 22 51" fill="none" stroke="#000" stroke-width="7"/>
<path d="M22 13 Q44 32 22 51" fill="none" stroke="{CREAM}" stroke-width="4"/>
<line x1="22" y1="13" x2="22" y2="51" stroke="#000" stroke-width="3"/>
<line x1="22" y1="13" x2="22" y2="51" stroke="{CREAM}" stroke-width="1.4"/>
<line x1="13" y1="32" x2="46" y2="32" stroke="#000" stroke-width="5.5"/>
<line x1="13" y1="32" x2="46" y2="32" stroke="{CREAM}" stroke-width="2.8"/>
<path d="M53 32 L44 26.5 L44 37.5 Z" fill="{CREAM}" stroke="#000" stroke-width="1.6"/>
<path d="M11 32 L16 26 L20 26 L16 32 L20 38 L16 38 Z" fill="#e8c35a" stroke="#000" stroke-width="1.4"/>
</g>'''

PAW = f'''<g fill="{CREAM}" stroke="#000" stroke-width="2">
<path d="M32 30 C40 30 46 38 45 43 C44 48 38 47 32 47 C26 47 20 48 19 43 C18 38 24 30 32 30 Z"/>
<ellipse cx="20.5" cy="27" rx="4.6" ry="6" transform="rotate(-20 20.5 27)"/>
<ellipse cx="28" cy="20" rx="4.6" ry="6.2" transform="rotate(-6 28 20)"/>
<ellipse cx="36" cy="20" rx="4.6" ry="6.2" transform="rotate(6 36 20)"/>
<ellipse cx="43.5" cy="27" rx="4.6" ry="6" transform="rotate(20 43.5 27)"/>
</g>'''

SHOE = f'''<path d="M20 47 L20 31 A12 12 0 0 1 44 31 L44 47" fill="none" stroke="#000" stroke-width="11"/>
<path d="M20 47 L20 31 A12 12 0 0 1 44 31 L44 47" fill="none" stroke="{CREAM}" stroke-width="7.5"/>
<rect x="15.5" y="45" width="9" height="5" rx="1.5" fill="{CREAM}" stroke="#000" stroke-width="1.6"/>
<rect x="39.5" y="45" width="9" height="5" rx="1.5" fill="{CREAM}" stroke="#000" stroke-width="1.6"/>
<g fill="#3a2a18"><circle cx="20" cy="38" r="1.4"/><circle cx="20" cy="31" r="1.4"/><circle cx="24" cy="23.5" r="1.4"/><circle cx="44" cy="38" r="1.4"/><circle cx="44" cy="31" r="1.4"/><circle cx="40" cy="23.5" r="1.4"/><circle cx="32" cy="19.6" r="1.4"/></g>'''

def arrow(angle):
    return f'''<g transform="rotate({angle} 32 50)">
<line x1="32" y1="50" x2="32" y2="17" stroke="#000" stroke-width="4.6"/>
<line x1="32" y1="50" x2="32" y2="17" stroke="{CREAM}" stroke-width="2.2"/>
<path d="M32 9.5 L27.5 18 L36.5 18 Z" fill="#cfe3f5" stroke="#000" stroke-width="1.5"/>
<path d="M32 46 L28 50 L28 55 L32 51 L36 55 L36 50 Z" fill="#7fb6e6" stroke="#000" stroke-width="1.3"/>
</g>'''
AMMO = arrow(-17) + arrow(17) + arrow(0) + f'''<rect x="24" y="34" width="16" height="5" rx="2" fill="#c98b4a" stroke="#000" stroke-width="1.5"/>'''

# Quiver widget art, 128x128.
def disc():
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs>
<radialGradient id="g" cx=".45" cy=".38" r=".7"><stop offset="0" stop-color="#26221a"/><stop offset=".8" stop-color="#0b0a08"/><stop offset="1" stop-color="#040403"/></radialGradient></defs>
<circle cx="64" cy="64" r="58" fill="url(#g)"/>
<circle cx="64" cy="64" r="58" fill="none" stroke="#000" stroke-width="3"/></svg>'''

def ring():
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128">
<circle cx="64" cy="64" r="57" fill="none" stroke="#000" stroke-width="11" opacity=".85"/>
<circle cx="64" cy="64" r="57" fill="none" stroke="#fff" stroke-width="7"/>
<circle cx="64" cy="64" r="52.2" fill="none" stroke="#fff" stroke-opacity=".45" stroke-width="1.4"/></svg>'''

def glow():
    return '''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs>
<filter id="b" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="5"/></filter></defs>
<circle cx="64" cy="64" r="52" fill="none" stroke="#fff" stroke-width="12" filter="url(#b)"/></svg>'''

def quiver():
    # Emerald: leather quiver with silver bands, green fletching.
    fl = ""
    for x, a in ((50, -12), (64, 0), (78, 12)):
        fl += f'''<g transform="rotate({a} {x} 52)"><line x1="{x}" y1="52" x2="{x}" y2="18" stroke="#000" stroke-width="5"/><line x1="{x}" y1="52" x2="{x}" y2="18" stroke="#d9c9a0" stroke-width="2.6"/>
<path d="M{x} 30 L{x-7} 22 L{x-7} 12 L{x} 19 L{x+7} 12 L{x+7} 22 Z" fill="#40e39a" stroke="#06331f" stroke-width="1.6"/></g>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs>
<linearGradient id="l" x1="0" x2="1"><stop offset="0" stop-color="#3a2414"/><stop offset=".45" stop-color="#7a4d2a"/><stop offset="1" stop-color="#2e1c10"/></linearGradient>
<linearGradient id="s" x1="0" x2="1"><stop offset="0" stop-color="#7f9a8d"/><stop offset=".5" stop-color="#e4f4ec"/><stop offset="1" stop-color="#6c8579"/></linearGradient></defs>
{fl}
<path d="M42 46 L86 46 L80 112 Q64 118 48 112 Z" fill="url(#l)" stroke="#000" stroke-width="3" stroke-linejoin="round"/>
<path d="M50 56 L78 56" stroke="#b07a4a" stroke-width="1.5" stroke-dasharray="3 3"/>
<rect x="40" y="42" width="48" height="9" rx="3" fill="url(#s)" stroke="#000" stroke-width="2"/>
<rect x="45" y="94" width="38" height="7" rx="3" fill="url(#s)" stroke="#000" stroke-width="2"/>
<circle cx="64" cy="74" r="7" fill="#1a7a52" stroke="#e4f4ec" stroke-width="2.4"/>
<circle cx="62" cy="72" r="2" fill="#bfffe0"/></svg>'''

def pouch():
    # Gunsmith: brass-trimmed leather ammo pouch with bullets.
    bl = ""
    for x in (48, 58, 68, 78):
        bl += f'''<rect x="{x}" y="28" width="8" height="20" rx="1" fill="#c8892f" stroke="#000" stroke-width="1.8"/>
<path d="M{x} 29 Q{x+4} 14 {x+8} 29 Z" fill="#d9d4cc" stroke="#000" stroke-width="1.6"/><rect x="{x+1.5}" y="30" width="2" height="16" fill="#f3c36a" opacity=".8"/>'''
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><defs>
<linearGradient id="l" x1="0" x2="1"><stop offset="0" stop-color="#2e1c10"/><stop offset=".5" stop-color="#6b4223"/><stop offset="1" stop-color="#26170c"/></linearGradient>
<linearGradient id="b" x1="0" x2="1"><stop offset="0" stop-color="#8a6420"/><stop offset=".5" stop-color="#f2cf7a"/><stop offset="1" stop-color="#7a5418"/></linearGradient></defs>
{bl}
<path d="M34 46 Q64 38 94 46 L90 100 Q64 114 38 100 Z" fill="url(#l)" stroke="#000" stroke-width="3" stroke-linejoin="round"/>
<path d="M34 46 Q64 38 94 46 L92 66 Q64 76 36 66 Z" fill="#4a2d17" stroke="#000" stroke-width="2.4"/>
<path d="M36 66 Q64 76 92 66" fill="none" stroke="url(#b)" stroke-width="3"/>
<circle cx="64" cy="70" r="7.5" fill="url(#b)" stroke="#000" stroke-width="2"/>
<circle cx="64" cy="70" r="3" fill="#ff8a1e"/>
<path d="M44 98 Q64 108 84 98" fill="none" stroke="#f27a1a" stroke-width="2" opacity=".8"/></svg>'''

ART = {
    "pin_trainer": (64, pin("#e8c35a", TRAINER)),
    "pin_pet": (64, pin("#5fd38a", PAW)),
    "pin_stable": (64, pin("#d0904c", SHOE)),
    "pin_ammo": (64, pin("#7fb6e6", AMMO)),
    "q_disc": (128, disc()),
    "q_ring": (128, ring()),
    "q_glow": (128, glow()),
    # q_quiver.tga is Ben's painted quiver since 3.3.1 (art/quiver_331.py).
    "q_pouch": (128, pouch()),
}

async def main():
    PNG.mkdir(parents=True, exist_ok=True); OUT.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/usr/bin/google-chrome")
        for name, (s, svg) in ART.items():
            pg = await b.new_page(viewport={"width": s, "height": s}, device_scale_factor=4)
            await pg.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
            tmp = PNG / f"{name}@4x.png"
            await pg.screenshot(path=str(tmp), omit_background=True, clip={"x": 0, "y": 0, "width": s, "height": s})
            im = Image.open(tmp).resize((s, s), Image.LANCZOS)
            tmp.unlink()
            im.save(PNG / f"{name}.png"); write_tga(im, OUT / f"{name}.tga")
            await pg.close()
        await b.close()

asyncio.run(main())
