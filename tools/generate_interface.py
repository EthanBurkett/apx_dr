"""Author ApX's image button family; Python + Pillow, no SDK conversion needed.

One geometry generates editable SVG, PNG and mipmapped DXT5 engine textures.
Labels remain live menu text so localization and dynamic labels still work.
"""
from pathlib import Path
from xml.sax.saxutils import escape
from PIL import Image, ImageDraw, ImageFont

from generate_progression import write_iwi, write_material

ROOT = Path(__file__).resolve().parents[1]
STATES = {
    'idle': ('#141e25', '#202e37', '#67727a', '#bcaa7c'),
    'hover': ('#26343b', '#35444a', '#d8c28c', '#f7db95'),
    'pressed': ('#101a20', '#1b2a30', '#9c8a60', '#dbbc74'),
    'disabled': ('#12191e', '#1b2329', '#39454d', '#57616a'),
}


def button(state):
    low, high, edge, accent = STATES[state]
    image = Image.new('RGBA', (1024, 128))
    draw = ImageDraw.Draw(image)
    svg = []

    def polygon(points, fill, stroke=None, width=1):
        scaled = [(x*2, y*2) for x,y in points]
        draw.polygon(scaled, fill=fill)
        if stroke:
            draw.line(scaled+[scaled[0]], fill=stroke, width=round(width*2), joint='curve')
        svg.append(f'<polygon points="{" ".join(f"{x},{y}" for x,y in points)}" fill="{fill}" stroke="{stroke or fill}" stroke-width="{width}"/>')

    def line(points, color, width=1):
        draw.line([(x*2,y*2) for x,y in points], fill=color, width=round(width*2))
        svg.append(f'<polyline points="{" ".join(f"{x},{y}" for x,y in points)}" fill="none" stroke="{color}" stroke-width="{width}"/>')

    # All decoration stays on the perimeter. The complete label area is clear
    # in every state, including inherited SDK controls with different baselines.
    polygon([(2,9),(9,2),(503,2),(510,9),(510,55),(503,62),(9,62),(2,55)], low, edge, 1)
    polygon([(4,10),(10,4),(502,4),(508,10),(508,59),(4,59)], high)
    if state == 'hover':
        line([(10,3),(502,3),(509,10)], accent, 1)
        line([(3,10),(3,54),(10,61),(502,61)], accent, 1)
    if state == 'pressed':
        line([(10,3),(502,3)], '#080f13', 2)
        line([(10,61),(502,61)], accent, 1)
    return image.resize((512,64), Image.Resampling.LANCZOS), '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 64">'+''.join(svg)+'</svg>'


def main():
    art = ROOT/'art/ui/buttons'
    art.mkdir(parents=True, exist_ok=True)
    preview = Image.new('RGB', (1000,540), '#10171d')
    draw = ImageDraw.Draw(preview)
    font_path = 'C:/Windows/Fonts/bahnschrift.ttf'
    font = ImageFont.truetype(font_path,22)
    small = ImageFont.truetype(font_path,16)
    draw.text((40,25), 'ApX Deathrun / image button states', fill='#e8e9e5', font=font)
    manifest = ['// ApX interface materials; images ship inside apx_dr.iwd.']
    for i,state in enumerate(STATES):
        name = 'apx_button_'+state
        image, svg = button(state)
        image.save(art/f'{name}.png')
        (art/f'{name}.svg').write_text(svg, encoding='utf-8')
        write_iwi(image, ROOT/'assets/images'/f'{name}.iwi')
        write_material(name,512,64)
        manifest.append('material,'+name)
        y=92+i*100
        preview.paste(image,(40,y),image)
        label = 'ENTER PRESTIGE' if state != 'disabled' else 'REQUIRES LEVEL 70'
        draw.text((91,y+32), label, font=font, anchor='lm', fill='#ede7d7' if state!='disabled' else '#79858b')
        draw.text((605,y+25), {'idle':'Idle','hover':'Mouse hover / keyboard focus','pressed':'Activated','disabled':'Locked / unavailable'}[state],font=small,fill='#c1c7c8')
    preview.save(art/'preview.png')
    write_iwi(Image.new('RGBA',(64,16),(255,255,255,255)),ROOT/'assets/images/apx_xp_fill.iwi')
    write_material('apx_xp_fill',64,16,techset='apx_xp_fill')
    manifest.append('material,apx_xp_fill')
    write_iwi(Image.new('RGBA',(64,16),(255,255,255,255)),ROOT/'assets/images/apx_health_fill.iwi')
    write_material('apx_health_fill',64,16,techset='apx_health_fill')
    manifest.append('material,apx_health_fill')
    # Preserve original artwork; letterbox to a power-of-two engine texture.
    logo = Image.open(ROOT/'art/brand/apx-logo.png').convert('RGBA')
    logo.thumbnail((512,256),Image.Resampling.LANCZOS)
    texture = Image.new('RGBA',(512,256))
    texture.alpha_composite(logo,((512-logo.width)//2,(256-logo.height)//2))
    write_iwi(texture,ROOT/'assets/images/apx_logo.iwi',encoding='BGRA')
    write_material('apx_logo',512,256)
    manifest.append('material,apx_logo')
    background=Image.open(ROOT/'art/ui/menus/background.png').convert('RGBA').resize((2048,1024),Image.Resampling.LANCZOS)
    write_iwi(background,ROOT/'assets/images/apx_menu_background.iwi')
    write_material('apx_menu_background',2048,1024)
    manifest.append('material,apx_menu_background')
    (ROOT/'manifests/13-interface.csv').write_text('\n'.join(manifest)+'\n',encoding='ascii')
    print('Generated four 512x64 ApX button states, editable artwork, engine assets and preview.')


if __name__ == '__main__':
    main()
