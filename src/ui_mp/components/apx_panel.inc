#include "ui/menudef.h"
#include "ui_mp/components/brand.inc"
#include "ui_mp/components/buttons.inc"
// Keep expression fields on separate source lines for the CoD4 menu compiler.
#define APX_TEXT(id,x,y,w,label,size) \
itemDef \
{ \
    name id \
    rect x y w 22 0 0 \
    exp text( label ) \
    textfont UI_FONT_NORMAL \
    textscale size \
    textaligny 17 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.91 1 \
    visible 1 \
    decoration \
}
#define APX_LINE(x,y,w) \
itemDef \
{ \
    rect x y w 1 0 0 \
    style WINDOW_STYLE_SHADER \
    background "white" \
    forecolor 0.42 0.48 0.51 0.4 \
    visible 1 \
    decoration \
}
#define APX_BUTTON(id,x,y,w,label,operation,condition) \
    APX_IMAGE_BUTTON(id,x,y,w,25,0 0,text label,0.32,ITEM_ALIGN_LEFT,APX_BUTTON_LABEL_X(w),18,operation,;,;,when(condition))
#define APX_DISABLED_BUTTON(id,x,y,w,label,condition) \
itemDef \
{ \
    name id \
    rect x y w 25 0 0 \
    style WINDOW_STYLE_SHADER \
    background "apx_button_disabled" \
    forecolor 0.65 0.69 0.71 1 \
    text label \
    textfont UI_FONT_NORMAL \
    textscale 0.3 \
    textalignx APX_BUTTON_LABEL_X(w) \
    textaligny 18 \
    visible when(condition) \
    decoration \
}
#define APX_PANEL() \
itemDef \
{ \
    rect 16 20 608 440 0 0 \
    style WINDOW_STYLE_SHADER \
    background "white" \
    forecolor 0.055 0.08 0.1 0.98 \
    visible 1 \
    decoration \
}

#define APX_RIGHT_TEXT(id,x,y,w,label,size) \
itemDef \
{ \
    name id \
    rect x y w 22 0 0 \
    exp text( label ) \
    textfont UI_FONT_NORMAL \
    textscale size \
    textalign ITEM_ALIGN_RIGHT \
    textaligny 17 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.91 1 \
    visible 1 \
    decoration \
}
