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


#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;


// ApX: rank integrity implementation.

antiHack()
{
	wait 0.05;
	baseVal = level.dvar["antiHackStat"];

	//if( self getTimePlayed() < (24*3600)/*15hours*/ && self.pers["rank"] >= 28  )
	//{
	//	// obviously hacked his rank
	//	punishHacker( self, "rank" );
	//}

	// === most important stats === //
	self verifyStat( 2326, baseVal, "prestige" );	// PRESTIGE	
	if( self getStat( 2350 ) > 1 )
		self verifyStat( 2350, baseVal+1, "rank" );	// RANK	
	self verifyStat( 2301, baseVal+2, "rank" );		// XP

	// === abilities === //
	self verifyStat( 3200, baseVal+3, "abilities" );
	self verifyStat( 3201, baseVal+4, "abilities" );
	self verifyStat( 3202, baseVal+5, "abilities" );
	self verifyStat( 3203, baseVal+6, "abilities" );
	self verifyStat( 3204, baseVal+7, "abilities" );
	self verifyStat( 3205, baseVal+8, "abilities" );
	self verifyStat( 3206, baseVal+9, "abilities" );
	self verifyStat( 3207, baseVal+10, "abilities" );

	//2314
}

updateAntiHackValues()
{
	baseVal = level.dvar["antiHackStat"];

	// THESE MUST MATCH ORDER IN antiHack() !!!
	self setStatFromStat( 2326, baseVal );
	self setStatFromStat( 2350, baseVal+1 );
	self setStatFromStat( 2301, baseVal+2 );

	self setStatFromStat( 3200, baseVal+3 );
	self setStatFromStat( 3201, baseVal+4 );
	self setStatFromStat( 3202, baseVal+5 );
	self setStatFromStat( 3203, baseVal+6 );
	self setStatFromStat( 3204, baseVal+7 );
	self setStatFromStat( 3205, baseVal+8 );
	self setStatFromStat( 3206, baseVal+9 );
	self setStatFromStat( 3207, baseVal+10 );
}

setStatFromStat( stat2, stat1 )
{
	self setStat( stat1, self getStat( stat2 ) );
}

verifyStat( stat, antiHackStat, what )
{
	if( self getStat( stat ) == self getStat( antiHackStat ) )
		return;
	
	punishHacker( self, what );
}

verifyStatValue( stat, expectedValue, what )
{
	if( self getStat( stat ) == expectedValue )
		return;
	punishHacker( self, what );	
}

punishHacker( player, what )
{
	iPrintlnBold( "^1" + player.name + " ^1tried to hack his "+ what + " :<" );

	self resetEverything();
	braxi\_rank_progression::updateRankStats( player, 0 );
	player updateAntiHackValues();

	player setClientDvars( "ui_dr_info", "^1It appears you tried to modify your profile.", "ui_dr_info2", "^1Your rank was reseted." );
	player braxi\_common::clientCmd( "wait 100;disconnect" );

	logPrint( "PROFILE_HACKER;" + player getGuid() + ";" + player getEntityNumber() + ";" + player.name + "\n" );
}

resetEverything()
{
	self.pers["prestige"] = 0;
	self.pers["rank"] = 0;
	self.pers["rankxp"] = 0;

	self setRank( self.pers["rank"], self.pers["prestige"] );

	self setStat( 2326, self.pers["prestige"] );
	self setStat( 2350, self.pers["rank"] );
	self setStat( 2301, self.pers["rankxp"] );

	for( stat = 3200; stat < 3208; stat++ ) // abilities
		self setStat( stat, 0 );

	for( stat = 979; stat < 983; stat++ ) // spray, character, weapon & ability
		self setStat( stat, 0 );
}
