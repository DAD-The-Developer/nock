import asyncio, random, math
from playwright.async_api import async_playwright
from PIL import Image
# name: (w,h,svg-or-html body)
T={}
def svg(w,h,inner,defs=''):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{inner}</svg>'
# 1 bar plaque 512x128
T['bar']=(512,128,svg(512,128,'''
<rect x="0" y="6" width="512" height="116" fill="url(#wood)"/>
<rect x="0" y="6" width="512" height="116" fill="url(#grain)" opacity=".55"/>
<rect x="0" y="6" width="512" height="116" fill="url(#mist)"/>
<rect x="0" y="5" width="512" height="4" fill="#8fb9a5"/><rect x="0" y="9" width="512" height="1.5" fill="#06100b"/>
<rect x="0" y="13" width="512" height="1.5" fill="#3fe39a" opacity=".45"/>
<rect x="0" y="119" width="512" height="4" fill="#8fb9a5"/><rect x="0" y="117.5" width="512" height="1.5" fill="#06100b"/>
<rect x="0" y="113" width="512" height="1.5" fill="#3fe39a" opacity=".45"/>
<rect x="0" y="16" width="512" height="18" fill="#000" opacity=".0"/>''',
'''<linearGradient id="wood" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2e3f35"/><stop offset=".5" stop-color="#18261f"/><stop offset="1" stop-color="#0c1511"/></linearGradient>
<pattern id="grain" width="40" height="116" patternUnits="userSpaceOnUse"><path d="M3 0 C8 40 0 80 5 116 M14 0 C10 50 18 70 13 116 M27 0 C31 30 24 90 29 116" stroke="#9fe0c0" stroke-opacity=".10" stroke-width="1.4" fill="none"/></pattern>
<radialGradient id="mist" cx=".5" cy="0" r=".9"><stop offset="0" stop-color="#50ffaa" stop-opacity=".12"/><stop offset="1" stop-color="#50ffaa" stop-opacity="0"/></radialGradient>'''))
# 2 bow 512x64 (string at bottom)
def bow(W=512,H=64):
    m=W/2
    limb=f'''<path d="M12 56 C7 50 12 44 22 42 C55 38 {m*0.5} 18 {m-26} 12 L{m-26} 25 C{m*0.52} 30 60 45 30 51 C22 52 19 56 16 60 Z" fill="url(#bw)" stroke="#e2bd5c" stroke-width="2" stroke-linejoin="round"/>
<path d="M30 47 C62 40 {m*0.52} 22 {m-28} 17" fill="none" stroke="#3fe39a" stroke-width="1.8" opacity=".9"/>
<path d="M{m*0.33} 31 l7 -6 M{m*0.53} 21 l7 -5 M{m*0.73} 15 l7 -3" stroke="#f0cf70" stroke-width="2.2"/>
<path d="M15 59 C2 61 -1 49 6 44 C9 51 12 54 16 55 Z" fill="#2fa86e" stroke="#bfe3cf" stroke-width="1.3"/>
<path d="M20 42 C14 32 22 26 30 30" fill="none" stroke="#e2bd5c" stroke-width="2"/>
<path d="M30 30 C34 24 42 25 41 31 C38 34 33 33 30 30 Z" fill="#2fa86e" stroke="#bfe3cf" stroke-width="1"/>'''
    return svg(W,H,f'''<path d="M16 60 L{W-16} 60" stroke="#d7f5e6" stroke-width="1.6" opacity=".85"/>
<g style="filter:drop-shadow(0 2px 2px rgba(0,0,0,.85))">{limb}<g transform="translate({W} 0) scale(-1 1)">{limb}</g>
<path d="M{m-40} 16 C{m-52} 4 {m-40} 0 {m-30} 7 Z M{m+40} 16 C{m+52} 4 {m+40} 0 {m+30} 7 Z" fill="#2fa86e" stroke="#e2bd5c" stroke-width="1.3"/>
<rect x="{m-29}" y="5" width="58" height="19" rx="4" fill="#2a1d12" stroke="#e2bd5c" stroke-width="1.8"/>
<path d="M{m-22} 6 v17 M{m-15} 6 v17 M{m+15} 6 v17 M{m+22} 6 v17" stroke="#e2bd5c" stroke-width="1.3" opacity=".75"/>
<circle cx="{m}" cy="14.5" r="8.5" fill="url(#gem)" stroke="#f0cf70" stroke-width="1.8"/>
<circle cx="{m-2.5}" cy="11.5" r="2.4" fill="#fff" opacity=".8"/></g>''',
'''<linearGradient id="bw" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#55673f"/><stop offset=".5" stop-color="#2c3d22"/><stop offset="1" stop-color="#16200f"/></linearGradient>
<radialGradient id="gem" cx=".4" cy=".35"><stop offset="0" stop-color="#d8ffe9"/><stop offset=".35" stop-color="#3fe39a"/><stop offset="1" stop-color="#0b4a2c"/></radialGradient>''')
T['bow']=(512,64,bow())
T['cap_fletch']=(64,64,svg(64,64,'''<g transform="translate(0,0) scale(1.4545,1)" style="filter:drop-shadow(0 1px 1px #000)">
<rect x="4" y="29.5" width="42" height="5" fill="#1d2e27" stroke="#7fa898" stroke-width="1"/>
<path d="M42 30 C30 28 18 18 6 8 L14 22 C12 25 13 28 16 30 Z" fill="url(#fv)" stroke="#bfe3cf" stroke-width="1.2"/>
<path d="M42 34 C30 36 18 46 6 56 L14 42 C12 39 13 36 16 34 Z" fill="url(#fv)" stroke="#bfe3cf" stroke-width="1.2"/>
<path d="M14 22 L36 29 M14 42 L36 35" stroke="#dfffee" stroke-width=".8" opacity=".55"/>
<path d="M2 27 L7 32 L2 37" fill="none" stroke="#bfe3cf" stroke-width="1.6"/></g>''',
'<linearGradient id="fv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2fa86e"/><stop offset=".5" stop-color="#0f4a30"/><stop offset="1" stop-color="#2fa86e"/></linearGradient>'))
T['cap_head']=(64,64,svg(64,64,'''<g transform="scale(1.4545,1)" style="filter:drop-shadow(0 1px 1px #000)">
<rect x="-2" y="29.5" width="10" height="5" fill="#1d2e27" stroke="#7fa898"/>
<rect x="5" y="27" width="7" height="10" rx="1.5" fill="#2a4a3c" stroke="#bfe3cf"/>
<path d="M5 29 h7 M5 32 h7 M5 35 h7" stroke="#12201a" stroke-width=".8"/>
<path d="M11 14 L42 32 L11 50 L17 32 Z" fill="url(#st)" stroke="#bfe3cf" stroke-width="1.4" stroke-linejoin="round"/>
<path d="M17 32 L42 32" stroke="#fff" stroke-width=".7" opacity=".6"/></g>''',
'<linearGradient id="st" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e4eae6"/><stop offset=".48" stop-color="#83908a"/><stop offset=".52" stop-color="#4a5852"/><stop offset="1" stop-color="#a0aea8"/></linearGradient>'))
# tile border ring 64x64 (transparent center)
T['tile']=(64,64,svg(64,64,'''<rect x="1.5" y="1.5" width="61" height="61" rx="3" fill="none" stroke="#06100b" stroke-width="3"/>
<rect x="4" y="4" width="56" height="56" rx="2" fill="none" stroke="#7fa898" stroke-width="2.4"/>
<rect x="6.5" y="6.5" width="51" height="51" fill="none" stroke="#0b130f" stroke-width="1.6"/>
<path d="M5 5 H59" stroke="#d7f5e6" stroke-width="1" opacity=".7"/>'''))
T['keybadge']=(64,32,svg(64,32,'''<rect x="1.5" y="1.5" width="61" height="29" rx="5" fill="url(#kb)" stroke="#9cc9b2" stroke-width="2.2"/>
<rect x="4" y="4" width="56" height="2" rx="1" fill="#d7f5e6" opacity=".18"/>''',
'<linearGradient id="kb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1d2e27"/><stop offset="1" stop-color="#0b130f"/></linearGradient>'))
T['paw']=(32,32,svg(32,32,'''<circle cx="16" cy="16" r="14.5" fill="url(#pb)" stroke="#9cc9b2" stroke-width="2"/>
<g fill="#c9ffe1" transform="translate(6,6) scale(1)"><ellipse cx="10" cy="13.5" rx="4.6" ry="3.8"/><ellipse cx="4" cy="8.5" rx="2" ry="2.5"/><ellipse cx="8" cy="5" rx="2" ry="2.6"/><ellipse cx="12.4" cy="5" rx="2" ry="2.6"/><ellipse cx="16.2" cy="8.6" rx="2" ry="2.5"/></g>''',
'<radialGradient id="pb" cx=".4" cy=".35"><stop offset="0" stop-color="#2a4a3c"/><stop offset="1" stop-color="#0b130f"/></radialGradient>'))
# reticle white (tinted in game)
T['reticle']=(64,64,svg(64,64,'''<g fill="none" stroke="#fff" stroke-width="2.4">
<path d="M32 5 A27 27 0 0 1 55 18"/><path d="M59 32 A27 27 0 0 1 46 55"/><path d="M32 59 A27 27 0 0 1 9 46"/><path d="M5 32 A27 27 0 0 1 18 9"/></g>
<g stroke="#fff" stroke-width="3"><path d="M32 0 v10 M32 54 v10 M0 32 h10 M54 32 h10"/></g>'''))
# soft glow (white) for ADD blend
T['glow']=(64,64,svg(64,64,'''<rect x="8" y="8" width="48" height="48" rx="6" fill="none" stroke="#fff" stroke-width="10" style="filter:blur(4px)"/>
<rect x="10" y="10" width="44" height="44" rx="3" fill="none" stroke="#fff" stroke-width="2.5"/>'''))
T['token']=(32,32,svg(32,32,'''<circle cx="16" cy="16" r="14" fill="url(#tk)" stroke="#0b130f" stroke-width="2"/><circle cx="16" cy="16" r="15" fill="none" stroke="#6dffb6" stroke-width="1.4"/>''',
'<radialGradient id="tk" cx=".4" cy=".35"><stop offset="0" stop-color="#ffffff"/><stop offset="1" stop-color="#a9c3b6"/></radialGradient>'))
T['divider']=(16,64,svg(16,64,'''<path d="M8 6 V58" stroke="#7fa898" stroke-width="1.6"/><path d="M8 55 L3 47 M8 55 L13 47 M8 47 L3 39 M8 47 L13 39" stroke="#7fa898" stroke-width="1.5" fill="none"/><path d="M8 3 L12 11 L8 9.5 L4 11 Z" fill="#bfe3cf"/>'''))
random.seed(7)
cont=''
for k in range(8):
    cx,cy=random.uniform(60,450),random.uniform(60,450)
    for r in range(1,5):
        cont+=f'<ellipse cx="{cx:.0f}" cy="{cy:.0f}" rx="{r*random.uniform(22,36):.0f}" ry="{r*random.uniform(14,24):.0f}" transform="rotate({random.randint(-30,30)} {cx:.0f} {cy:.0f})"/>'
