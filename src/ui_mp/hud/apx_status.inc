menuDef
{
    name "scorebars"
    rect 0 0 640 480 0 0
    fullScreen 0
    visible when(APX_HUD_VISIBLE)
    APX_LOGO(20,6,104,52,0 0,0.75,when(!dvarInt("apx_minimal_hud")))
    APX_HUD_LABEL("mode",24,48,120,dvarString("apx_hud_mode"),0.17)
    itemDef
    {
        rect 242 45 156 16 0 0
        exp text(dvarString("apx_hud_detail"))
        textfont UI_FONT_NORMAL
        textscale 0.2
        textalign ITEM_ALIGN_CENTER
        textaligny 12
        textstyle ITEM_TEXTSTYLE_SHADOWED
        forecolor 0.91 0.84 0.68 0.9
        visible when(dvarInt("apx_efr_active"))
        decoration
    }
    itemDef
    {
        rect 24 441 98 28 0 0
        style WINDOW_STYLE_SHADER
        background "white"
        forecolor 0.05 0.075 0.09 0.2
        visible when(NOT_SPECTATING && dvarInt("apx_hud_hp")>0)
        decoration
    }
    itemDef
    {
        rect 30 441 86 16 0 0
        exp text("HP  " + dvarInt("apx_hud_hp"))
        textfont UI_FONT_NORMAL
        textscale 0.21
        textaligny 12
        textstyle ITEM_TEXTSTYLE_SHADOWED
        forecolor 0.9 0.92 0.92 1
        visible when(NOT_SPECTATING && dvarInt("apx_hud_hp")>0)
        decoration
    }
    itemDef
    {
        rect 30 460 86 3 0 0
        style WINDOW_STYLE_SHADER
        background "white"
        forecolor 0.35 0.4 0.43 0.4
        visible when(NOT_SPECTATING && dvarInt("apx_hud_hp")>0)
        decoration
    }
    itemDef
    {
        rect 30 460 86 3 0 0
        exp rect W(86*dvarFloat("apx_hud_health"))
        style WINDOW_STYLE_SHADER
        background "apx_health_fill"
        // Encode health in alpha for the HLSL red -> gold -> mint palette.
        forecolor 0.49 0.81 0.67 1
        exp forecolor A(0.5+0.5*dvarFloat("apx_hud_health"))
        visible when(NOT_SPECTATING && dvarInt("apx_hud_hp")>0)
        decoration
    }
    itemDef
    {
        rect 30 458 86 7 0 0
        style WINDOW_STYLE_SHADER
        background "white"
        forecolor 1 0.4 0.3 0
        exp forecolor A(dvarFloat("apx_hud_damage_flash")*0.65)
        visible when(NOT_SPECTATING && dvarInt("apx_hud_hp")>0)
        decoration
    }
}
