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

// Responsibility: player. See docs/ARCHITECTURE.md.

playerConnect()
{

	self thread cleanUp();
	self.guid = self getGuid();
	self.number = self getEntityNumber();
	self.statusicon = "hud_status_connecting";
	self.died = false;
	self.doingNotify = false; //for hud logic

	if( !isDefined( self.name ) )
		self.name = "undefined name";
	if( !isDefined( self.guid ) )
		self.guid = "undefined guid";
	
	self braxi\_profile::sanitizeCustomization();
	self braxi\_preferences::load();
	self braxi\_menu_service::load();
	self setClientDvar( "drui_character", (self getStat( 980 )) );
	self setClientDvar( "drui_spray", (self getStat( 979 )) );
	self setClientDvar( "drui_weapon", (self getStat( 981 )) );
	
	//self thread doHud();
	self thread braxi\_hud::updateHealthBar();

	// we want to show hud and we get an IP adress for "add to favourities" menu
	self setClientDvars( "show_hud", "true", "ip", getDvar("net_ip"), "port", getDvar("net_port") );
	if( !isDefined( self.pers["team"] ) )
	{
		if( level.dvar["show_guids"] )
			iPrintln( self.name + " ^2[" + getSubStr( self.guid, 24, 32 ) + "^2] ^7entered the game" );
		else
			iPrintln( self.name + " ^7entered the game" );

		self.sessionstate = "spectator";
		self.team = "spectator";
		self.pers["team"] = "spectator";

		self.pers["score"] = 0;
		self.pers["kills"] = 0;
		self.pers["deaths"] = 0;
		self.pers["assists"] = 0;
		self.pers["lifes"] = 0;
		self.pers["headshots"] = 0;
		self.pers["knifes"] = 0;
		self.pers["activator"] = 0;
		self.pers["time"] = 99999999;
		self.pers["isDog"] = false;

		self.pers["ability"] = "specialty_null";
	}
	else
	{
		self.score = self.pers["score"];
		self.kills = self.pers["kills"];
		self.assists = self.pers["assists"];
		self.deaths = self.pers["deaths"];
	}

	level notify( "connected", self );
	self thread braxi\_lives::SetupLives();
	
	self thread modBanned();

	if(!isDefined(level.spawn["spectator"]))
		level.spawn["spectator"] = level.spawn["allies"][0];
		
	if( game["state"] == "endmap" )
	{
		self spawnSpectator( level.spawn["spectator"].origin, level.spawn["spectator"].angles );
		self.sessionstate = "intermission";
		return;
	}

	if( isDefined( self.pers["weapon"] ) && self.pers["team"] != "spectator" )
	{
		self.pers["weapon"] = "colt_mp";
		self braxi\_teams::setTeam( "allies" ); //just keep in case... i saw player in new round that shouldnt be opfor but was (v0.3)
		spawnPlayer();
		return;
	}
	else
	{
		self spawnSpectator( level.spawn["spectator"].origin, level.spawn["spectator"].angles );
		self thread delayedMenu();
		//bxLogPrint( ("J: " + self.name + " ; guid: " + self.guid) );
		logPrint("J;" + self.guid + ";" + self.number + ";" + self.name + "\n");
	}

	self setClientDvars( "cg_drawSpectatorMessages", 1, "ui_hud_hardcore", 1, "player_sprintTime", 4, "ui_uav_client", 0, "g_scriptMainMenu", game["menu_team"] );
}

playerDisconnect()
{
	level notify( "disconnected", self );
	self thread cleanUp();
	self thread braxi\_lives::destroyLifeIcons();

	if( !isDefined( self.name ) )
		self.name = "no name";

	if( level.dvar["show_guids"] )
		iPrintln( self.name + " ^2[" + getSubStr( self getGuid(), 24, 32 ) + "^2] ^7left the game" );
	else
		iPrintln( self.name + " ^7left the game" );

	logPrint("Q;" + self getGuid() + ";" + self getEntityNumber() + ";" + self.name + "\n");
}

spawnPlayer( origin, angles )
{
	// A queued practice respawn can outlive a switch to spectators.
	if( self.pers["team"] != "allies" && self.pers["team"] != "axis" ) return;
//	self endon( "disconnect" );
	if( game["state"] == "endmap" ) 
		return;

	level notify( "jumper", self );
	self cleanUp();
	self.finishedMap = undefined;
	resettimeout();

	self.team = self.pers["team"];
	self.sessionteam = self.team;
	self.sessionstate = "playing";
	self.spectatorclient = -1;
	self.killcamentity = -1;
	self.archivetime = 0;
	self.psoffsettime = 0;
	self.statusicon = "";

	self braxi\_profile::sanitizeCustomization();
	self braxi\_teams::setPlayerModel();

	if( isDefined( origin ) && isDefined( angles ) )
		self spawn( origin,angles );
	else
	{
		spawnPoint = level.spawn[self.pers["team"]][randomInt(level.spawn[self.pers["team"]].size)];
		self spawn( spawnPoint.origin, spawnPoint.angles );
	}

	self SetActionSlot( 1, "nightvision" );
	self braxi\_equipment::spawnEquipment();

	self braxi\_teams::setHealth();
	self braxi\_hud_damage::reset();
	self braxi\_teams::setSpeed();
	self thread afterFirstFrame();

	if( self braxi\_admin::hasPermission( "b" ) )
		self.headicon = "headicon_admin";

	self notify( "spawned_player" );
	level notify( "player_spawn", self );

	//self thread test();
}

