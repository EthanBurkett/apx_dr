"""Offline layout proof of native menu coordinates, not a CoD4 client renderer.

Uses the actual generated button/logo assets and native menu macro coordinates.
Dynamic data is a labeled sample profile. Engine ownerdraws require client QA.
"""
import ast
import csv
import json
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from gsc import mask

ROOT=Path(__file__).resolve().parents[1]
SCALE=2
STATS={252:54,2326:5,2301:594000,2303:731,2305:450,2400:1,2401:110,2402:0,2403:1,2404:0,2405:0,2406:0,988:0,981:3,980:4,982:0,979:0}
DVARS={'apx_menu_map':'mp_dr_lithium','apx_hud_mode':'PRACTICE','apx_hud_detail':'1 / 3 players ready','dr_admin_p_n':'hype','dr_admin_p_h':'100/100','dr_admin_p_t':'Jumpers','dr_admin_p_s':'Playing'}


def args(text):
    result=[]; start=0; depth=0; quoted=False; escape=False
    for i,char in enumerate(text):
        if escape: escape=False; continue
        if char=='\\' and quoted: escape=True; continue
        if char=='"': quoted=not quoted
        if quoted: continue
        if char=='(': depth+=1
        if char==')': depth-=1
        if char==',' and depth==0: result.append(text[start:i].strip()); start=i+1
    result.append(text[start:].strip())
    return result


def lookup(table,keycol,key,column):
    rows=csv.reader((ROOT/'src'/table).read_text().splitlines())
    return next((row[int(column)] for row in rows if row and row[int(keycol)]==str(key) and len(row)>int(column)),'')


def expression(source):
    source=re.sub(r'localVarInt\((\w+)\)',lambda m:str(0),source)
    source=source.replace('&&',' and ').replace('||',' or ')
    source=re.sub(r'!(?!=)',' not ',source).strip()
    tree=ast.parse(source,mode='eval')
    safe=(ast.Expression,ast.Constant,ast.BinOp,ast.UnaryOp,ast.BoolOp,ast.Compare,ast.Call,ast.Name,ast.Load,ast.Add,ast.Sub,ast.Mult,ast.Div,ast.And,ast.Or,ast.Not,ast.Eq,ast.NotEq,ast.Lt,ast.Gt,ast.LtE,ast.GtE)
    if any(not isinstance(node,safe) for node in ast.walk(tree)): raise ValueError(source)
    def dvar(name):
        if name.startswith('apx_item_') or name.startswith('apx_character_'): return 1
        return DVARS.get(name,0)
    env={'stat':lambda id:STATS.get(id,0),'dvarString':dvar,'dvarInt':dvar,'tableLookup':lookup,'min':min,'localVarInt':lambda key:0}
    # UI concatenates numeric terms with strings; substitute known scalar calls.
    source=re.sub(r'stat\((\d+)\)',lambda m:str(STATS.get(int(m[1]),0)),source)
    if '+' in source and '"' in source:
        parts=re.split(r'\s+\+\s+',source)
        try: return ''.join(str(eval(compile(ast.parse(part,mode='eval'),'<preview>','eval'),{'__builtins__':{}},env)) for part in parts)
        except Exception: pass
    return eval(compile(tree,'<preview>','eval'),{'__builtins__':{}},env)


def label(source):
    try: value=str(expression(source))
    except Exception: value='Sample profile'
    if value.startswith('@'): return value.split('_',1)[-1].replace('_',' ').title()
    return value


def source_menu(path,name):
    text=(ROOT/'src'/path).read_text()
    start=re.search(r'menuDef\s*\{\s*name\s+"'+re.escape(name)+r'"',text).start()
    masked=mask(text); opening=masked.index('{',start); depth=1; end=opening+1
    while depth:
        depth+=(masked[end]=='{')-(masked[end]=='}'); end+=1
    return text[opening+1:end-1]


