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


// ApX: rank progression implementation.

roundUp( floatVal )
{
	if ( int( floatVal ) != floatVal )
		return int( floatVal+1 );
	else
		return int( floatVal );
}

giveRankXP( type, value )
{
	self endon("disconnect");
	if( isDefined( level.efrActive ) && level.efrActive ) return;

	if ( !isDefined( value ) && !braxi\_rank_tables::isRegisteredEvent( type ) ) return;
	if ( !isDefined( value ) )
		value = braxi\_rank_tables::getScoreInfoValue( type );

	if( value < 0 || value > 3000 || getDvar("dedicated") == "listen server" )
		return;

	if( level.freeRun )
		value = int( value *0.5 ); // play deathrun or gtfo and play cj

	self.score += value;
	self.pers["score"] = self.score;

	score = self maps\mp\gametypes\_persistence::statGet( "score" );
	self maps\mp\gametypes\_persistence::statSet( "score", score+value );

	self incRankXP( value );
	self thread braxi\_rank_hud::updateRankScoreHUD( value );
}

getRank()
{	
	rankXp = self.pers["rankxp"];
	rankId = self.pers["rank"];
	
	if ( rankXp < (braxi\_rank_tables::getRankInfoMinXP( rankId ) + braxi\_rank_tables::getRankInfoXPAmt( rankId )) )
		return rankId;
	else
		return self getRankForXp( rankXp );
}

getRankForXp( xpVal )
{
	for( rankId = 0; rankId < level.maxRank; rankId++ )
		if( xpVal < braxi\_rank_tables::getRankInfoMaxXP( rankId ) ) return rankId;
	return level.maxRank;
}

getSPM()
{
	rankLevel = self getRank() + 1;
	return 3 + (rankLevel * 0.5);
}

getPrestigeLevel()
{
	return self.pers["prestige"];
}

getRankXP()
{
	return self.pers["rankxp"];
}

incRankXP( amount )
{	
	xp = self getRankXP();
	newXp = (xp + amount);
	if( newXp < 0 ) newXp = 0;
	
	if( level.dvar["dev"] )
	{
		iprintln( "getRankXP() : " + xp );
		iprintln( "newXp : " + newXp );
	}

	if ( newXp >= braxi\_rank_tables::getRankInfoMaxXP( level.maxRank ) )
		newXp = braxi\_rank_tables::getRankInfoMaxXP( level.maxRank );

	self.pers["rankxp"] = newXp;
	self setStat( 2301, newXp );

	rankId = self getRankForXp( self getRankXP() );
	self updateRank( rankId );

	self braxi\_rank_integrity::updateAntiHackValues();
}

updateRank( rankId )
{
	if( braxi\_rank_tables::getRankInfoMaxXP( self.pers["rank"] ) <= self getRankXP() && self.pers["rank"] < level.maxRank )
	{
		rankId = self getRankForXp( self getRankXP() );
		self setRank( rankId, self.pers["prestige"] );
		self.pers["rank"] = rankId;
		self braxi\_rank_hud::updateRankAnnounceHUD();
		// comming in 1.1
		// ps. already in 1.2 but a bit diferent :D
		//unlockedChallenge = self getRankInfoUnlockChallenge( rankId );
		//if ( isDefined( unlockedChallenge ) && unlockedChallenge != "" )
		//	self braxi\_missions::unlockChallenge( unlockedChallenge );
	}
	updateRankStats( self, rankId );
}

updateRankStats( player, rankId )
{
	player braxi\_prestige::syncProfile();
}

processXpReward( sMeansOfDeath, attacker, victim )
{
	if( attacker.pers["team"] == victim.pers["team"] )
		return;

	kills = attacker maps\mp\gametypes\_persistence::statGet( "kills" );
	attacker maps\mp\gametypes\_persistence::statSet( "kills", kills+1 );

	if( victim.pers["team"] == "allies" )
	{
		kills = attacker maps\mp\gametypes\_persistence::statGet( "KILLED_JUMPERS" );
		attacker maps\mp\gametypes\_persistence::statSet( "KILLED_JUMPERS", kills+1 );
	}	
	else
	{
		kills = attacker maps\mp\gametypes\_persistence::statGet( "KILLED_ACTIVATORS" );
		attacker maps\mp\gametypes\_persistence::statSet( "KILLED_ACTIVATORS", kills+1 );
	}	

	switch( sMeansOfDeath )
	{
		case "MOD_HEAD_SHOT":
			attacker.pers["headshots"]++;
			attacker braxi\_rank::giveRankXP( "headshot" );
			hs = attacker maps\mp\gametypes\_persistence::statGet( "headshots" );
			attacker maps\mp\gametypes\_persistence::statSet( "headshots", hs+1 );
			break;
		case "MOD_MELEE":
			attacker.pers["knifes"]++;
			attacker braxi\_rank::giveRankXP( "melee" );
			knife = attacker maps\mp\gametypes\_persistence::statGet( "MELEE_KILLS" );
			attacker maps\mp\gametypes\_persistence::statSet( "MELEE_KILLS", knife+1 );
			break;
		default:
			pistol = attacker maps\mp\gametypes\_persistence::statGet( "PISTOL_KILLS" );
			attacker maps\mp\gametypes\_persistence::statSet( "PISTOL_KILLS", pistol+1 );
			attacker braxi\_rank::giveRankXP( "kill" );
			break;
	}
}
