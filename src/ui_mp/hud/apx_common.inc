#define APX_HUD_VISIBLE (!ui_active() && !menuisopen(scoreboard) && !inkillcam() && !flashbanged() && dvarString("show_hud") == "true")
#define APX_HUD_LABEL(id,x,y,w,label,size) \
itemDef \
{ \
    name id \
    rect x y w 18 0 0 \
    exp text(label) \
    textfont UI_FONT_NORMAL \
    textscale size \
    textaligny 13 \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    forecolor 0.9 0.92 0.92 1 \
    visible 1 \
    decoration \
}
#define APX_HUD_RECT(x,y,w,h,r,g,b,a) \
itemDef \
{ \
    rect x y w h 0 0 \
    style WINDOW_STYLE_SHADER \
    background "white" \
    forecolor r g b a \
    visible 1 \
    decoration \
}
