// Shared row geometry for the native Tab scoreboard override.
#define APX_SCORE_ROW(id,y) \
itemDef \
{ \
    rect 48 y 544 21 0 0 \
    style WINDOW_STYLE_SHADER \
    background "white" \
    forecolor 0.045 0.065 0.08 0.24 \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 52 y 21 21 0 0 \
    style WINDOW_STYLE_SHADER \
    exp material( tablelookup("mp/rankIconTable.csv",0,dvarInt("apx_sb_"id"_rank"),1) ) \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 82 y 21 21 0 0 \
    style WINDOW_STYLE_SHADER \
    exp material( tablelookup("mp/apx_prestiges.csv",0,dvarInt("apx_sb_"id"_prestige"),1) ) \
    visible when( dvarInt("apx_sb_"id"_has") && dvarInt("apx_sb_"id"_prestige") > 0 ) \
    decoration \
} \
itemDef \
{ \
    rect 112 y 187 21 0 0 \
    exp text( dvarString("apx_sb_"id"_name") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.3 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 302 y 72 21 0 0 \
    exp text( dvarString("apx_sb_"id"_team") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.23 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 382 y 40 21 0 0 \
    exp text( dvarString("apx_sb_"id"_state") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.24 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 426 y 76 21 0 0 \
    exp text( dvarString("apx_sb_"id"_score") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.3 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    textalign ITEM_ALIGN_RIGHT \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 508 y 34 21 0 0 \
    exp text( dvarString("apx_sb_"id"_kills") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.3 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    textalign ITEM_ALIGN_RIGHT \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
} \
itemDef \
{ \
    rect 550 y 34 21 0 0 \
    exp text( dvarString("apx_sb_"id"_deaths") ) \
    textfont UI_FONT_NORMAL \
    textscale 0.3 \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.9 1 \
    textalign ITEM_ALIGN_RIGHT \
    visible when( dvarInt("apx_sb_"id"_has") ) \
    decoration \
}