def render(path,name):
    image=Image.new('RGBA',(640*SCALE,480*SCALE),'#10171d'); draw=ImageDraw.Draw(image)
    def draw_text(x,y,text,size,color='#dfe7e3'):
        font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',round(size*48*SCALE))
        draw.text((round(x*SCALE),round(y*SCALE)),text,font=font,fill=color,anchor='ls')
    source=source_menu(path,name)
    # Reduce native decorative items to proof macros while preserving draw order.
    def reduce_item(match):
        block=match[0]
        rect=re.search(r'rect ([0-9.]+) ([0-9.]+) ([0-9.]+) ([0-9.]+)',block)
        if not rect: return ''
        visible=re.search(r'visible when\((.*)\)',block)
        if visible:
            try:
                if not expression(visible[1]): return ''
            except Exception: return ''
        material=re.search(r'exp material\((.*)\)',block)
        coords=','.join(rect.groups())
        if material: return 'APX_PROOF_IMAGE('+coords+','+material[1]+')'
        content=re.search(r'(?:exp text\((.*)\)|^text (.*)$)',block,re.M)
        if content:
            size=re.search(r'textscale ([0-9.]+)',block)
            return 'APX_UI_TEXT("proof",'+','.join(rect.groups()[:3])+','+(content[1] or content[2])+','+(size[1] if size else '.25')+')'
        return ''
    source=re.sub(r'itemDef\s*\{[^{}]*\}',reduce_item,source)
    for line in source.splitlines():
        match=re.match(r'\s*(APX_UI_RECT|APX_UI_TEXT|APX_UI_BUTTON|APX_UI_LOCKED|APX_LOGO|APX_PROOF_IMAGE|APX_UI_BACKDROP)\((.*)\)\s*$',line)
        if not match: continue
        kind=match[1]; values=args(match[2])
        if kind=='APX_UI_BACKDROP':
            background=Image.open(ROOT/'art/ui/menus/background.png').convert('RGBA').resize(image.size,Image.Resampling.LANCZOS)
            image.alpha_composite(background)
        elif kind=='APX_UI_RECT':
            x,y,w,h=map(float,values[:4]); rgba=[float(v) for v in values[4].split()]
            color=tuple(round(v*255) for v in rgba)
            layer=Image.new('RGBA',image.size)
            ImageDraw.Draw(layer).rectangle((x*SCALE,y*SCALE,(x+w)*SCALE,(y+h)*SCALE),fill=color)
            image.alpha_composite(layer)
        elif kind=='APX_PROOF_IMAGE':
            x,y,w,h=map(float,values[:4]); material=label(values[4])
            candidate=ROOT/'art/ui/models'/(material+'.png')
            if not candidate.exists(): candidate=ROOT/'art/progression/prestige'/(material+'.png')
            if not candidate.exists(): candidate=ROOT/'art/progression/ranks'/(material+'.png')
            if candidate.exists():
                asset=Image.open(candidate).convert('RGBA').resize((round(w*SCALE),round(h*SCALE)),Image.Resampling.LANCZOS)
                image.alpha_composite(asset,(round(x*SCALE),round(y*SCALE)))
        elif kind=='APX_LOGO':
            x,y,w,h=map(float,values[:4]); logo=Image.open(ROOT/'art/brand/apx-logo.png').convert('RGBA')
            logo.thumbnail((round(w*SCALE),round(h*SCALE)),Image.Resampling.LANCZOS)
            image.alpha_composite(logo,(round(x*SCALE),round((y+h/2)*SCALE-logo.height/2)))
        elif kind=='APX_UI_TEXT':
            _,x,y,w,content,size=values
            draw_text(float(x),float(y)+15,label(content),float(size))
        else:
            _,x,y,w,content,*tail=values
            try: enabled=bool(expression(tail[-1]))
            except Exception: enabled=False
            if not enabled: continue
            x,y,w=map(float,(x,y,w)); state='disabled' if kind=='APX_UI_LOCKED' else 'idle'
            if values[0]=='"nav_dr_options"' and name=='dr_options': state='hover'
            asset=Image.open(ROOT/f'art/ui/buttons/apx_button_{state}.png').convert('RGBA').resize((round(w*SCALE),27*SCALE))
            image.alpha_composite(asset,(round(x*SCALE),round(y*SCALE)))
            draw_text(x+12,y+18,label(content),.23 if state=='disabled' else .26,'#8a999b' if state=='disabled' else '#e1e7df')
    return image.convert('RGB')


def main():
    samples=[('ui_mp/main.menu','main_text'),('ui_mp/scriptmenus/character_stuff.menu','character_stuff'),('ui_mp/scriptmenus/dr_options.menu','dr_options'),('ui_mp/scriptmenus/popup_leavegame.menu','popup_endgame')]
    output=ROOT/'art/ui/menus'; output.mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGB',(1280*2,960*2),'#10171d')
    for i,(path,name) in enumerate(samples):
        result=render(path,name); result.save(output/(name+'.png'))
        sheet.paste(result,((i%2)*1280,(i//2)*960))
    sheet.save(output/'layout-proof.png')
    print('Wrote art/ui/menus/layout-proof.png. Coordinate proof only; dynamic engine items require client QA.')


if __name__=='__main__': main()
