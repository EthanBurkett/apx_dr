"""Rebuild ApX's editable badges, lossless IWI textures, materials and rank tables.

Requires Pillow only. The stock 2D material supplies the engine binary layout;
all emblem geometry is authored here and also saved as editable SVG sources.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import csv
import io
import json
import math
import struct
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
MAX_PRESTIGE = json.loads((ROOT/'ui/content_profile.json').read_text())['prestiges']
PALETTES = ['#c0ad8a', '#c8d0d8', '#d6b45f', '#65c8c4', '#7ea6e1', '#bb91df', '#e37f68', '#e4c875', '#d1e8eb', '#f0db9a']
BADGE_SIZE = 512
DRAW_SCALE = 8  # 1024px artwork, downsampled once for clean 512px edges.


class Badge:
    def __init__(self):
        self.image = Image.new('RGBA', (128*DRAW_SCALE, 128*DRAW_SCALE))
        self.draw = ImageDraw.Draw(self.image)
        self.svg = []

    def polygon(self, points, fill, outline=None, width=1):
        self.draw.polygon([(x * DRAW_SCALE, y * DRAW_SCALE) for x, y in points], fill=fill)
        if outline:
            self.line(points + [points[0]], outline, width)
        coords = ' '.join(f'{x:.2f},{y:.2f}' for x, y in points)
        self.svg.append(f'<polygon points="{coords}" fill="{fill}" stroke="{outline or fill}" stroke-width="{width}"/>')

    def line(self, points, fill, width=1):
        self.draw.line([(x * DRAW_SCALE, y * DRAW_SCALE) for x, y in points], fill=fill, width=max(1, round(width * DRAW_SCALE)), joint='curve')
        coords = ' '.join(f'{x:.2f},{y:.2f}' for x, y in points)
        self.svg.append(f'<polyline points="{coords}" fill="none" stroke="{fill}" stroke-width="{width}"/>')

    def circle(self, x, y, radius, fill, outline=None, width=1):
        self.draw.ellipse(((x-radius)*DRAW_SCALE, (y-radius)*DRAW_SCALE, (x+radius)*DRAW_SCALE, (y+radius)*DRAW_SCALE), fill=fill, outline=outline, width=max(1, round(width*DRAW_SCALE)))
        self.svg.append(f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{fill}" stroke="{outline or fill}" stroke-width="{width}"/>')

    def text(self, label, x, y, size, fill):
        font_path = Path('C:/Windows/Fonts/bahnschrift.ttf')
        if not font_path.exists():
            font_path = Path('C:/Windows/Fonts/arialbd.ttf')
        font = ImageFont.truetype(str(font_path), size*DRAW_SCALE)
        self.draw.text((x*DRAW_SCALE, y*DRAW_SCALE), label, font=font, anchor='mm', fill=fill)
        self.svg.append(f'<text x="{x}" y="{y}" font-family="Bahnschrift,Arial,sans-serif" font-weight="bold" font-size="{size}" text-anchor="middle" dominant-baseline="central" fill="{fill}">{escape(label)}</text>')

    def star(self, x, y, r, fill, points=5):
        coords = []
        for i in range(points*2):
            a = -math.pi/2 + i*math.pi/points
            radius = r if i % 2 == 0 else r*.43
            coords.append((x+math.cos(a)*radius, y+math.sin(a)*radius))
        self.polygon(coords, fill)

    def save(self, name, family):
        art = ROOT / 'art' / 'progression' / family
        art.mkdir(parents=True, exist_ok=True)
        (art / f'{name}.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">'+''.join(self.svg)+'</svg>', encoding='utf-8')
        image = self.image.resize((BADGE_SIZE,BADGE_SIZE), Image.Resampling.LANCZOS)
        image.save(art / f'{name}.png')
        write_iwi(image, ROOT / 'assets/images' / f'{name}.iwi', encoding='BGRA')
        write_material(name,BADGE_SIZE,BADGE_SIZE)
        return image


def write_iwi(image, path, encoding='DXT5'):
    """CoD4 v6 UI texture, no picmip reduction, smallest mip stored first.

    Format 1 maps to D3DFMT_A8R8G8B8 (BGRA bytes); format 13 is DXT5.
    The native loader treats flag 1 as noPicmip while retaining the mip chain.
    See build/reference/r_image_load_obj.asm, Image_LoadFromFileWithReader.
    """
    if encoding not in ('DXT5','BGRA'):
        raise ValueError('Unsupported IWI encoding: '+encoding)
    mips = []
    width, height = image.size
    while True:
        mip = image.resize((width,height), Image.Resampling.LANCZOS)
        if encoding == 'BGRA':
            mips.append(mip.tobytes('raw','BGRA'))
        else:
            buffer = io.BytesIO()
            mip.save(buffer, format='DDS', pixel_format='DXT5')
            dds = buffer.getvalue()
            assert dds[84:88] == b'DXT5'
            mips.append(dds[128:])
        if width == height == 1:
            break
        width, height = max(1, width//2), max(1, height//2)
    sizes = [28 + sum(len(m) for m in mips[p:]) for p in range(4)]
    header = struct.pack('<3sBBB3H4I', b'IWi', 6, 1 if encoding == 'BGRA' else 13, 1, image.width, image.height, 1, *sizes)
    path.write_bytes(header + b''.join(reversed(mips)))


def write_material(name, width=128, height=128, techset='2d'):
    template = (ROOT / 'assets/materials/rank_0').read_bytes()
    header = bytearray(template[:76]+techset.encode()+b'\0')
    struct.pack_into('<I',header,0,len(header))
    struct.pack_into('<2H', header, 24, width, height)
    texture_offset = len(header) + len(name) + 1
    semantic_offset = texture_offset + len(name) + 1
    for offset in (4,72):
        struct.pack_into('<I', header, offset, texture_offset)
    struct.pack_into('<I', header, 64, semantic_offset)
    (ROOT / 'assets/materials' / name).write_bytes(header + name.encode()+b'\0'+name.encode()+b'\0colorMap\0')
    (ROOT / 'assets/material_properties' / name).write_bytes((ROOT / 'assets/material_properties/rank_0').read_bytes())


def rank_badge(level):
    badge = Badge()
    tier, step = divmod(level-1,10)
    accent = PALETTES[tier]
    shield = [(26,18),(64,6),(102,18),(98,77),(84,101),(64,118),(44,101),(30,77)]
    badge.polygon(shield, '#10171c', '#68737d', 2)
    badge.polygon([(32,23),(64,13),(96,23),(92,75),(80,95),(64,108),(48,95),(36,75)], '#29323a', accent, 1.5)
    badge.line([(36,25),(64,17),(92,25)], '#e3e7e5', 1)
    for i in range(tier+1):
        x = 64 + (i-tier/2)*9
        badge.circle(x,29,2.2,accent)
    # A ten-step chevron/bar vocabulary, supplemented by the exact level number.
    for i in range(step//3+1):
        y = 41+i*8
        badge.polygon([(43,y),(64,y+8),(85,y),(85,y+5),(64,y+13),(43,y+5)], accent)
    for i in range(step%3):
        badge.circle(59+i*10,78,2, '#e1e7e9')
    badge.polygon([(42,87),(86,87),(83,105),(64,115),(45,105)], '#111b23', '#52616b', 1)
    badge.text(str(level),64,98,20, '#edf0e9')
    return badge


def prestige_badge(prestige):
    badge = Badge()
    tier, variant = divmod(prestige-1,5)
    accent = PALETTES[tier]
    # Distinct five-stage silhouettes per tier: wings, rays, wreath and crown.
    for side in (-1,1):
        for i in range(3+variant):
            y = 33+i*9
            badge.polygon([(64+side*23,y+4),(64+side*(48-i*3),y-10),(64+side*(43-i*3),y+5),(64+side*24,y+14)], '#59646d', accent, 1)
    for i in range(8+tier):
        a = 2*math.pi*i/(8+tier)
        badge.line([(64+math.sin(a)*37,58+math.cos(a)*37),(64+math.sin(a)*(43+variant),58+math.cos(a)*(43+variant))], accent, 2)
    badge.circle(64,58,35,'#111a22',accent,2)
    badge.circle(64,58,30,'#2d363e','#8b949a',1)
    badge.polygon([(64,28),(85,44),(78,73),(64,84),(50,73),(43,44)], '#17222a',accent,2)
    # ApX's angular A mark, with increasingly ornate tier markers.
    badge.polygon([(49,68),(61,39),(67,39),(79,68),(71,68),(68,60),(59,60),(56,68)],accent)
    badge.polygon([(61,54),(64,45),(67,54)], '#17222a')
    if tier >= 3:
        badge.star(64,21,6,accent)
    if tier >= 6:
        badge.star(42,22,4,accent); badge.star(86,22,4,accent)
    for i in range(variant+1):
        badge.circle(64+(i-variant/2)*7,79,1.8,'#e6e9e0')
    badge.polygon([(37,91),(91,91),(87,113),(64,122),(41,113)], '#111a22',accent,1.5)
    badge.text(f'{prestige:02}',64,104,22,'#f0eee2')
    return badge


def tables():
    rows=[]
    for rank in range(70):
        minimum = 200*rank*(rank+1)
        amount = 400*(rank+1)
        label = f'APXRANK_LEVEL_{rank+1}'
        rows.append([rank,f'rank{rank}',minimum,amount,label,label,f'apx_rank_{rank+1:02}',minimum+amount,';',';',';',';',';',rank+1,rank+1,';',label])
    write_csv('rankTable.csv', rows+[['maxrank',69]])
    # Native clients expose one rank icon. Always retain the level badge there;
    # the custom panel/menu uses the separate prestige table for its second icon.
    write_csv('rankIconTable.csv', [[r]+[f'apx_rank_{r+1:02}']*(MAX_PRESTIGE+1) for r in range(70)]+[['maxrank',69],['maxprestige',MAX_PRESTIGE]])
    write_csv('apx_prestiges.csv', [[0,'white','No prestige']]+[[p,f'apx_prestige_{p:02}',f'Prestige {p}'] for p in range(1,MAX_PRESTIGE+1)]+[['maxprestige',MAX_PRESTIGE]])
    localized=['VERSION "1"','CONFIG ""','FILENOTES "ApX Deathrun levels 1-70"','']
    for level in range(1,71): localized += [f'REFERENCE LEVEL_{level}',f'LANG_ENGLISH "Level {level}"','']
    localized += ['ENDMARKER','']
    (ROOT/'src/english/localizedstrings/APXRANK.str').write_text('\n'.join(localized),encoding='utf-8')


def write_csv(name, rows):
    with (ROOT/'src/mp'/name).open('w',newline='',encoding='utf-8') as stream:
        csv.writer(stream,lineterminator='\n').writerows(rows)


def main():
    images=[]
    names=[]
    for family,count,builder,prefix in [('ranks',70,rank_badge,'apx_rank'),('prestiges',MAX_PRESTIGE,prestige_badge,'apx_prestige')]:
        for number in range(1,count+1):
            name=f'{prefix}_{number:02}'
            images.append((name,builder(number).save(name,family)))
            names.append(name)
    tables()
    (ROOT/'manifests/12-progression.csv').write_text('// Generated by tools/generate_progression.py\n'+'\n'.join('material,'+name for name in names)+'\n',encoding='utf-8')
    sheet=Image.new('RGB',(1000,math.ceil(len(images)/10)*115),'#151e26')
    draw=ImageDraw.Draw(sheet)
    for i,(name,im) in enumerate(images):
        x,y=(i%10)*100,(i//10)*115
        sheet.paste(im.resize((92,92)),(x+4,y),im.resize((92,92)))
        draw.text((x+10,y+94),name.replace('apx_',''),fill='#d9e0e4')
    sheet.save(ROOT/'art/progression/contact-sheet.png')
    print(f'Generated 70 rank badges, {MAX_PRESTIGE} prestige emblems, IWI/material assets and progression tables.')


if __name__ == '__main__':
    main()