T['map']=(512,512,svg(512,512,f'''<g fill="none" stroke="#a8ffd2" stroke-width="1.6" opacity=".55">{cont}
<path d="M30 470 C150 330 230 490 360 320 S470 120 480 90" stroke-dasharray="10 8" stroke-width="2.4"/>
<path d="M470 80 l20 20 M490 80 l-20 20" stroke-width="3.5"/>
<g transform="translate(440,440)"><circle r="34"/><circle r="22"/><path d="M0 -46 L7 0 L0 46 L-7 0 Z M-46 0 L0 7 L46 0 L0 -7 Z" fill="#a8ffd2" fill-opacity=".35"/></g></g>'''))
T['mist']=(512,512,svg(512,512,'''<rect width="512" height="512" fill="url(#bg)"/><rect width="512" height="512" fill="url(#m1)"/><rect width="512" height="512" fill="url(#m2)"/><rect width="512" height="512" fill="url(#m3)"/>''',
'''<linearGradient id="bg" x1="0" y1="0" x2=".6" y2="1"><stop offset="0" stop-color="#1b4136"/><stop offset=".6" stop-color="#0f2a23"/><stop offset="1" stop-color="#0b1f1a"/></linearGradient>
<radialGradient id="m1" cx=".25" cy=".15" r=".6"><stop offset="0" stop-color="#8cffc8" stop-opacity=".22"/><stop offset="1" stop-color="#8cffc8" stop-opacity="0"/></radialGradient>
<radialGradient id="m2" cx=".85" cy=".85" r=".55"><stop offset="0" stop-color="#788cff" stop-opacity=".14"/><stop offset="1" stop-color="#788cff" stop-opacity="0"/></radialGradient>
<radialGradient id="m3" cx=".6" cy=".55" r=".7"><stop offset="0" stop-color="#c8ffe6" stop-opacity=".07"/><stop offset="1" stop-color="#c8ffe6" stop-opacity="0"/></radialGradient>'''))
T['vine']=(64,64,svg(64,64,'''<g transform="scale(2)"><path d="M3 30 V9 Q3 3 9 3 H30" fill="none" stroke="#bfe3cf" stroke-width="1.8"/>
<path d="M7 26 V12 Q7 7 12 7 H26" fill="none" stroke="#3f9a70" stroke-width="1"/>
<path d="M12 7 C16 10 15 15 11 15 C9 15 9 12 11 12" fill="none" stroke="#bfe3cf" stroke-width="1.1"/>
<path d="M18 3 C22 -1 28 1 29 5 C25 7 20 6 18 3 Z" fill="#2fa86e" stroke="#bfe3cf" stroke-width=".7"/>
<path d="M3 18 C-1 22 1 28 5 29 C7 25 6 20 3 18 Z" fill="#2fa86e" stroke="#bfe3cf" stroke-width=".7"/>
<circle cx="6" cy="6" r="2.2" fill="#6dffb6"/></g>'''))
T['crest']=(128,128,svg(128,128,'''<g transform="scale(2.0645)"><circle cx="31" cy="31" r="31" fill="url(#mg)"/><circle cx="31" cy="31" r="22" fill="none" stroke="#6dffb6" stroke-opacity=".3"/>
<path d="M38 12 A20 20 0 1 0 38 50 A16 16 0 1 1 38 12 Z" fill="#e6f4ee" stroke="#9cc9b2" stroke-width=".8"/>
<g fill="#c9ffe1"><circle cx="44" cy="22" r="1.4"/><circle cx="49" cy="31" r="1"/><circle cx="42" cy="39" r="1.2"/></g>
<path d="M31 52 C27 47 27 43 31 40 C35 43 35 47 31 52 Z" fill="#2fa86e" stroke="#bfe3cf" stroke-width=".7"/></g>''',
'<radialGradient id="mg" cx=".45" cy=".4"><stop offset="0" stop-color="#1f5a45"/><stop offset="1" stop-color="#06120d"/></radialGradient>'))
T['moon']=(32,32,svg(32,32,'''<g transform="scale(1.6)"><path d="M13 2 A8.5 8.5 0 1 0 13 18 A7 7 0 1 1 13 2 Z" fill="#e6f4ee"/><circle cx="15.5" cy="7" r="1" fill="#c9ffe1"/></g>'''))
T['header']=(256,64,svg(256,64,'''<rect width="256" height="64" fill="url(#h)"/><rect y="60" width="256" height="2.5" fill="#9cc9b2"/><rect y="62.5" width="256" height="1.5" fill="#2fa86e"/>''',
'<linearGradient id="h" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1f3a30"/><stop offset="1" stop-color="#0f1f19"/></linearGradient>'))

def write_tga(img, path):
    img=img.convert('RGBA'); w,h=img.size
    hdr=bytes([0,0,2,0,0,0,0,0,0,0,0,0,w&255,w>>8,h&255,h>>8,32,8])
    px=img.transpose(Image.FLIP_TOP_BOTTOM).tobytes('raw','BGRA')
    open(path,'wb').write(hdr+px)
async def main():
    async with async_playwright() as p:
        b=await p.chromium.launch(executable_path='/usr/bin/google-chrome')
        for name,(w,h,body) in T.items():
            pg=await b.new_page(viewport={'width':w,'height':h},device_scale_factor=2)
            await pg.set_content(f'<html><body style="margin:0;background:transparent">{body}</body></html>')
            await pg.screenshot(path=f'png/{name}.png',omit_background=True,clip={'x':0,'y':0,'width':w,'height':h})
            im=Image.open(f'png/{name}.png').resize((w,h),Image.LANCZOS)
            im.save(f'png/{name}.png'); write_tga(im,f'../Nock/Media/{name}.tga')
            await pg.close()
        await b.close()
import os; os.makedirs('png',exist_ok=True); os.makedirs('../Nock/Media',exist_ok=True)
asyncio.run(main())
