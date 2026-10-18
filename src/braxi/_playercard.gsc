///////////////////////////////////////////////////////////////
////|         |///|        |///|       |/\  \/////  ///|  |////
////|  |////  |///|  |//|  |///|  |/|  |//\  \///  ////|__|////
////|  |////  |///|  |//|  |///|  |/|  |///\  \/  /////////////
////|          |//|  |//|  |///|       |////\    //////|  |////
////|  |////|  |//|         |//|  |/|  |/////    \/////|  |////
////|  |////|  |//|  |///|  |//|  |/|  |////  /\  \////|  |////
////|  |////|  |//|  | //|  |//|  |/|  |///  ///\  \///|  |////
////|__________|//|__|///|__|//|__|/|__|//__/////\__\//|__|////
///////////////////////////////////////////////////////////////
/*
	BraXi's Death Run Mod
	(c) 2010-2020 Paulina Sokołowska

	https://www.moddb.com/mods/braxs-death-run-mod

	Twitter: https://twitter.com/TheBraXi
	GitHub: https://github.com/BraXi/

	E-mail: paulinabraxi somewhere at gmail.com
*/

// ApX compact elimination strip, using saved sprays or real ApX rank badges.
init()
{
    for(;;)
    {
        level waittill( "player_killed", victim, inflictor, attacker );
        if( !isDefined( attacker ) || !isDefined( victim ) ) continue;
        thread showPlayerCard( attacker, victim, "ELIMINATION" );
    }
}

icon( player )
{
    if( level.dvar["playerCardIcons"] == 0 ) return "spray"+player getStat(979)+"_menu";
    return braxi\_rank_tables::getRankInfoIcon( player.pers["rank"], player.pers["prestige"] );
}

showPlayerCard( attacker, victim, text )
{
    if( !level.dvar["playerCards"] || attacker == victim || !isPlayer( attacker ) || game["state"] == "endmap" ) return;
    level notify( "new emblem" );
    level endon( "new emblem" );
    destroyPlayerCard();
    level.playerCard = [];
    panel = newHudElem();
    panel.horzAlign = "center";
    panel.vertAlign = "bottom";
    panel.x = -170;
    panel.y = -112;
    panel.color = (.045,.06,.069);
    panel.alpha = .94;
    panel.hideWhenInMenu = true;
    panel.sort = 89;
    panel setShader( "white", 340, 44 );
    level.playerCard[0] = panel;
    for( i = 0; i < 2; i++ )
    {
        player = attacker;
        if( i == 1 ) player = victim;
        hud = newHudElem();
        hud.horzAlign = "center";
        hud.vertAlign = "bottom";
        hud.x = -157+i*284;
        hud.y = -104;
        hud.hideWhenInMenu = true;
        hud.sort = 90;
        hud setShader( icon(player), 30, 30 );
        level.playerCard[level.playerCard.size] = hud;
    }
    title = braxi\_presentation::text( 0, -106, text, .95 );
    title.vertAlign = "bottom";
    title.alignX = "center";
    title.color = (.88,.77,.53);
    level.playerCard[level.playerCard.size] = title;
    names = braxi\_scoreboard_panel::displayName(attacker.name)+" / "+braxi\_scoreboard_panel::displayName(victim.name);
    hud = braxi\_presentation::text( 0, -90, names, 1.0 );
    hud.vertAlign = "bottom";
    hud.alignX = "center";
    level.playerCard[level.playerCard.size] = hud;
    wait 2;
    for( i = 0; i < level.playerCard.size; i++ )
    {
        level.playerCard[i] fadeOverTime(.2);
        level.playerCard[i].alpha = 0;
    }
    wait .2;
    destroyPlayerCard();
}

destroyPlayerCard()
{
    if( !isDefined( level.playerCard ) ) return;
    for( i = 0; i < level.playerCard.size; i++ )
        if( isDefined( level.playerCard[i] ) ) level.playerCard[i] destroy();
    level.playerCard = [];
}
