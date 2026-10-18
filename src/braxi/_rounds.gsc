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

// Responsibility: rounds. See docs/ARCHITECTURE.md.

endRound( reasonText, team )
{
	level endon ( "endmap" );

	if( game["state"] == "round ended" || !game["roundStarted"] )
		return;

	game["roundStarted"] = false;
	game["state"] = "round ended";
	level notify( "round_ended", reasonText, team );
	level notify( "endround" );
	level notify( "kill logic" );

	game["state"] = "round ended";
	game["roundsplayed"]++;

	if( isDefined( level.hud_time ) )
		level.hud_time destroy();

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		players[i] setClientDvars( "cg_thirdperson", 1, "r_blur", 2.0, "show_hud", "false" );
	}

	if( team == "jumpers" )
	{
		visionSetNaked( "jumpers", 4 );
	}
	else
	{
		visionSetNaked( "activators", 4 );
		
		if( isDefined( level.activ ) && isPlayer( level.activ ) ) 
			level.activ braxi\_rank::giveRankXp( "activator" );
	}

	if( game["roundsplayed"] >= (level.dvar[ "round_limit" ]+1) )
	{
		level endMap( "Game has ended" );
		return;
	}
	else
	{
		//iPrintlnBold( reasonText );
		level thread braxi\_hud::endRoundAnnoucement( reasonText, (0,1,0) );
		if( level.dvar["roundSound"] )
		{
			song = (1+randomInt(10));
			level thread playSoundOnAllPlayers( "end_round_" + song );	
			hud = braxi\_hud::addTextHud( level, 5, 7, 1, "left", "middle", 1.4 );
			hud setText( "Now playing: ^2" + getDvar( "dr_song_" + song ) );
			//players[i] setClientDvar( "ui_songname", getDvar( "dr_song_" + song ) );
		}
	}

	wait 10;
	map_restart( true );
}

gameLogic()
{
	level endon( "endround" );
	level endon( "kill logic" );
	waittillframeend;

	level.allowSpawn = true;
	warning = false;
	if( plugins\_efr::runWarmup() ) return;

	visionSetNaked( "mpIntro", 0 );
	if( isDefined( level.matchStartText ) )
		level.matchStartText destroyElem();

	wait 0.2;

	level.matchStartText = createServerFontString( "objective", 1.5 );
	level.matchStartText setPoint( "CENTER", "CENTER", 0, -20 );
	level.matchStartText.sort = 1001;
	level.matchStartText setText( level.text["waiting_for_players"] );
	level.matchStartText.foreground = false;
	level.matchStartText.hidewheninmenu = true;

	min = 2;
	if( level.freeRun )
		min = 1;
	if( plugins\_efr::isEnabled() ) min = level.dvar["pi_efr_min"];

	waitForPlayers( min ); // wait for 2 players to start game

	braxi\_hud::roundStartTimer();
	
	if( !canStartRound( min ) )
	{
		thread restartLogic(); // lets start all over again...
		return;
	}

	level notify( "round_started", game["roundsplayed"] );
	level notify( "game started" );
	game["state"] = "playing";
	game["roundStarted"] = true;

	visionSetNaked( level.mapName, 2.0 );
	
	thread roundDelay();

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		if( players[i] isPlaying() )
		{
			players[i] unLink();
			players[i] enableWeapons();
			players[i] thread braxi\_player::antiAFK();
		}
	}

	if( level.freeRun )
	{
		level.hud_time setTimer( level.dvar["freerun_time"] );
		thread freeRunTimer();
		//iPrintlnBold( "^1>> ^2Free Run ^1<<" );

		thread braxi\_hud::drawInformation( 800, 0.8, 1, "FREE RUN" );
		thread braxi\_hud::drawInformation( 800, 0.8, -1, "FREE RUN" );
		return; //no logic in free run
	}
	else
	{
		level thread restrictSpawnAfterTime( level.dvar["spawn_time"] );
		level thread checkTimeLimit();

		level.hud_jumpers fadeOverTime( 2 );
		level.hud_jumpers.alpha = 1;
	}

	startJumpers = undefined;
	while( game["state"] == "playing" )
	{
		wait 0.2;

		level.jumper = [];
		level.jumpers = 0;
		level.activators = 0;
		level.totalPlayers = 0;
		level.totalPlayingPlayers = 0;

		players = getAllPlayers();
		if(players.size > 0)
		{
			for(i = 0; i < players.size; i++)
			{
				level.totalPlayers++;

				if( isDefined( players[i].pers["team"] ) )	
				{
					if( players[i] isReallyAlive() )
						level.totalPlayingPlayers++;

					if(players[i].pers["team"] == "allies" && players[i] isReallyAlive() )
					{
						level.jumpers++;
						level.jumper[level.jumper.size] = players[i];
					}
					if(players[i].pers["team"] == "axis" && players[i] isReallyAlive() )
						level.activators++;
				}
			}		
			
			if( !isDefined( startJumpers ) )
				startJumpers = level.jumpers;

			if( startJumpers >= 3 /*+1 cuz one is acti*/ && level.jumpers == 1 && !level.freeRun )
				level.jumper[0] thread braxi\_events::lastJumper();

			if( level.jumpers > 1 && !level.activators && !level.activatorKilled && !level.freeRun )
			{
				
				if( !level.dvar["pickingsystem"] )
					pickRandomActivator();
				else
					NewPickingSystem();
				continue;
			}

			if( level.activators >= 2 && !warning )
			{
				warning( "level.activators >= 2 - report this to BraXi at www.braxi.cba.pl" );
				warning( "level.activators = " + level.activators );
				warning = true;
			}

			if( !level.jumpers && level.activators )
				thread endRound( "Jumpers died", "activators" );
			else if( !level.freeRun && !level.activators && level.jumpers )
				thread endRound( "Activator died", "jumpers" );
			else if( !level.activators && !level.jumpers )
				thread endRound( "Everyone died", "activators" );
		}
	}
}

