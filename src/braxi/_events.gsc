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

// Responsibility: events. See docs/ARCHITECTURE.md.

firstBlood()
{
    if( !level.dvar["firstBlood"] ) return;
    level waittill( "activator" );
    wait .1;
    level waittill( "player_killed", who );
    if( !isDefined( who ) ) return;
    level thread playSoundOnAllPlayers( "first_blood" );
    braxi\_presentation::notice( "FIRST BLOOD", braxi\_scoreboard_panel::displayName( who.name ) + " was first to fall." );
}

lastJumper()
{
    if( !level.dvar["lastalive"] || level.lastJumper ) return;
    level.lastJumper = true;
    level thread playSoundOnAllPlayers( "last_alive" );
    braxi\_presentation::notice( "LAST RUNNER", braxi\_scoreboard_panel::displayName( self.name ) + " is still in the run." );
}
