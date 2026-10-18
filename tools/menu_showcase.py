"""Dedicated native model-showcase layouts. All coordinates use 640x480."""


def model(u,x,y,w,h,material,condition='1',cell=None):
    condition=condition.replace('localVarInt(apx_rotate)==0','(localVarInt(apx_rotate)==0 || dvarString("r_rendererInUse")=="Shader model 2.0")').replace('localVarInt(apx_rotate)==1','(localVarInt(apx_rotate)==1 && dvarString("r_rendererInUse")!="Shader model 2.0")')
    result=[]
    # CoD4 expressions expose alpha but not RGB. Eight mutually exclusive
    # quads provide constant red cell codes while preserving normal UI alpha.
    for index in range(8) if cell is not None else [None]:
        color='1 1 1 1' if index is None else f'{(index+.5)/8} 1 1 1'
        shown=condition if index is None else f'({condition}) && (({cell})=={index})'
        result.append(f'''itemDef
{{
rect {x} {y} {w} {h} 0 0
style WINDOW_STYLE_SHADER
exp material({material})
forecolor {color}
visible when({shown})
decoration
}}
''')
    return ''.join(result)


def chrome(u,title,back='character_stuff'):
    return ('APX_UI_RECT(0,0,640,480,0.025 0.035 0.043 0.98)\n'
            'APX_LOGO(24,12,92,46,0 0,1,1)\n'+
            u.text('section',140,20,350,'APX / ARMORY',.17)+u.text('title',140,40,350,title,.4)+
            u.button('back',526,26,90,'Back',f'close self; open {back};')+
            'APX_UI_RECT(24,73,592,1,0.35 0.4 0.42 0.5)\n')


def loadout(u):
    body=chrome(u,'Your loadout','team_select')
    body+='APX_UI_RECT(24,88,252,320,0.055 0.073 0.083 1)\n'
    body+=model(u,74,85,160,320,'tableLookup("mp/apx_character_previews.csv",0,stat(980),1)','localVarInt(apx_view)==0','int(tableLookup("mp/apx_character_previews.csv",0,stat(980),6))')
    body+=model(u,74,85,160,320,'tableLookup("mp/apx_character_previews.csv",0,stat(980),2)','localVarInt(apx_view)==1','int(tableLookup("mp/apx_character_previews.csv",0,stat(980),7))')
    body+=u.text('operator',40,97,220,'OPERATOR',.18)
    body+=u.text('operator_name',40,373,220,'tableLookup("mp/characterTable.csv",1,stat(980),6)',.29,True)
    body+=u.button('front',24,416,78,'Front','setLocalVarInt apx_view 0;')
    body+=u.button('back_view',108,416,78,'Back','setLocalVarInt apx_view 1;')
    body+=u.button('character',192,416,84,'Change','close self; open dr_characters;')
    body+='APX_UI_RECT(292,88,324,156,0.045 0.061 0.071 1)\n'
    body+=u.text('primary',308,96,190,'PRIMARY',.18)
    body+=u.button('edit_primary',518,99,82,'Change','close self; open dr_weapons;')
    body+=model(u,304,125,206,103,'tableLookup("mp/apx_weapon_previews.csv",0,stat(981),1)',cell='int(tableLookup("mp/apx_weapon_previews.csv",0,stat(981),2))')
    body+=u.text('weapon_name',308,216,290,'tableLookup("mp/itemTable.csv",1,stat(981),5)',.27,True)
    body+=u.button('abilities',292,260,156,'Abilities','close self; open dr_abilities;')
    body+=u.button('sprays',460,260,156,'Sprays','close self; open dr_sprays;')
    body+='APX_UI_RECT(292,320,156,88,0.045 0.061 0.071 1)\nAPX_UI_RECT(460,320,156,88,0.045 0.061 0.071 1)\n'
    body+=u.text('knife',304,323,130,'KNIFE',.18)+model(u,306,345,128,64,'tableLookup("mp/apx_knife_previews.csv",0,stat(2405),1)',cell='int(tableLookup("mp/apx_knife_previews.csv",0,stat(2405),2))')
    body+=u.text('gloves',472,323,130,'GLOVES / ARMS',.18)
    body+=model(u,474,345,128,64,'tableLookup("mp/apx_character_previews.csv",0,stat(980),3)','stat(2406)==0',cell='int(tableLookup("mp/apx_character_previews.csv",0,stat(980),8))')
    body+=model(u,474,345,128,64,'tableLookup("mp/apx_glove_previews.csv",0,stat(2406),1)','stat(2406)>0',cell='int(tableLookup("mp/apx_glove_previews.csv",0,stat(2406),2))')
    body+=u.button('knife_info',292,416,156,'Change knife','scriptMenuResponse "nav:apx_knife";')
    body+=u.button('gloves_info',460,416,156,'Change arms','scriptMenuResponse "nav:apx_gloves";')
    body+=u.text('rules',292,451,324,'Primary + knife. Changes apply next spawn.',.19)
    u.save('ui_mp/scriptmenus/character_stuff.menu',u.menu('character_stuff','',body,shell_on=False,onopen='setLocalVarInt apx_view 0;'))