roundDelay()
{
	wait 2;
	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		if( players[i] isPlaying() )
		{
			players[i] unLink();
			players[i] enableWeapons();
			players[i] thread braxi\_player::antiAFK();
		}
	}
}

pickRandomActivator()
{
	braxi\_selection::pick( false );
}

checkTimeLimit()
{
	level endon( "endround" );
	level endon( "game over" );

	if( !level.dvar["time_limit"] )
		return;

	time = 60 * level.dvar["time_limit"];	
	level.hud_time setTimer( time );
	wait time;	
	level thread endRound( "Time limit reached", "activators" );
}

endMap( winningteam )
{
	game["state"] = "endmap";
	level notify( "apx_notice" );
	braxi\_presentation::clearNotice();
	level notify( "new emblem" );
	braxi\_playercard::destroyPlayerCard();
	level notify( "intermission" );
	level notify( "game over" );

	setDvar( "g_deadChat", 1 );

	if( isDefined( level.hud_jumpers ) )
		level.hud_jumpers destroy();

	level.hud_round fadeOverTime( 2.6 );
	level.hud_round.alpha = 0;
	wait 3;
	level.hud_round destroy();
	
	//thread saveMapScores();

	level thread playSoundOnAllPlayers( "end_map" );

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		players[i] closeMenu();
		players[i] closeInGameMenu();
		players[i] setClientDvar( "show_hud", "false" );
		players[i] freezeControls( true );
		players[i] braxi\_player::cleanUp();
		players[i] braxi\_lives::destroyLifeIcons();

//		players[i] setClientDvar( "cg_thirdpersonangle", randomInt(360), "cg_thirdpersonrange", 120 );
//		if( players[i].sessionstate != "spectator" )
//			players[i] setClientDvar( "cg_thirdperson", 0 );
//		else
//			players[i] setClientDvar( "cg_thirdperson", 1 );
	}
	wait .05;

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		players[i] braxi\_player::spawnSpectator( level.spawn["spectator"].origin, level.spawn["spectator"].angles );
		players[i] allowSpectateTeam( "allies", false );
		players[i] allowSpectateTeam( "axis", false );
		players[i] allowSpectateTeam( "freelook", false );
		players[i] allowSpectateTeam( "none", true );
	}

	// Records update even when the optional match-report phase is disabled.
	braxi\_intermission::prepareResults();
	if( level.dvar["displayBestPlayers"] )
		braxi\_scoreboard::showBestStats();

	braxi\_records::saveMapScores();
	braxi\_records::saveAllScores();

	wait 0.5;

	braxi\_mapvoting::startMapVote();
	braxi\_credits::main();
	
	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		players[i] braxi\_player::spawnSpectator( level.spawn["spectator"].origin, level.spawn["spectator"].angles );
		players[i].sessionstate = "intermission";
	}
	braxi\_intermission::close();
	
	if( !level.dvar["mapvote"] )
		braxi\_vote_maps::changeMap( braxi\_vote_maps::nextMap() );
	else
		braxi\_mapvoting::changeMap( braxi\_mapvoting::getWinningMap() );
}

