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

// Responsibility: experimental. See docs/ARCHITECTURE.md.

test()
{
	/*while( !self meleeButtonPressed() )
		wait 0.05;

	body = self clonePlayer( 999999999999 );
	body hide();
	body showToPlayer( self );

	thread preview( body );
	wait 1;


	body setModel( level.characterInfo[0].model );

	maxnum = level.characterInfo.size;*/
	while( 1 )
	{
		while( !self useButtonPressed() )
			wait 0.05;
		//while( self meleeButtonPressed() )
		//	wait 0.05;


		wait 0.1;
		self thread makemenotsolid();
		contents = self setContents( 0 );
		//iprintln( "old contents: " + contents );
		//contents = self setContents( 4 );
		//iprintln( "new contents: " + contents );


		//self braxi\_rank::giveRankXP( "kill", 5000 );
		break;
		/*num++;
		body setModel( level.characterInfo[num].model );

		if( num >= maxnum )
			num = 0;*/
	}

}

makeMeNotSolid()
{
    self endon( "disconnect" );
    self endon( "spawned_player" );
    self endon( "joined_spectators" );
    self endon( "death" );

	self setClientDvar( "g_playerCollisionEjectSpeed", 1 );
	while( self isReallyAlive() )
	{
		wait 0.05;
		self setContents( 0 );
	}
}
