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

// Bootstrap and stable API for existing maps and plugins.
// Implementation lives in the focused modules documented in docs/ARCHITECTURE.md.

main()
{

	braxi\_dvar::setupDvars(); // all dvars are there
	braxi\_assets::precache();
	braxi\_assets::init_spawns();
	braxi\_cod4stuff::main(); // setup vanilla cod4 variables
	//thread braxi\_bots::addTestClients();

	game["DeathRunVersion"] = 12; //DO NOT MODIFY! PLUGINS MIGHT REQUIRE THIS VERSION OR HIGHER
	level.mapName = toLower( getDvar( "mapname" ) );
	level.jumpers = 0;
	level.activators = 0;
	level.activatorKilled = false;
	level.freeRun = false;
	level.allowSpawn = true;
	level.tempEntity = spawn( "script_model", (0,0,0) ); // entity used to link players
	level.colliders = [];
	level.trapsDisabled = false;
	//level.admins = strTok( level.dvar["admins"], ";" );
	level.canCallFreeRun = true;
	level.color_cool_green = ( 0.8, 2.0, 0.8 );
	level.color_cool_green_glow = ( 0.3, 0.6, 0.3 );
	level.hudYOffset = 10;
	level.firstBlood = false;
	level.lastJumper = false;
	level.mapHasTimeTrigger = false;

	if( !isDefined( game["roundsplayed"] ) )
		game["roundsplayed"] = 1;
	game["roundStarted"] = false;
	game["state"] = "readyup";

	if( game["roundsplayed"] == 1 )
	{
		game["playedmaps"] = strTok( level.dvar["playedmaps"], ";" );
		addMap = true;
		if( game["playedmaps"].size )
		{
			for( i = 0; i < game["playedmaps"].size; i++ )
			{
				if( game["playedmaps"][i] == level.mapName )
				{
					addMap = false;
					break;
				}
			}
		}
		if( addMap )
		{
			braxi\_records::appendToDvar( "dr_playedmaps", level.mapName+";" );
			level.dvar["playedmaps"] = getDvar( "dr_playedmaps" );
			game["playedmaps"] = strTok( level.dvar["playedmaps"], ";" ); //update
		}

		if( level.dvar["freerun"] )
			level.freeRun = true;
	}

	setDvar( "jump_slowdownEnable", 0 );
	setDvar( "bullet_penetrationEnabled", 0 );
	//setDvar( "g_playerCollisionEjectSpeed", 1 );
	setDvar( "mod_author", "BraXi" );
	makeDvarServerInfo( "mod_author", "BraXi" );

	braxi\_assets::buildSprayInfo();
	braxi\_assets::buildCharacterInfo();
	braxi\_assets::buildGloveInfo();
	braxi\_assets::buildItemInfo();
	braxi\_assets::buildKnifeInfo();
	braxi\_assets::buildAbilityInfo();
	braxi\_records::bestMapScores();

	thread maps\mp\gametypes\_hud::init();
	thread maps\mp\gametypes\_hud_message::init();
	thread maps\mp\gametypes\_damagefeedback::init();
	thread maps\mp\gametypes\_clientids::init();
	thread maps\mp\gametypes\_gameobjects::init();
	thread maps\mp\gametypes\_spawnlogic::init();
	thread maps\mp\gametypes\_oldschool::deletePickups();
	thread maps\mp\gametypes\_quickmessages::init();

	thread braxi\_admin::main();
	thread braxi\_menus::init();
	thread braxi\_scoreboard::init();
	thread braxi\_rank::init();
	thread braxi\_mapvoting::init();
	thread braxi\_playercard::init();
	braxi\_maps::init();
	//thread braxi\_credits::neon();
	thread braxi\_missions::init();

	if( level.dvar["usePlugins"] ) plugins\_plugins::main();
	level thread braxi\_rounds::gameLogic();
	level thread braxi\_hud::doHud();
	level thread braxi\_hud::serverMessages();

	level thread braxi\_events::firstBlood();
	level thread braxi\_records::fastestTime();


	visionSetNaked( level.mapName, 0 );

}

precache()
{
	return braxi\_assets::precache();
}

init_spawns()
{
	return braxi\_assets::init_spawns();
}

buildSprayInfo()
{
	return braxi\_assets::buildSprayInfo();
}

buildAbilityInfo()
{
	return braxi\_assets::buildAbilityInfo();
}

buildCharacterInfo()
{
	return braxi\_assets::buildCharacterInfo();
}

buildItemInfo()
{
	return braxi\_assets::buildItemInfo();
}

playerConnect()
{
	return braxi\_player::playerConnect();
}

playerDisconnect()
{
	return braxi\_player::playerDisconnect();
}

PlayerLastStand( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	return braxi\_combat::PlayerLastStand( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
}

PlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	return braxi\_combat::PlayerDamage( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, psOffsetTime );
}

PlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration )
{
	return braxi\_combat::PlayerKilled( eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration );
}

spawnPlayer( origin, angles )
{
	return braxi\_player::spawnPlayer( origin, angles );
}

afterFirstFrame()
{
	return braxi\_player::afterFirstFrame();
}

watchDog()
{
	return braxi\_equipment::watchDog();
}

makeMeDog()
{
	return braxi\_equipment::makeMeDog();
}

makeMeHuman()
{
	return braxi\_equipment::makeMeHuman();
}

test()
{
	return braxi\_experimental::test();
}

makeMeNotSolid()
{
	return braxi\_experimental::makeMeNotSolid();
}

bunnyHoop()
{
	return braxi\_movement::bunnyHoop();
}

advancedJumping()
{
	return braxi\_movement::advancedJumping();
}

isAngleOk( angles, min, max )
{
	return braxi\_movement::isAngleOk( angles, min, max );
}

sprayLogo()
{
	return braxi\_equipment::sprayLogo();
}

endRound( reasonText, team )
{
	return braxi\_rounds::endRound( reasonText, team );
}

addTextHud( who, x, y, alpha, alignX, alignY, fontScale )
{
	return braxi\_hud::addTextHud( who, x, y, alpha, alignX, alignY, fontScale );
}

endRoundAnnoucement( text, color )
{
	return braxi\_hud::endRoundAnnoucement( text, color );
}

spawnSpectator( origin, angles )
{
	return braxi\_player::spawnSpectator( origin, angles );
}

cleanUp()
{
	return braxi\_player::cleanUp();
}

gameLogic()
{
	return braxi\_rounds::gameLogic();
}

roundDelay()
{
	return braxi\_rounds::roundDelay();
}

pickRandomActivator()
{
	return braxi\_rounds::pickRandomActivator();
}

checkTimeLimit()
{
	return braxi\_rounds::checkTimeLimit();
}

endMap( winningteam )
{
	return braxi\_rounds::endMap( winningteam );
}

respawn()
{
	return braxi\_player::respawn();
}

antiAFK()
{
	return braxi\_player::antiAFK();
}

kickAfterTime( time )
{
	return braxi\_player::kickAfterTime( time );
}

roundStartTimer()
{
	return braxi\_hud::roundStartTimer();
}

doHud()
{
	return braxi\_hud::doHud();
}

updateHealthBar()
{
	return braxi\_hud::updateHealthBar();
}

freeRunChoice()
{
	return braxi\_rounds::freeRunChoice();
}

disableTraps()
{
	return braxi\_rounds::disableTraps();
}

serverMessages()
{
	return braxi\_hud::serverMessages();
}

isWallKnifing( attacker, victim )
{
	return braxi\_combat::isWallKnifing( attacker, victim );
}

NewPickingSystem()
{
	return braxi\_rounds::NewPickingSystem();
}

new_ending_hud( align, fade_in_time, x_off, y_off )
{
	return braxi\_hud::new_ending_hud( align, fade_in_time, x_off, y_off );
}

drawInformation( start_offset, movetime, mult, text )
{
	return braxi\_hud::drawInformation( start_offset, movetime, mult, text );
}

SetupLives()
{
	return braxi\_lives::SetupLives();
}

giveLife()
{
	return braxi\_lives::giveLife();
}

showLifeIcon()
{
	return braxi\_lives::showLifeIcon();
}

useLife()
{
	return braxi\_lives::useLife();
}

addLifeIcon( num, x, y, offset, sort )
{
	return braxi\_lives::addLifeIcon( num, x, y, offset, sort );
}

destroyLifeIcons()
{
	return braxi\_lives::destroyLifeIcons();
}

gib_splat()
{
	return braxi\_combat::gib_splat();
}

fastestTime()
{
	return braxi\_records::fastestTime();
}

endTimer()
{
	return braxi\_records::endTimer();
}

playerTimer()
{
	return braxi\_records::playerTimer();
}

initScoresStat( num, name )
{
	return braxi\_records::initScoresStat( num, name );
}

bestMapScores()
{
	return braxi\_records::bestMapScores();
}

appendToDvar( dvar, string )
{
	return braxi\_records::appendToDvar( dvar, string );
}

saveMapScores()
{
	return braxi\_records::saveMapScores();
}

saveAllScores()
{
	return braxi\_records::saveAllScores();
}

statToString( stat )
{
	return braxi\_records::statToString( stat );
}

updateRecord( num, player )
{
	return braxi\_records::updateRecord( num, player );
}

firstBlood()
{
	return braxi\_events::firstBlood();
}

lastJumper()
{
	return braxi\_events::lastJumper();
}

watchItems()
{
	return braxi\_equipment::watchItems();
}

cleanUpInsertion()
{
	return braxi\_equipment::cleanUpInsertion();
}

showAbility()
{
	return braxi\_hud::showAbility();
}