def catalog(u,name,title,rows,category,stat,iconcol,namecol,desccol,unlock):
    body=chrome(u,title)
    body+=u.text('search_hint',24,82,216,'FIND BY NAME',.17)
    body+='APX_UI_RECT(24,105,158,27,0.075 0.097 0.11 1)\n'
    body+=f'''itemDef
{{
name "search"
rect 24 105 158 27 0 0
type ITEM_TYPE_EDITFIELD
// The native caption painter falls back to the dvar when text is absent.
text " "
dvar "apx_catalog_search"
maxChars 32
maxPaintChars 20
textfont UI_FONT_NORMAL
textscale 0.25
textaligny 18
forecolor 0.9 0.92 0.9 1
visible 1
}}
'''
    body+=u.button('search_go',188,105,70,'Search',f'scriptMenuResponse "browse:{category}:search";')
    body+=u.button('all',24,137,110,'All items',f'scriptMenuResponse "browse:{category}:all";')
    body+=u.button('owned',142,137,116,'Unlocked',f'scriptMenuResponse "browse:{category}:owned";')
    body+='itemDef { rect 36 162 86 1 0 0 style WINDOW_STYLE_SHADER background "white" forecolor 0.8 0.69 0.45 1 visible when(!dvarInt("apx_browse_owned")) decoration }\n'
    body+='itemDef { rect 154 162 92 1 0 0 style WINDOW_STYLE_SHADER background "white" forecolor 0.8 0.69 0.45 1 visible when(dvarInt("apx_browse_owned")) decoration }\n'
    for slot in range(8):
        y=176+slot*29
        body+=u.button('result_'+str(slot),24,y,234,f'dvarString("apx_browse_name_{slot}")',f'scriptMenuResponse "browse:{category}:select:{slot}";',f'dvarInt("apx_browse_show_{slot}")',True)
        body+=f'itemDef {{ rect 36 {y+25} 210 1 0 0 style WINDOW_STYLE_SHADER background "white" forecolor 0.8 0.69 0.45 1 visible when(dvarInt("apx_browse_selected_{slot}")) decoration }}\n'
    body+=u.text('pages',24,411,234,'dvarInt("apx_browse_count") + " ITEMS / PAGE " + dvarInt("apx_browse_page") + " OF " + dvarInt("apx_browse_pages")',.18,True)
    body+=u.button('previous_page',24,440,54,'Prev',f'scriptMenuResponse "browse:{category}:page:-1";')
    body+=u.button('next_page',84,440,54,'Next',f'scriptMenuResponse "browse:{category}:page:1";')
    body+='APX_UI_RECT(150,440,42,27,0.075 0.097 0.11 1)\n'
    body+='''itemDef
{
name "page_number"
rect 150 440 42 27 0 0
type ITEM_TYPE_EDITFIELD
text " "
dvar "apx_catalog_page"
maxChars 3
maxPaintChars 3
textfont UI_FONT_NORMAL
textscale 0.25
textaligny 18
forecolor 0.9 0.92 0.9 1
visible 1
}
'''
    body+=u.button('jump',202,440,56,'Go',f'scriptMenuResponse "browse:{category}:jump:0";')
    body+='APX_UI_RECT(276,88,340,320,0.05 0.067 0.077 1)\n'
    body+=u.text('selected',292,100,308,'dvarString("apx_browse_name")',.3,True)
    body+=u.text('requirement',292,122,308,'dvarString("apx_browse_requirement")',.18,True)
    x,y,w,h=(382,146,118,236) if category=='character' else ((282,158,328,164) if category in ('weapon','knife','gloves') else (378,163,128,128))
    body+=model(u,x,y,w,h,'dvarString("apx_browse_preview")','dvarInt("apx_browse_exists") && localVarInt(apx_rotate)==0',cell='dvarInt("apx_browse_cell")' if category in ('weapon','character','knife','gloves') else None)
    body+=model(u,x,y,w,h,'dvarString("apx_browse_turn")','dvarInt("apx_browse_exists") && localVarInt(apx_rotate)==1')
    if category!='character': body+=u.text('detail',292,347,308,'dvarString("apx_browse_description")',.21,True)
    body+=u.button('previous_item',276,416,76,'Previous',f'scriptMenuResponse "browse:{category}:step:-1";')
    body+=u.button('next_item',358,416,68,'Next',f'scriptMenuResponse "browse:{category}:step:1";')
    body+=u.button('equip',434,416,182,'Equip primary' if category=='weapon' else 'Equip selection',f'scriptMenuResponse "browse:{category}:equip";','dvarInt("apx_browse_exists") && dvarInt("apx_browse_unlocked") && !dvarInt("apx_browse_equipped")')
    body+=u.locked('equipped',434,416,182,'Equipped','dvarInt("apx_browse_equipped")')
    body+=u.locked('locked',434,416,182,'Locked / inspect only','dvarInt("apx_browse_exists") && !dvarInt("apx_browse_unlocked")')
    if category in ('weapon','character','knife','gloves'):
        body+=u.button('rotate',276,450,116,'Rotate view','setLocalVarInt apx_rotate 1;')
        body+=u.button('still',400,450,116,'Still view','setLocalVarInt apx_rotate 0;')
    body+=u.text('owned_state',524,451,92,'dvarInt("apx_browse_unlocked") + " / UNLOCK"',.16,True)
    return u.menu(name,'',body,'character_stuff',shell_on=False,onopen=f'execNow "setu apx_catalog_search search"; setdvar apx_catalog_search ""; execNow "setu apx_catalog_page 1"; setLocalVarInt apx_rotate 0; scriptMenuResponse "browse:{category}:open";',escape='close self; open character_stuff;')


