// Shared, restrained ApX gameplay notices. No pulsing stock announcement HUD.
text( x, y, value, size )
{
    hud = newHudElem();
    hud.horzAlign = "center";
    hud.vertAlign = "top";
    hud.alignX = "left";
    hud.alignY = "top";
    hud.x = x;
    hud.y = y;
    hud.font = "objective";
    hud.fontScale = size;
    hud.color = (.88,.91,.90);
    hud.glowAlpha = 0;
    hud.hideWhenInMenu = true;
    hud.foreground = true;
    hud.sort = 90;
    hud setText( value );
    return hud;
}

clearNotice()
{
    if( !isDefined( level.apxNotice ) ) return;
    for( i = 0; i < level.apxNotice.size; i++ )
        if( isDefined( level.apxNotice[i] ) ) level.apxNotice[i] destroy();
    level.apxNotice = [];
}

notice( title, detail )
{
    level notify( "apx_notice" );
    level endon( "apx_notice" );
    clearNotice();
    level.apxNotice = [];
    panel = newHudElem();
    panel.horzAlign = "center";
    panel.vertAlign = "top";
    panel.x = -170;
    panel.y = 82;
    panel.color = (.045,.06,.069);
    panel.alpha = .94;
    panel.sort = 89;
    panel.hideWhenInMenu = true;
    panel setShader( "white", 340, 45 );
    level.apxNotice[0] = panel;
    level.apxNotice[1] = text( -154, 88, title, 1.25 );
    level.apxNotice[1].color = (.88,.77,.53);
    level.apxNotice[2] = text( -154, 108, detail, 1.0 );
    wait 2.8;
    for( i = 0; i < level.apxNotice.size; i++ )
    {
        level.apxNotice[i] fadeOverTime( .2 );
        level.apxNotice[i].alpha = 0;
    }
    wait .2;
    clearNotice();
}
