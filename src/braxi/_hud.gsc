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

#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

#include braxi\_common;
#include braxi\_dvar;

// Responsibility: hud. See docs/ARCHITECTURE.md.

addTextHud( who, x, y, alpha, alignX, alignY, fontScale )
{
	if( isPlayer( who ) )
		hud = newClientHudElem( who );
	else
		hud = newHudElem();

	hud.x = x;
	hud.y = y;
	hud.alpha = alpha;
	hud.alignX = alignX;
	hud.alignY = alignY;
	hud.fontScale = fontScale;
	return hud;
}

endRoundAnnoucement( text, color )
{
	notifyData = spawnStruct();
	notifyData.titleText = text;
	notifyData.notifyText = ("Starting round ^3" + game["roundsplayed"] + "^7 out of ^3" + level.dvar["round_limit"] );
	//notifyData.iconName = "logo_brax";
	notifyData.glowColor = color;
	notifyData.duration = 8.8;

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
		players[i] thread maps\mp\gametypes\_hud_message::notifyMessage( notifyData );
}

roundStartTimer()
{	
	
	if( isDefined( level.matchStartText ) )
		level.matchStartText destroyElem();

	level.matchStartText = createServerFontString( "objective", 1.4 );
	level.matchStartText setPoint( "CENTER", "CENTER", 0, -20 );
	level.matchStartText.sort = 1001;
	level.matchStartText setText( level.text["round_begins_in"] );
	level.matchStartText.foreground = false;
	level.matchStartText.hidewheninmenu = true;
	
	level.matchStartTimer = createServerTimer( "objective", 1.6 );
	level.matchStartTimer setPoint( "CENTER", "CENTER", 0, 0 );
	level.matchStartTimer setTimer( level.dvar["spawn_time"] );
	level.matchStartTimer.sort = 1001;
	level.matchStartTimer.foreground = false;
	level.matchStartTimer.hideWhenInMenu = true;
		
	wait level.dvar["spawn_time"];
	
	level.matchStartText destroyElem();
	level.matchStartTimer destroyElem();
}

// Keep the existing timer handles for round/map compatibility.
doHud()
{
    level endon( "intermission" );
    level.hud_round = statusText( -24, 16, 1.4 );
    level.hud_round setText( "ROUND " + game["roundsplayed"] + " / " + level.dvar["round_limit"] );
    level.hud_time = statusText( -24, 36, 1.7 );
    level.hud_time.color = (0.88,0.78,0.56);
    level.hud_jumpers = statusText( -24, 63, 1.4 );
    level.hud_jumpers.label = &"JUMPERS &&1";
    level thread braxi\_hud_state::run();
    for(;;)
    {
        if( isDefined( level.hud_jumpers ) )
        {
            level.hud_jumpers.alpha = 1;
            if( level.freeRun || (isDefined( level.efrActive ) && level.efrActive) ) level.hud_jumpers.alpha = 0;
            level.hud_jumpers setValue( level.jumpers );
        }
        if( isDefined( level.hud_time ) && isDefined( level.efrActive ) && level.efrActive ) level.hud_time.alpha = 0;
        wait 0.5;
    }
}

statusText( x, y, size )
{
    hud = newHudElem();
    hud.x = x;
    hud.y = y;
    hud.alignX = "right";
    hud.alignY = "top";
    hud.horzAlign = "right";
    hud.vertAlign = "top";
    hud.font = "objective";
    hud.fontScale = size;
    hud.color = (0.88,0.91,0.92);
    hud.glowAlpha = 0;
    hud.hideWhenInMenu = true;
    hud.foreground = true;
    hud.sort = 1;
    return hud;
}

// Compatibility initializer; _hud_state maintains health, including healing.
updateHealthBar()
{
    if( isDefined( self.health ) && isDefined( self.maxhealth ) )
        self setClientDvar( "ui_healthbar", braxi\_hud_state::fraction( self.health, 0, self.maxhealth ) );
}

serverMessages()
{
	if( !level.dvar["messages_enable"] )
		return;

	messages = strTok( level.dvar["messages"], ";" );
	lastMessage = messages.size-1;
	if( !isDefined( game["msg_time"] ) )	game["msg_time"] = 0;
	if( !isDefined( game["msg"] ) )			game["msg"] = 0;

	while( 1 )
	{
		if( game["msg_time"] == level.dvar["messages_delay"] )
		{
			game["msg_time"] = 0;
			iPrintln( "^1>>^7 " + messages[game["msg"]] );
			game["msg"]++;
			if( game["msg"] > lastMessage )
				game["msg"] = 0;
		}
		wait 1;
		game["msg_time"]++;
	}
}

new_ending_hud( align, fade_in_time, x_off, y_off )
{
	hud = newHudElem();
    hud.foreground = true;
	hud.x = x_off;
	hud.y = y_off;
	hud.alignX = align;
	hud.alignY = "middle";
	hud.horzAlign = align;
	hud.vertAlign = "middle";

 	hud.fontScale = 1.6;

	hud.color = (0.88, 0.91, 0.92);
	hud.font = "objective";
	hud.glowColor = (0.3, 0.6, 0.3);
	hud.glowAlpha = 0;

	hud.alpha = 0;
	hud fadeovertime( fade_in_time );
	hud.alpha = 1;
	hud.hidewheninmenu = true;
	hud.sort = 10;
	return hud;
}

drawInformation( start_offset, movetime, mult, text )
{
	start_offset *= mult;
	hud = new_ending_hud( "center", 0.1, start_offset, 90 );
	hud setText( text );
	hud moveOverTime( movetime );
	hud.x = 0;
	wait( movetime );
	wait( 3 );
	hud moveOverTime( movetime );
	hud.x = start_offset * -1;

	wait movetime;
	hud destroy();
}

showAbility()
{
	self notify( "show ability" );
	self endon( "show ability" );
	self endon( "disconnect" );

	if( isDefined( self.abilityHud ) )
		self.abilityHud destroy();

	self.abilityHud = newClientHudElem( self );
	self.abilityHud.x = 299.5;
	self.abilityHud.y = 370;
	self.abilityHud.alpha = 0.3;
	self.abilityHud setShader( self.pers["ability"], 55, 48 );
	self.abilityHud.sort = 985;
	
	self.abilityHud fadeOverTime( 0.3 );
	self.abilityHud.alpha = 1;
	wait 1;
	self.abilityHud fadeOverTime( 0.2 );
	self.abilityHud.alpha = 0;
	wait 0.2;
	self.abilityHud destroy();
}