def build(u):
    items=[r for r in u.catalog('itemTable.csv') if len(r)<9 or r[8]!='0']
    for name in ('dr_weapons','apx_primary'):
        u.save(f'ui_mp/scriptmenus/{name}.menu',catalog(u,name,'Primary weapons',items,'weapon',981,3,5,6,'item'))
    characters=[r for r in u.catalog('characterTable.csv') if r[8]!='0']
    for name,title,rows,cat,stat,ic,nc,dc,un in [
        ('dr_characters','Operators',characters,'character',980,3,6,7,'character'),
        ('dr_abilities','Abilities',u.catalog('abilityTable.csv'),'ability',982,4,5,6,'ability'),
        ('dr_sprays','Sprays',u.catalog('sprayTable.csv'),'spray',979,3,5,6,'spray')]:
        u.save(f'ui_mp/scriptmenus/{name}.menu',catalog(u,name,title,rows,cat,stat,ic,nc,dc,un))
    u.save('ui_mp/scriptmenus/apx_knife.menu',catalog(u,'apx_knife','Knives / melee',u.catalog('knifeTable.csv'),'knife',2405,3,5,6,'knife'))
    u.save('ui_mp/scriptmenus/apx_gloves.menu',catalog(u,'apx_gloves','Gloves / arms',u.catalog('gloveTable.csv'),'gloves',2406,0,3,4,'gloves'))
    loadout(u)
