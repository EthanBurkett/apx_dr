// Native weapon silhouette; explicit numbers avoid the engine's bullet graphic.
menuDef
{
    name "weaponinfo"
    rect 0 0 640 480 0 0
    fullScreen 0
    visible when(APX_HUD_VISIBLE && NOT_SPECTATING && dvarInt("apx_hud_hp")>0 && dvarInt("apx_hud_ammo_visible") && !dvarBool(ammoCounterHide))
    itemDef
    {
        // Native ownerdraw expands W by the weapon's 1:1/2:1/4:1 icon ratio
        // and moves X left to keep X+W fixed. Supply a square, not final width.
        // Results: 24/48/96 wide, 24 high, all ending at virtual X=616.
        rect 592 423 24 24 0 0
        ownerdraw CG_PLAYER_WEAPON_PRIMARY_ICON
        forecolor 0.86 0.89 0.87 0.82
        visible 1
        decoration
    }
    itemDef
    {
        rect 526 449 46 20 0 0
        exp text(dvarInt("apx_hud_clip"))
        textfont UI_FONT_NORMAL
        textscale 0.32
        textalign ITEM_ALIGN_RIGHT
        textaligny 15
        textstyle ITEM_TEXTSTYLE_SHADOWED
        forecolor 0.94 0.87 0.7 1
        visible 1
        decoration
    }
    itemDef
    {
        rect 577 452 39 16 0 0
        exp text("/ " + dvarInt("apx_hud_stock"))
        textfont UI_FONT_NORMAL
        textscale 0.2
        textaligny 12
        textstyle ITEM_TEXTSTYLE_SHADOWED
        forecolor 0.8 0.85 0.85 0.9
        visible 1
        decoration
    }
    itemDef
    {
        rect 552 402 12 15 0 0
        ownerdraw CG_OFFHAND_WEAPON_ICON_FRAG
        forecolor 0.85 0.89 0.9 0.6
        visible 1
        decoration
    }
    itemDef
    {
        rect 568 402 16 15 0 0
        ownerdraw CG_OFFHAND_WEAPON_AMMO_FRAG
        textfont UI_FONT_NORMAL
        textscale 0.18
        forecolor 0.85 0.89 0.9 0.8
        visible 1
        decoration
    }
    itemDef
    {
        rect 586 402 12 15 0 0
        ownerdraw CG_OFFHAND_WEAPON_ICON_SMOKEFLASH
        forecolor 0.85 0.89 0.9 0.6
        visible 1
        decoration
    }
    itemDef
    {
        rect 602 402 16 15 0 0
        ownerdraw CG_OFFHAND_WEAPON_AMMO_SMOKEFLASH
        textfont UI_FONT_NORMAL
        textscale 0.18
        forecolor 0.85 0.89 0.9 0.8
        visible 1
        decoration
    }
}
