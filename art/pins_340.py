"""Nock 3.4.0: rare tameable beast pin (SVG -> TGA). Reuses the 3.3.0 badge.

Run from the repo root:  python3 art/pins_340.py
"""
import asyncio
from pathlib import Path
from PIL import Image
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]
src = (ROOT / "art" / "pins_330.py").read_text().split("async def main")[0]
ns = {"__file__": str(ROOT / "art" / "pins_330.py")}
exec(src, ns)
pin, PAW, CREAM, write_tga, PNG, OUT = ns["pin"], ns["PAW"], ns["CREAM"], ns["write_tga"], ns["PNG"], ns["OUT"]

STAR = '''<path d="M49 9 L51.6 15.6 L58.6 16 L53.2 20.4 L55 27.2 L49 23.4 L43 27.2 L44.8 20.4 L39.4 16 L46.4 15.6 Z"
 fill="#ffd34a" stroke="#000" stroke-width="1.8"/>'''
GLYPH = f'<g transform="translate(-2 3) scale(0.94)">{PAW}</g>' + STAR
ART = {"pin_tame": (64, pin("#f29e3f", GLYPH))}

async def main():
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
