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


// ApX bootstrap and compatibility entry points.

init()
{
	level.scoreInfo = [];
	level.rankTable = [];

	precacheShader("white");

	precacheString( &"RANK_PLAYER_WAS_PROMOTED_N" );
	precacheString( &"RANK_PLAYER_WAS_PROMOTED" );
	precacheString( &"RANK_PROMOTED" );
	precacheString( &"MP_PLUS" );
	precacheString( &"BRAXI_CHARACTER_NEW" );
	precacheString( &"BRAXI_SPRAY_NEW" );

	// score info
	/*registerScoreInfo( "kill", 50 );
	registerScoreInfo( "headshot", 100 );
	registerScoreInfo( "melee", 75 );
	registerScoreInfo( "activator", 25 );
	registerScoreInfo( "trap_activation", 5 );
	registerScoreInfo( "jumper_died", 10 );*/

	braxi\_rank_tables::registerScoreInfo( "kill", 100 );
	braxi\_rank_tables::registerScoreInfo( "headshot", 200 );
	braxi\_rank_tables::registerScoreInfo( "melee", 150 );
	braxi\_rank_tables::registerScoreInfo( "activator", 50 );
	braxi\_rank_tables::registerScoreInfo( "trap_activation", 10 );
	braxi\_rank_tables::registerScoreInfo( "jumper_died", 20 );

	braxi\_rank_tables::registerScoreInfo( "win", 20 );
	braxi\_rank_tables::registerScoreInfo( "loss", 10 );
	braxi\_rank_tables::registerScoreInfo( "tie", 25 );

	level.maxRank = int(tableLookup( "mp/rankTable.csv", 0, "maxrank", 1 ));
	level.maxPrestige = int(tableLookup( "mp/rankIconTable.csv", 0, "maxprestige", 1 ));
	
	for( rId = 0; rId <= level.maxRank; rId++ )
		precacheShader( braxi\_rank_tables::getRankInfoIcon( rId, 0 ) );
	for( pId = 1; pId <= level.maxPrestige; pId++ )
	{
		shader = braxi\_prestige::getIcon( pId );
		assertex( shader != "", "ApX prestige icon missing for ID " + pId + " / max " + level.maxPrestige );
		precacheShader( shader );
	}

	rankId = 0;
	rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
	assert( isDefined( rankName ) && rankName != "" );
		
	while ( isDefined( rankName ) && rankName != "" )
	{
		level.rankTable[rankId][1] = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );
		level.rankTable[rankId][2] = tableLookup( "mp/ranktable.csv", 0, rankId, 2 );
		level.rankTable[rankId][3] = tableLookup( "mp/ranktable.csv", 0, rankId, 3 );
		level.rankTable[rankId][7] = tableLookup( "mp/ranktable.csv", 0, rankId, 7 );

		precacheString( tableLookupIString( "mp/ranktable.csv", 0, rankId, 16 ) );

		rankId++;
		rankName = tableLookup( "mp/ranktable.csv", 0, rankId, 1 );		
	}

	level thread braxi\_rank_players::onPlayerConnect();
}

antiHack()
{
	return braxi\_rank_integrity::antiHack();
}

updateAntiHackValues()
{
	return braxi\_rank_integrity::updateAntiHackValues();
}

setStatFromStat( stat2, stat1 )
{
	return braxi\_rank_integrity::setStatFromStat( stat2, stat1 );
}

verifyStat( stat, antiHackStat, what )
{
	return braxi\_rank_integrity::verifyStat( stat, antiHackStat, what );
}

verifyStatValue( stat, expectedValue, what )
{
	return braxi\_rank_integrity::verifyStatValue( stat, expectedValue, what );
}

punishHacker( player, what )
{
	return braxi\_rank_integrity::punishHacker( player, what );
}

resetEverything()
{
	return braxi\_rank_integrity::resetEverything();
}

isRegisteredEvent( type )
{
	return braxi\_rank_tables::isRegisteredEvent( type );
}

registerScoreInfo( type, value )
{
	return braxi\_rank_tables::registerScoreInfo( type, value );
}

getScoreInfoValue( type )
{
	return braxi\_rank_tables::getScoreInfoValue( type );
}

getScoreInfoLabel( type )
{
	return braxi\_rank_tables::getScoreInfoLabel( type );
}

