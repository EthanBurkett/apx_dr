#ifndef APX_IMAGE_BUTTON_DEFINED
#define APX_IMAGE_BUTTON_DEFINED
// Shared label inset. The current artwork keeps the interior completely clear.
#define APX_BUTTON_LABEL_X(w) ((w*0.075)+8)
// Background and hit area are the same item, including conditional visibility.
// setbackground is a native CoD4 UI command; labels stay engine-rendered text.
#define APX_IMAGE_BUTTON(id,x,y,w,h,alignment,labelField,scale,textAlign,tx,ty,operation,onItemEnter,onItemExit,visibility) \
itemDef \
{ \
    name id \
    rect x y w h alignment \
    type ITEM_TYPE_BUTTON \
    style WINDOW_STYLE_SHADER \
    background "apx_button_idle" \
    forecolor 1 1 1 1 \
    labelField \
    textfont UI_FONT_NORMAL \
    textstyle ITEM_TEXTSTYLE_SHADOWED \
    textscale scale \
    textalign textAlign \
    textalignx tx \
    textaligny ty \
    visible visibility \
    onFocus { setbackground "apx_button_hover"; onItemEnter } \
    leaveFocus { setbackground "apx_button_idle"; onItemExit } \
    mouseEnter { setbackground "apx_button_hover"; play "mouse_over"; onItemEnter } \
    mouseExit { setbackground "apx_button_idle"; onItemExit } \
    action { setbackground "apx_button_pressed"; play "mouse_click"; operation } \
}
#endif

#define DR_BUTTON(id,x,y,w,h,itemName,itemAction,visArg) \
    DR_BUTTON_EXT(id,x,y,w,h,itemName,itemAction,;,;,visArg)
#define DR_BUTTON2(id,x,y,w,h,itemName,itemAction,visArg) \
    DR_BUTTON2_EXT(id,x,y,w,h,itemName,itemAction,;,;,visArg)
#define DR_BUTTON_EXT(id,x,y,w,h,itemName,itemAction,onItemEnter,onItemExit,visArg) \
    APX_IMAGE_BUTTON("button_default"id,x,y,w,h,DR_BUTTON_ALIGN,exp text(itemName),0.32,ITEM_ALIGN_LEFT,APX_BUTTON_LABEL_X(w),(h-5),itemAction,onItemEnter,onItemExit,visArg)
#define DR_BUTTON2_EXT(id,x,y,w,h,itemName,itemAction,onItemEnter,onItemExit,visArg) \
    APX_IMAGE_BUTTON("button_default"id,x,y,w,h,DR_BUTTON_ALIGN,exp text(itemName),0.3,ITEM_ALIGN_CENTER,0,(h-5),itemAction,onItemEnter,onItemExit,visArg)
