"""Nock 3.5.0: new map pin icons in the 3.3 badge style (SVG -> TGA).
Run from the repo root:  python3 art/pins_350.py"""
import asyncio, importlib.util, sys
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright
ROOT = Path(__file__).resolve().parents[1]
PNG = ROOT / "art" / "pins-3.5"; OUT = ROOT / "Nock" / "Media" / "Textures" / "pins"
src = (ROOT / "art" / "pins_330.py").read_text().split("async def main")[0]
ns = {"__file__": str(ROOT / "art" / "pins_330.py")}; exec(src, ns)
pin, CREAM, write_tga = ns["pin"], ns["CREAM"], ns["write_tga"]

BOWGUN = f'''<g transform="rotate(-35 32 32)">
<rect x="12" y="29" width="40" height="6" rx="2" fill="{CREAM}" stroke="#000" stroke-width="2"/>
<rect x="12" y="35" width="12" height="9" rx="2" fill="#b07a4a" stroke="#000" stroke-width="2"/>
<rect x="46" y="27" width="6" height="4" fill="{CREAM}" stroke="#000" stroke-width="1.5"/></g>
<g transform="rotate(35 32 32)"><path d="M24 12 Q44 32 24 52" fill="none" stroke="#000" stroke-width="6.5"/>
<path d="M24 12 Q44 32 24 52" fill="none" stroke="#d8b8f2" stroke-width="3.6"/>
<line x1="24" y1="12" x2="24" y2="52" stroke="#000" stroke-width="2.6"/><line x1="24" y1="12" x2="24" y2="52" stroke="{CREAM}" stroke-width="1.2"/></g>'''

QUIVER = f'''<g transform="rotate(18 32 32)">
<line x1="28" y1="22" x2="25" y2="10" stroke="#000" stroke-width="4"/><line x1="28" y1="22" x2="25" y2="10" stroke="{CREAM}" stroke-width="2"/>
<line x1="34" y1="22" x2="36" y2="9" stroke="#000" stroke-width="4"/><line x1="34" y1="22" x2="36" y2="9" stroke="{CREAM}" stroke-width="2"/>
<path d="M22 20 L42 20 L39 52 Q32 55 25 52 Z" fill="#8a5a30" stroke="#000" stroke-width="2.6" stroke-linejoin="round"/>
<rect x="21" y="18" width="22" height="5" rx="2" fill="#9fd6db" stroke="#000" stroke-width="1.8"/>
<rect x="24" y="43" width="16" height="4" rx="2" fill="#9fd6db" stroke="#000" stroke-width="1.6"/></g>'''

MEAT = f'''<g transform="rotate(-30 32 32)">
<path d="M18 30 C18 18 34 14 42 22 C50 30 44 44 32 44 C26 44 22 40 21 36 Z" fill="#e0805f" stroke="#000" stroke-width="2.4"/>
<path d="M24 28 C26 22 34 20 38 25" fill="none" stroke="#ffd0b8" stroke-width="2"/>
<rect x="38" y="38" width="12" height="5" rx="2" transform="rotate(40 44 40)" fill="{CREAM}" stroke="#000" stroke-width="1.8"/>
<circle cx="50" cy="47" r="3.6" fill="{CREAM}" stroke="#000" stroke-width="1.6"/><circle cx="47" cy="50" r="3.6" fill="{CREAM}" stroke="#000" stroke-width="1.6"/></g>'''

QUEST = f'''<path d="M27 14 L37 14 L35 38 L29 38 Z" fill="#f6d34a" stroke="#000" stroke-width="2.6" stroke-linejoin="round"/>
<circle cx="32" cy="47" r="4.8" fill="#f6d34a" stroke="#000" stroke-width="2.4"/>'''

FLIGHT = f'''<path d="M32 22 C26 14 14 14 10 20 C18 20 22 24 24 28 C18 28 14 32 14 36 C20 33 26 33 30 36 L32 46 L34 36 C38 33 44 33 50 36 C50 32 46 28 40 28 C42 24 46 20 54 20 C50 14 38 14 32 22 Z" fill="{CREAM}" stroke="#000" stroke-width="2" stroke-linejoin="round"/>'''

ART = {
    "pin_ranged": pin("#c79ef0", BOWGUN),
    "pin_quiver": pin("#8fd3da", QUIVER),
    "pin_petfood": pin("#ec8c6b", MEAT),
    "pin_quest": pin("#f6d34a", QUEST),
    "pin_flight": pin("#b3c7db", FLIGHT),
}
async def main():
    PNG.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path="/usr/bin/google-chrome")
        for name, svg in ART.items():
            pg = await b.new_page(viewport={"width": 64, "height": 64}, device_scale_factor=4)
            await pg.set_content(f'<html><body style="margin:0;background:transparent">{svg}</body></html>')
            tmp = PNG / f"{name}@4x.png"
            await pg.screenshot(path=str(tmp), omit_background=True, clip={"x": 0, "y": 0, "width": 64, "height": 64})
            im = Image.open(tmp).resize((64, 64), Image.LANCZOS); tmp.unlink()
            im.save(PNG / f"{name}.png"); write_tga(im, OUT / f"{name}.tga")
            await pg.close()
        await b.close()
asyncio.run(main())
