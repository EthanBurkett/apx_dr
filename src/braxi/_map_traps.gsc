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
//	In this script you can add following:
//		- blockers that will create invisible walls for players [ spawnCollision( (X,Y,Z), width, height ) ]
//		- arrays of activation triggers for specified maps, used for freerun and detection of trap usage


#include braxi\_common;

// ApX: map traps implementation.

checkTrapUsage()
{

	if( !level.trapTriggers.size )
	{
		warning( "checkTrapUsage() reported that level.trapTriggers.size is -1, add trap activation triggers to level.trapTriggers array and recompile FF" );
		warning( "Map doesn't support free run and XP for activation" );
		return;
	}

	for( i = 0; i < level.trapTriggers.size; i++ )
	{
		if ( level.dvar[ "freeRunChoice" ] == 2 )
		{
			level.trapTriggers[i] thread killFreeRunIfActivated();
		}
		if ( level.dvar[ "giveXpForActivation" ] )
		{
			level.trapTriggers[i] thread giveXpIfActivated();
		}
		level.trapTriggers[i] thread processTrapChallenge();
	}
}

processTrapChallenge()
{
	self endon( "death" );
	level endon( "endround" );
	self endon( "delete" );
	self endon( "deleted" );

	while( isDefined( self ) )
	{
		self waittill( "trigger", who );
		if( isPlayer( who ) && who.pers["team"] == "axis" )
		{
			if( game["state"] != "playing" )
				return;
			who braxi\_missions::processChallenge( "ch_activated", 1 );
			break;
		}
	}
}

killFreeRunIfActivated()
{
	self endon( "death" );
	level endon( "endround" );
	self endon( "delete" );
	self endon( "deleted" );
	level endon( "kill_free_run_choice" );

	//level.trapsDisabled
	while( isDefined( self ) )
	{
		self waittill( "trigger", who );
		if( isPlayer( who ) && who.pers["team"] == "axis" )
		{
			level.canCallFreeRun = false;
			if( !level.trapsDisabled )
			{
				//who iPrintlnBold( "You have activated trap and now you can't call free run" );
				level notify( "kill_free_run_choice" );
			}
			break;
		}
	}
}

giveXpIfActivated()
{
	self endon( "death" );
	level endon( "endround" );
	self endon( "delete" );
	self endon( "deleted" );

	while( isDefined( self ) )
	{
		self waittill( "trigger", who );
		if( isPlayer( who ) && who.pers["team"] == "axis" )
		{
			if( game["state"] != "playing" )
				return;
			who braxi\_rank::giveRankXP( "trap_activation" );
			break;
		}
	}
}
