"""Generate the M9 RIFTHEART material, scoped models and procedural camo data.

Optional authoring step; normal builds consume checked-in outputs. Requires the
installed SDK/game, Python and Pillow. Does not edit the game's raw tree.
"""
import argparse
import json
from pathlib import Path
import random
import re
import struct
import zipfile
from PIL import Image, ImageDraw
from generate_progression import write_iwi

ROOT = Path(__file__).resolve().parents[1]
MATERIAL = "apx_m9_rift_chrome"
STOCK_MATERIAL = "mtl_weapon_beretta"
TECHSET = "l_sm_apxrift"
CAMO = "apx_m9_rift_fields"
STATES = {"unlit", "lit", "lit sun", "lit sun shadow", "lit spot",
          "lit spot shadow", "lit omni", "lit omni shadow"}


def fields(size=512):
    """Seeded, tileable RGBA: two turbulence bands, circuitry, cellular faults."""
    rng = random.Random(0xA9F2026)
    channels = []
    for channel in range(2):
        layers = []
        for cells in (4, 8, 16, 32, 64):
            grid = Image.new("L", (cells+1, cells+1))
            values = [[rng.randrange(256) for _ in range(cells)] for _ in range(cells)]
            grid.putdata([values[y % cells][x % cells] for y in range(cells+1) for x in range(cells+1)])
            expanded = grid.resize((size+size//cells, size+size//cells), Image.Resampling.BICUBIC)
            layers.append(expanded.crop((0, 0, size, size)))
        image = layers[0]
        for layer, weight in zip(layers[1:], (.38, .23, .14, .08)):
            image = Image.blend(image, layer, weight)
        channels.append(image)
    circuits = Image.new("L", (size, size))
    draw = ImageDraw.Draw(circuits)
    for y in range(0, size, 32):
        for x in range(0, size, 32):
            inset = rng.randrange(3, 9)
            level = rng.randrange(140, 256)
            draw.line([(x+inset, y+3), (x+inset, y+14),
                       (x+inset+9, y+23), (x+28, y+23)], fill=level, width=1)
            draw.ellipse((x+inset-2, y+1, x+inset+2, y+5), outline=level, width=1)
            if rng.random() < .55:
                draw.line((x+24, y+6, x+28, y+6), fill=255, width=2)
                draw.line((x+24, y+10, x+28, y+10), fill=180, width=1)
    cells = 10
    sites = {(x,y):(rng.random(),rng.random()) for y in range(cells) for x in range(cells)}
    faults = bytearray(size*size)
    for y in range(size):
        py=y*cells/size;iy=int(py)
        for x in range(size):
            px=x*cells/size;ix=int(px);nearest=second=100.0
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    sx,sy=sites[((ix+dx)%cells,(iy+dy)%cells)]
                    distance=(px-(ix+dx+sx))**2+(py-(iy+dy+sy))**2
                    if distance<nearest: second,nearest=nearest,distance
                    elif distance<second: second=distance
            edge=max(0.0,min(1.0,1.0-(second**.5-nearest**.5)/.065))
            faults[y*size+x]=round(edge*edge*(3-2*edge)*255)
    return Image.merge("RGBA", (*channels,circuits,Image.frombytes("L",(size,size),bytes(faults))))


def material_bytes(template):
    """Preserve the stock material's flags/constants; append relocated tables."""
    data=bytearray(template)
    if len(data)<140 or data[48]!=3 or data[50]!=2:
        raise ValueError("Unexpected stock M9 material layout")
    def string(value):
        offset=len(data);data.extend(value.encode("ascii")+b"\0");return offset
    struct.pack_into("<I",data,0,string(MATERIAL))
    struct.pack_into("<I",data,52,string(TECHSET))
    semantic=string("camoMap");texture=string(CAMO)
    old_table=struct.unpack_from("<I",data,56)[0]
    descriptors=bytes(data[old_table:old_table+36])
    sampler_flags=struct.unpack_from("<I",descriptors,4)[0]
    table=len(data);data.extend(descriptors)
    data.extend(struct.pack("<III",semantic,sampler_flags,texture))
    struct.pack_into("<I",data,56,table);data[48]=4
    return bytes(data)


def scoped_model(data):
    if len(MATERIAL)!=len(STOCK_MATERIAL):
        raise ValueError("Model material replacement must preserve binary length")
    old=STOCK_MATERIAL.encode()+b"\0"
    if old not in data: raise ValueError("M9 model does not reference expected material")
    return data.replace(old,MATERIAL.encode()+b"\0")


def weapon_bytes(data):
    source=data.decode("latin1")
    for field,old,new in (("gunModel","viewmodel_beretta_mp","apx_m9_rift_view"),
                          ("worldModel","weapon_beretta","apx_m9_rift_world")):
        before="\\"+field+"\\"+old+"\\"
        if before not in source: raise ValueError("Stock M9 "+field+" changed")
        source=source.replace(before,"\\"+field+"\\"+new+"\\",1)
    return source.encode("latin1")


def save_treatment(weapon, record):
    """Append a treatment without discarding the other weapons' registrations."""
    path=ROOT/"ui/weapon_shaders.json"
    registry=json.loads(path.read_text()) if path.exists() else {"version":1,"weapons":{}}
    registry["description"]="Per-base-weapon shader treatments."
    registry["weapons"][weapon]=record
    path.write_text(json.dumps(registry,indent=2)+"\n",encoding="utf8")
    manifest="// Scoped base-weapon shader materials and view/world models.\n"
    for entry in registry["weapons"].values():
        manifest+="material,"+entry["material"]+"\n"
        manifest+="xmodel,"+entry["view_model"]+"\n"
        manifest+="xmodel,"+entry["world_model"]+"\n"
    (ROOT/"manifests/18-weapon-shaders.csv").write_text(manifest,encoding="ascii",newline="\n")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-root",type=Path,default=ROOT.parent.parent)
    args=parser.parse_args();game=args.game_root.resolve();raw=game/"raw"
    art=ROOT/"art/weapons/beretta-rift";art.mkdir(parents=True,exist_ok=True)
    image=fields();image.save(art/"camo-fields.png")
    write_iwi(image,ROOT/"assets/images"/(CAMO+".iwi"),encoding="BGRA")
    (ROOT/"assets/materials"/MATERIAL).write_bytes(material_bytes((raw/"materials"/STOCK_MATERIAL).read_bytes()))
    (ROOT/"assets/material_properties"/MATERIAL).write_bytes((raw/"material_properties"/STOCK_MATERIAL).read_bytes())
    for original,target in (("viewmodel_beretta_mp","apx_m9_rift_view"),("weapon_beretta","apx_m9_rift_world")):
        (ROOT/"assets/xmodel"/target).write_bytes(scoped_model((raw/"xmodel"/original).read_bytes()))
    weapon=None
    for archive_path in sorted((game/"main").glob("*.iwd")):
        with zipfile.ZipFile(archive_path) as archive:
            if "weapons/mp/beretta_mp" in archive.namelist():
                weapon=archive.read("weapons/mp/beretta_mp")
    if weapon is None: raise FileNotFoundError("Installed stock beretta_mp weapon definition")
    (ROOT/"src/weapons/mp/beretta_mp").write_bytes(weapon_bytes(weapon))
    # Keep stock depth/shadow/debug and additive-light passes. Override full-color
    # lighting paths once, so dynamic lights do not redraw the emissive core.
    for model in ("","mc_"):
        for shadow in ("sm","hsm"):
            original=model+"l_"+shadow+"_r0c0s0"
            target=model+"l_"+shadow+"_apxrift"
            text=(raw/"techsets"/(original+".techset")).read_text()
            for state in STATES:
                pattern=r'("'+re.escape(state)+r'"\s*:\s*)[a-zA-Z0-9_]+\s*;'
                text=re.sub(pattern,lambda m:m[1]+"apx_m9_rift;",text)
            (ROOT/"assets/techsets"/(target+".techset")).write_text(text,encoding="ascii",newline="\n")
            fallback=ROOT/"assets/techsets/sm2"/(target+".techset")
            fallback.write_bytes((raw/"techsets/sm2"/(original+".techset")).read_bytes())
    save_treatment("beretta_mp", {"effect":"RIFTHEART","catalog_id":0,"material":MATERIAL,
              "techset":TECHSET,"view_model":"apx_m9_rift_view","world_model":"apx_m9_rift_world",
              "fields":CAMO,"sm2":"stock appearance","gameplay":"stock damage, animation, ammo and weapon identity"})
    print("Generated M9 RIFTHEART: one material, one 512-square data texture, two scoped models; stock gameplay retained.")


if __name__=="__main__":
    main()
