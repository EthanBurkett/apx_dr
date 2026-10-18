#ifndef APX_SHELL_DEFINED
#define APX_SHELL_DEFINED
#include "ui/menudef.h"
#include "ui_mp/components/brand.inc"
#include "ui_mp/components/buttons.inc"
#define APX_UI_TEXT(id,x,y,w,label,size) \
itemDef \
{ \
    name id \
    rect x y w 20 0 0 \
    exp text(label) \
    textfont UI_FONT_NORMAL \
    textscale size \
    textaligny 15 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.88 0.91 0.9 1 \
    visible 1 \
    decoration \
}
#define APX_UI_RECT(x,y,w,h,color) \
itemDef \
{ \
    rect x y w h 0 0 \
    style WINDOW_STYLE_SHADER \
    background "white" \
    forecolor color \
    visible 1 \
    decoration \
}
#define APX_UI_BUTTON(id,x,y,w,label,operation,condition) \
APX_IMAGE_BUTTON(id,x,y,w,27,0 0,exp text(label),0.26,ITEM_ALIGN_LEFT,12,18,operation,;,;,when(condition))
#define APX_UI_LOCKED(id,x,y,w,label,condition) \
itemDef \
{ \
    name id \
    rect x y w 27 0 0 \
    style WINDOW_STYLE_SHADER \
    background "apx_button_disabled" \
    exp text(label) \
    textfont UI_FONT_NORMAL \
    textscale 0.23 \
    textalignx 12 \
    textaligny 18 \
    forecolor 0.48 0.55 0.56 1 \
    visible when(condition) \
    decoration \
}
#define APX_UI_BACKDROP(material) \
itemDef \
{ \
    rect 0 0 640 480 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN \
    style WINDOW_STYLE_SHADER \
    background material \
    forecolor 1 1 1 1 \
    visible 1 \
    decoration \
}
#define APX_UI_IMAGE(x,y,w,h,material) \
itemDef \
{ \
    rect x y w h 0 0 \
    style WINDOW_STYLE_SHADER \
    exp material(material) \
    forecolor 1 1 1 1 \
    visible 1 \
    decoration \
}
#endif
