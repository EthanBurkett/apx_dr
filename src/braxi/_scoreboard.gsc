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

#include braxi\_common;
init()
{

	setdvar("g_TeamName_Allies", "^2Jumpers");
	setdvar("g_TeamIcon_Allies", "killiconfalling");
	setdvar("g_TeamColor_Allies", "0 0.8 0");
	setdvar("g_ScoresColor_Allies", "0.1 0.8 0.1");

	setdvar("g_TeamName_Axis", "^1Activator");
	setdvar("g_TeamIcon_Axis", "killiconsuicide");
	setdvar("g_TeamColor_Axis", "0.8 0 0");
	setdvar("g_ScoresColor_Axis", "0.8 0.1 0.1");

	setdvar("g_ScoresColor_Spectator", ".25 .25 .25");
	setdvar("g_ScoresColor_Free", ".76 .78 .10");
	setdvar("g_teamColor_MyTeam", ".6 .8 .6" );
	setdvar("g_teamColor_EnemyTeam", "1 .45 .5" );	

	level thread configureClients();
	//precacheString(
}

showBestStats()
{
	braxi\_intermission::present( 0, 8 );
}



destroyHudAfterTime( time )
{
	self fadeOverTime( time );
	self.alpha = 0;
	wait time;
	self destroy();
}

showHud( hud, X, alpha, movetime, fadetime )
{
	hud moveOverTime( movetime );
	hud.x = x;

	hud fadeOverTime( fadetime );
	hud.alpha = alpha;
}

/*
showBestStats()
{
	level.hud_best_players = newHudElem();
	level.hud_best_players.x = 320;
	level.hud_best_players.y = 105;
	level.hud_best_players.alignX = "center";
	level.hud_best_players.alignY = "middle";
	level.hud_best_players.alpha = 0;
	level.hud_best_players.sort = 10;

	wait 1;

	guy = getBestPlayerFromScore( "score" );
	if( guy.pers["kills"] )
	{
		cleanScreen();
		level.hud_best_players thread changeImage( "killiconsuicide" ); //<CHANGE THIS
		iPrintlnBold( guy.name + "^2 is ^1THE BEST PLAYER ^2with ^3" + guy.pers["score"] + "^2 score." );
		wait 2.6;
	}

	guy = getBestPlayerFromScore( "kills" );
	if( guy.pers["kills"] )
	{
		cleanScreen();
		level.hud_best_players thread changeImage( "killiconsuicide" );
		iPrintlnBold( guy.name + "^2 is ^1THE BEST KILLER ^2with ^3" + guy.pers["kills"] + "^2 kills total." );
		wait 2.6;
	}

	guy = getBestPlayerFromScore( "knifes" );
	if( guy.pers["knifes"] )
	{
		cleanScreen();
		level.hud_best_players thread changeImage( "killiconmelee" );
		iPrintlnBold( guy.name + "^2 is ^1NINJA ^2with ^3" + guy.pers["knifes"] + "^2 melee kills." );
		wait 2.6;
	}

	guy = getBestPlayerFromScore( "headshots" );
	if( guy.pers["headshots"] )
	{
		cleanScreen();
		level.hud_best_players thread changeImage( "killiconheadshot" );
		iPrintlnBold( guy.name + "^2 is ^2HEAD HUNTER ^2with ^3" + guy.pers["headshots"] + "^2 head shot kills." );
		wait 2.6;
	}

	cleanScreen();
	level.hud_best_players destroy();

	wait 0.5;
}


changeImage( image )
{
	self.alpha = 0;
	self setShader( image, 64, 64 );
	self fadeOverTime( 0.4 );
	self.alpha = 1;
	wait 2.2;
	self fadeOverTime( 0.4 );
	self.alpha = 0;
}*/


addIconHud( who, x, y, alpha, shader, scalex, scaley )
{
	if( isPlayer( who ) )
		hud = newClientHudElem( who );
	else
		hud = newHudElem();

	hud.x = x;
	hud.y = y;
	hud.alpha = alpha;
	hud setShader( shader, scalex, scaley );

	return hud;
}

//"center", "middle"
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
	hud.fontScale = braxi\_presentation::fontScale( fontScale );
	return hud;
}
configureClients()
{
	for(;;)
	{
		level waittill( "connected", player );
		// Keep the native cgame rows and footer below the virtual 480px viewport.
		// The custom UI menu retains the normal score-key lifecycle.
		player setClientDvars( "cg_scoreboardHeight", 10000, "cg_scoreboardItemHeight", 1000 );
		player thread braxi\_scoreboard_panel::prime();
	}
}