getRankInfoMinXP( rankId )
{
	return braxi\_rank_tables::getRankInfoMinXP( rankId );
}

getRankInfoXPAmt( rankId )
{
	return braxi\_rank_tables::getRankInfoXPAmt( rankId );
}

getRankInfoMaxXp( rankId )
{
	return braxi\_rank_tables::getRankInfoMaxXp( rankId );
}

getRankInfoFull( rankId )
{
	return braxi\_rank_tables::getRankInfoFull( rankId );
}

getRankInfoIcon( rankId, prestigeId )
{
	return braxi\_rank_tables::getRankInfoIcon( rankId, prestigeId );
}

getRankInfoUnlockWeapon( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockWeapon( rankId );
}

getRankInfoUnlockPerk( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockPerk( rankId );
}

getRankInfoUnlockChallenge( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockChallenge( rankId );
}

getRankInfoUnlockFeature( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockFeature( rankId );
}

getRankInfoUnlockCamo( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockCamo( rankId );
}

getRankInfoUnlockAttachment( rankId )
{
	return braxi\_rank_tables::getRankInfoUnlockAttachment( rankId );
}

getRankInfoLevel( rankId )
{
	return braxi\_rank_tables::getRankInfoLevel( rankId );
}

onPlayerConnect()
{
	return braxi\_rank_players::onPlayerConnect();
}

onJoinedTeam()
{
	return braxi\_rank_players::onJoinedTeam();
}

onJoinedSpectators()
{
	return braxi\_rank_players::onJoinedSpectators();
}

onPlayerSpawned()
{
	return braxi\_rank_players::onPlayerSpawned();
}

roundUp( floatVal )
{
	return braxi\_rank_progression::roundUp( floatVal );
}

giveRankXP( type, value )
{
	return braxi\_rank_progression::giveRankXP( type, value );
}

updateRankScoreHUD( amount )
{
	return braxi\_rank_hud::updateRankScoreHUD( amount );
}

removeRankHUD()
{
	return braxi\_rank_hud::removeRankHUD();
}

getRank()
{
	return braxi\_rank_progression::getRank();
}

getRankForXp( xpVal )
{
	return braxi\_rank_progression::getRankForXp( xpVal );
}

getSPM()
{
	return braxi\_rank_progression::getSPM();
}

getPrestigeLevel()
{
	return braxi\_rank_progression::getPrestigeLevel();
}

getRankXP()
{
	return braxi\_rank_progression::getRankXP();
}

incRankXP( amount )
{
	return braxi\_rank_progression::incRankXP( amount );
}

updateRank( rankId )
{
	return braxi\_rank_progression::updateRank( rankId );
}

updateRankStats( player, rankId )
{
	return braxi\_rank_progression::updateRankStats( player, rankId );
}

updateRankAnnounceHUD()
{
	return braxi\_rank_hud::updateRankAnnounceHUD();
}

processXpReward( sMeansOfDeath, attacker, victim )
{
	return braxi\_rank_progression::processXpReward( sMeansOfDeath, attacker, victim );
}

unlockSpray()
{
	return braxi\_unlocks::unlockSpray();
}

isSprayUnlocked( num )
{
	return braxi\_unlocks::isSprayUnlocked( num );
}

unlockCharacter()
{
	return braxi\_unlocks::unlockCharacter();
}

isCharacterUnlocked( num )
{
	return braxi\_unlocks::isCharacterUnlocked( num );
}

unlockItem()
{
	return braxi\_unlocks::unlockItem();
}

isItemUnlocked( num )
{
	return braxi\_unlocks::isItemUnlocked( num );
}

isAbilityUnlocked( num )
{
	return braxi\_unlocks::isAbilityUnlocked( num );
}

unlockAbility( name )
{
	return braxi\_unlocks::unlockAbility( name );
}

destroyUnlockMessage()
{
	return braxi\_rank_hud::destroyUnlockMessage();
}

initUnlockMessage()
{
	return braxi\_rank_hud::initUnlockMessage();
}

unlockMessage( notifyData )
{
	return braxi\_rank_hud::unlockMessage( notifyData );
}

showUnlockMessage( notifyData )
{
	return braxi\_rank_hud::showUnlockMessage( notifyData );
}

