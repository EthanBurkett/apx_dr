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

// Responsibility: lives. See docs/ARCHITECTURE.md.

SetupLives()
{
	self endon( "disconnect" );

	if( !level.dvar["allowLifes"] )
		return;

	destroyLifeIcons();
	self.hud_lifes = [];
	if( !isDefined( self.pers["lifes"] ) || self.pers["lifes"] < 0 ) self.pers["lifes"] = 0;
	if( self.pers["lifes"] > 3 ) self.pers["lifes"] = 3; // hud elems array
	
	self addLifeIcon( 0, 16, 94, -18, 10 );
	self addLifeIcon( 1, 16, 94, -18, 10 );
	self addLifeIcon( 2, 16, 94, -18, 10 );

	wait .05;
	
	if( !self.pers["lifes"] )
		return;

	for( i = 0; i < self.pers["lifes"]; i++ )
	{
		self.hud_lifes[i] showLifeIcon();
	}
}

giveLife()
{
	if( !level.dvar["allowLifes"] )
		return;

	if( self.pers["lifes"] >= 3 )
		return; 

	self.pers["lifes"]++;

	// hud stuff;
	hud = self.hud_lifes[ self.pers["lifes"]-1 ];
	hud showLifeIcon();

	hud SetPulseFX( 30, 100000, 700 );
	//self iprintlnBold( "You earned additional life" );
}

showLifeIcon()
{
	self fadeOverTime( 1 );
	self.alpha = 1;
	self.glowAlpha = 1;
	self.color = level.color_cool_green;
}

useLife()
{
	if( game["state"] != "playing" || self.pers["team"] != "allies" || !self.pers["lifes"] || self.sessionstate == "playing" || !level.dvar["allowLifes"] )
		return; 

	hud = self.hud_lifes[ self.pers["lifes"]-1 ];
	hud fadeOverTime( 1 );
	hud.alpha = 0;
	hud.glowAlpha = 0;
	//hud.color = (0.88,0.78,0.56);

	self.pers["lifes"]--;

	if( !self.pers["lifes"] )
		self iPrintlnBold( "This was your last life, don't waste it" );
	else
		self iprintlnBold( "You used one of your additional lifes" );

	if( level.dvar["insertion"] && isDefined( self.insertion ) )
	{
		self braxi\_player::spawnPlayer( self.insertion.origin, (0,self.insertion.angles[1],0) );
	}
	else
		self braxi\_player::spawnPlayer();

	self.usedLife = true;
}

addLifeIcon( num, x, y, offset, sort )
{

	hud = newClientHudElem( self );
    hud.foreground = true;
	hud.x = -24 - num * 15;
	hud.y = 84;
	hud setShader( "stance_stand", 13, 18 );
	hud.alignX = "right";
	hud.alignY = "top";
	hud.horzAlign = "right";
	hud.vertAlign = "top";
	hud.sort = sort;
	hud.color = (0.88,0.78,0.56);
	hud.glowColor = level.color_cool_green_glow;
	hud.glowAlpha = 0;
	hud.alpha = 0;
 	hud.hidewheninmenu = true;
 	self.hud_lifes[num] = hud;
}

destroyLifeIcons()
{
	if( !isDefined( self.hud_lifes ) )
		return;
	for( i = 0; i < self.hud_lifes.size; i++ )
		if( isDefined( self.hud_lifes[i] ) )
			self.hud_lifes[i] destroy();
}
