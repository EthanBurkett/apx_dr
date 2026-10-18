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
#include braxi\_common;

// ApX bootstrap and compatibility entry points.

init()
{
	if ( !mayProcessChallenges() )
		return;
	
	level.numChallengeTiers	= 2;

	level.ch_ownage = 0;
	level.ch_machines = 0;

	braxi\_rank::registerScoreInfo( "challenge", 250 );
	precacheString( &"MP_CHALLENGE_COMPLETED" );

	braxi\_challenge_data::buildChallegeInfo();

	thread braxi\_challenge_events::playerConnected();
	thread braxi\_challenge_events::playerSpawned();
	thread braxi\_challenge_events::playerKilled();
	thread braxi\_challenge_events::playerDamaged();

	thread braxi\_challenge_events::onEndRound();
	thread braxi\_challenge_events::onEndMap();
}

mayProcessChallenges()
{
	if( isDefined( level.efrActive ) && level.efrActive ) return false;
	return true;
}

onEndRound()
{
	return braxi\_challenge_events::onEndRound();
}

onEndMap()
{
	return braxi\_challenge_events::onEndMap();
}

playerConnected()
{
	return braxi\_challenge_events::playerConnected();
}

onPlayerDisconnect()
{
	return braxi\_challenge_events::onPlayerDisconnect();
}

test()
{
	return braxi\_challenge_events::test();
}

playerSpawned()
{
	return braxi\_challenge_events::playerSpawned();
}

playerDamaged()
{
	return braxi\_challenge_events::playerDamaged();
}

playerKilled()
{
	return braxi\_challenge_events::playerKilled();
}

ch_spray()
{
	return braxi\_challenge_events::ch_spray();
}

dumpTable( tableName )
{
	return braxi\_challenge_data::dumpTable( tableName );
}

buildChallegeInfo()
{
	return braxi\_challenge_data::buildChallegeInfo();
}

updateChallenges()
{
	return braxi\_challenge_data::updateChallenges();
}

unlockChallenge( refString )
{
	return braxi\_challenge_progress::unlockChallenge( refString );
}

unlockChallengeSingular( refString )
{
	return braxi\_challenge_progress::unlockChallengeSingular( refString );
}

unlockChallengeGroup( refString )
{
	return braxi\_challenge_progress::unlockChallengeGroup( refString );
}

getChallengeStatus( name )
{
	return braxi\_challenge_data::getChallengeStatus( name );
}

getChallengeLevels( baseName )
{
	return braxi\_challenge_data::getChallengeLevels( baseName );
}

isStrStart( string1, subStr )
{
	return braxi\_challenge_data::isStrStart( string1, subStr );
}

processChallenge( baseName, progressInc )
{
	return braxi\_challenge_progress::processChallenge( baseName, progressInc );
}

tierCheck( tierID )
{
	return braxi\_challenge_progress::tierCheck( tierID );
}

challengeNotify( challengeName, challengeDesc )
{
	return braxi\_challenge_progress::challengeNotify( challengeName, challengeDesc );
}

