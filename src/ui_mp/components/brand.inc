#ifndef APX_BRAND_DEFINED
#define APX_BRAND_DEFINED
// The logo texture is 2:1 with transparent padding; retain that quad ratio.
#define APX_LOGO(x,y,w,h,alignment,opacity,visibility) \
itemDef \
{ \
    rect x y w h alignment \
    style WINDOW_STYLE_SHADER \
    background "apx_logo" \
    forecolor 1 1 1 opacity \
    visible visibility \
    decoration \
}
#endif