afterFirstFrame()
{
	self endon( "disconnect" );
    self endon( "joined_spectators" );
    self endon( "death" );
	waittillframeend;
	wait 0.1;

	if( !self isPlaying() )
		return;

	if( game["state"] == "readyup" )
	{
		self linkTo( level.tempEntity );
		self disableWeapons();
	}
	else
	{
		self thread antiAFK();
	}

	if( self.pers["team"] == "allies" )
	{
	}
	else
	{
		self thread braxi\_rounds::freeRunChoice();
	}
	
	if( self getStat( 988 ) == 1 )
		self setClientDvar( "cg_thirdperson", 1 );


	// give special ability
	self clearPerks();
	self.pers["ability"] = level.abilityInfo[self getStat(982)]["codeName"];
	if( self.pers["ability"] != "specialty_null" && self.pers["ability"] != "" )
	{
		self setPerk( self.pers["ability"] );
		self thread braxi\_hud::showAbility();

		if( self.pers["ability"] == "specialty_armorvest"  )
		{
			self.maxhealth = self.health + int( self.health/10 );
			self.health = self.maxhealth;
		}
	}


	//self thread makeMeNotSolid();
	self thread braxi\_equipment::watchItems();
	self thread braxi\_records::playerTimer();
	self thread braxi\_equipment::sprayLogo();
	self thread braxi\_movement::bunnyHoop();
	self thread braxi\_equipment::watchDog();
	//self thread advancedJumping();
}

spawnSpectator( origin, angles )
{
	if( !isDefined( origin ) )
		origin = (0,0,0);
	if( !isDefined( angles ) )
		angles = (0,0,0);

	self notify( "joined_spectators" );

	self thread cleanUp();
	resettimeout();
	self.sessionstate = "spectator";
	self.spectatorclient = -1;
	self.statusicon = "";
	self spawn( origin, angles );
	self braxi\_teams::setSpectatePermissions();

	level notify( "player_spectator", self );
}

cleanUp()
{
	self clearLowerMessage();
	self notify( "kill afk monitor" );
	self setClientDvars( "cg_thirdperson", 0, "cg_thirdpersonrange", 80, "r_blur", 0, "ui_healthbar", 1, "bg_viewKickMax", 90, "bg_viewKickMin", 5, "bg_viewKickRandom", 0.4, "bg_viewKickScale", 0.2 );
	self unLink();

	self.bh = 0; 
	self.doingBH = false;
	self enableWeapons();

	if( isDefined( self.hud_freeround ) )		self.hud_freeround destroy();
	if( isDefined( self.hud_freeround_time ) )	self.hud_freeround_time destroy();
	if( isDefined( self.hud_time ) )			self.hud_time destroy();
}

respawn()
{
	self endon( "disconnect" );
	level endon( "endround" );
	level endon( "intermission" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );

	if( level.freeRun || !game["roundStarted"] )
	{
		wait 0.1;
		self spawnPlayer();
		return;
	}

	if( self canSpawn() && self.pers["team"] == "allies" )
	{
		wait 0.5;

		if( game["state"] != "playing" )
			return;
		self setLowerMessage( &"PLATFORM_PRESS_TO_SPAWN" );
	
		while( !self useButtonPressed() )
			wait .05;

		if( game["state"] != "playing" )
			return;

		self thread braxi\_lives::useLife();
	}
}

antiAFK()
{
	self endon( "disconnect" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );
	self endon( "kill afk monitor" );

	if( !level.dvar["afk"] || self.pers["team"] == "axis" )
		return;

	time = 0;
	oldOrigin = self.origin - (0,0,50);
	while( isAlive( self ) )
	{
		wait 0.2;
		if( distance(oldOrigin, self.origin) <= 10 )
			time++;
		else
			time = 0;

		if( time == (level.dvar["afk_warn"]*5) )
		{
			if( level.dvar["afk_method"] )
				self iPrintlnBold( "You will be kicked from server due to AFK if you don't move" );
			else
				self iPrintlnBold( "Move or you will be killed due to AFK" );
		}

		if( time == (level.dvar["afk_time"]*5) )
		{
			if( level.dvar["afk_method"] )
			{
				iPrintln( self.name + " was kicked from server due to AFK." );
				self clientCmd( "disconnect" );
				//kick( self getEntityNumber() );
				self thread kickAfterTime( 2 );
			}
			else
			{
				iPrintln( self.name + " was killed due to AFK." );
				self suicide();
			}
			break;
		}
		oldOrigin = self.origin;
	}
}

kickAfterTime( time )
{
	self endon( "disconnect" );
	wait time;

	if( isDefined( self ) )
		kick( self getEntityNumber() );
}
