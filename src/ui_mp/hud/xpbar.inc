// Bottom-edge progress, with secondary information kept deliberately small.
menuDef
{
    name "xpbar"
    rect 0 0 640 480 0 0
    fullScreen 0
    visible when(APX_HUD_VISIBLE && !dvarInt("apx_minimal_hud"))
    itemDef
    {
        rect 0 477 640 3 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_SUBTOP
        style WINDOW_STYLE_SHADER
        background "white"
        forecolor 0.12 0.16 0.18 0.5
        visible 1
        decoration
    }
    itemDef
    {
        rect 0 477 640 3 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_SUBTOP
        exp rect W(640*dvarFloat("apx_hud_xp"))
        style WINDOW_STYLE_SHADER
        background "apx_xp_fill"
        forecolor 0.86 0.74 0.49 0.85
        visible 1
        decoration
    }
    itemDef
    {
        rect 260 458 14 14 0 0
        style WINDOW_STYLE_SHADER
        exp material(tableLookup("mp/rankIconTable.csv",0,stat(252),1))
        forecolor 1 1 1 0.85
        visible 1
        decoration
    }
    itemDef
    {
        rect 276 458 14 14 0 0
        style WINDOW_STYLE_SHADER
        exp material(tableLookup("mp/apx_prestiges.csv",0,stat(2326),1))
        forecolor 1 1 1 0.85
        visible when(stat(2326)>0)
        decoration
    }
    APX_HUD_LABEL("level",294,456,104,"LV " + (stat(252)+1) + "  /  P " + stat(2326),0.17)
}