freeRunChoice()
{
	self endon( "disconnect" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );
	self endon( "death" );

	if( !level.dvar["freeRunChoice"] || level.trapsDisabled )
		return;

	self.hud_freeround = newClientHudElem( self );
	self.hud_freeround.elemType = "font";
	self.hud_freeround.x = 0;
	self.hud_freeround.y = -124;
	self.hud_freeround.horzAlign = "center";
	self.hud_freeround.vertAlign = "bottom";
	self.hud_freeround.hideWhenInMenu = true;
	self.hud_freeround.alignX = "center";
	self.hud_freeround.alignY = "middle";
	self.hud_freeround.alpha = 1;
	self.hud_freeround.font = "default";
	self.hud_freeround.fontScale = 1.25;
	self.hud_freeround.color = (.88,.77,.53);
	self.hud_freeround.sort = 0;
	self.hud_freeround.foreground = true;
	self.hud_freeround.label = level.text["call_freeround"];

	self.hud_freeround_time = newClientHudElem( self );
	self.hud_freeround_time.elemType = "font";
	self.hud_freeround_time.x = 0;
	self.hud_freeround_time.y = -105;
	self.hud_freeround_time.horzAlign = "center";
	self.hud_freeround_time.vertAlign = "bottom";
	self.hud_freeround_time.hideWhenInMenu = true;
	self.hud_freeround_time.alignX = "center";
	self.hud_freeround_time.alignY = "middle";
	self.hud_freeround_time.alpha = 1;
	self.hud_freeround_time.font = "default";
	self.hud_freeround_time.fontScale = 1.15;
	self.hud_freeround_time.sort = 0;
	self.hud_freeround_time.foreground = true;
	self.hud_freeround_time setTimer( level.dvar["freeRunChoiceTime"] );

	wait 1;
	freeRun = false;
	for( i = 0; i < 10*level.dvar["freeRunChoiceTime"]; i++ ) // time to switch into free run
	{
		if( !level.canCallFreeRun )
		{
			self.hud_freeround destroy();
			self.hud_freeround_time destroy();
			return;
		}
		if( self attackButtonPressed() )
		{
			freeRun = true;
			level endon( "kill_free_run_choice" );
			break;
		}
		wait 0.1;
	}
	level endon( "kill_free_run_choice" );


	if( isDefined( self.hud_freeround ) )
		self.hud_freeround destroy();
	if( isDefined( self.hud_freeround_time ) )
		self.hud_freeround_time destroy();

	if( freeRun )
	{
		thread braxi\_hud::drawInformation( 800, 0.8, 1, "FREE RUN" );
		thread braxi\_hud::drawInformation( 800, 0.8, -1, "FREE RUN" );

		level disableTraps();
			
		players = getAllPlayers();
		for( i = 0; i < players.size; i++ )
		{
			if( players[i] isPlaying() )
			{
				weapon = players[i] braxi\_content_unlocks::selectedKnife();
				players[i] braxi\_equipment::equipWeapons( weapon, false );
				players[i] switchToWeapon( weapon );
			}
		}
		level notify( "round_freerun" );
	}
}

disableTraps()
{
	level.trapsDisabled = true;
	for( i = 0; i < level.trapTriggers.size; i++ )
		if( isDefined( level.trapTriggers[i] ) )
			level.trapTriggers[i].origin = level.trapTriggers[i].origin - (0,0,10000);
	level notify( "traps_disabled" ); //for mappers
}

NewPickingSystem()
{
	braxi\_selection::pick( true );
}
