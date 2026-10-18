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

// ApX: challenge events implementation.

onEndRound()
{
	level waittill( "round_ended", reasonText, winningTeam );

	players = getAllPlayers();
	for( i = 0; i < players.size; i++ )
	{
		if( !players[i] isReallyAlive() )
			continue;

		players[i] braxi\_challenge_progress::processChallenge( "ch_rounds1" );
	}

	if( !level.freeRun && level.ch_machines >= 6 && isDefined( level.activ ) && level.activ isReallyAlive() )
		level.activ braxi\_challenge_progress::processChallenge( "ch_machines" );
}

onEndMap()
{
	level waittill( "intermission" );
	
	player = getBestPlayerFromScore( "score" );
	if( isDefined( player ) && player.pers["score"] )
	{
		player braxi\_challenge_progress::processChallenge( "ch_risingstar" );
		player braxi\_challenge_progress::processChallenge( "ch_ontop", 1 );
	}
}

playerConnected()
{
	while( 1 )
	{
		level waittill( "connected", player );
		player thread onPlayerDisconnect();		
		player.ch_kills = 0;
		
		// hack
		player braxi\_challenge_data::updateChallenges();
		player thread braxi\_challenge_progress::unlockChallenge( "tier_1" );
		player braxi\_challenge_data::updateChallenges();

	}
}

onPlayerDisconnect()
{
	self waittill( "disconnect" );
	//some stuff here
}

test()
{
	while( self.sessionstate == "playing" )
	{
		while( !self useButtonPressed() )
			wait 0.5;

		
		self braxi\_challenge_progress::processChallenge( "ch_ontop", 1 );
		wait 1;
	}
}

playerSpawned()
{
	while( 1 )
	{
		level waittill( "player_spawn", player );
		player thread ch_spray();
		//player thread test();
	}
}

playerDamaged()
{
	while( 1 )
	{
		level waittill( "player_damage", who, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon );
	}
}

playerKilled()
{
	while( 1 )
	{
		level waittill( "player_killed", who, eInflictor, attacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, psOffsetTime, deathAnimDuration ) ;

		if( !level.freeRun )
			who braxi\_challenge_progress::processChallenge( "ch_failzor", 1 );

		level.ch_machines += 1;

		if( isPlayer( attacker ) )
		{
			if( attacker == who || !isPlayer( attacker ) )
				return;

			
			if( attacker.pers["team"] == "axis" )
			{
				level.ch_machines = -999;
				level.ch_ownage++;
				
				if( level.ch_ownage == 3 )
					attacker braxi\_challenge_progress::processChallenge( "ch_ownage" );
			}
			else
			{
				if( isDefined( attacker.usedLife ) && who.pers["team"] == "axis" )
					attacker braxi\_challenge_progress::processChallenge( "ch_back" );
			}

			if( sHitLoc == "head" && sMeansOfDeath != "MOD_MELEE" )
			{
				sMeansOfDeath = "MOD_HEAD_SHOT";
				attacker braxi\_challenge_progress::processChallenge( "ch_headshot" );
			}
				

			if( !attacker isOnGround() && !who isOnGround() )
				attacker braxi\_challenge_progress::processChallenge( "ch_airkill" );


			if( sMeansOfDeath == "MOD_HEAD_SHOT" )
			{
				switch( sWeapon )
				{
					case "beretta_mp":
					case "colt_mp":
					case "usp_mp":
						w = strTok( sWeapon, "_" )[0];
						attacker braxi\_challenge_progress::processChallenge( "ch_" + w + "head" + 1 );
						break;						
				}
			}

			switch( sWeapon )
			{
				case "beretta_mp":
				case "colt_mp":
				case "usp_mp":
					w = strTok( sWeapon, "_" )[0];
					//for( i = 1; i < 4; i++ )
					//	attacker processChallenge( "ch_beretta"+i );

					attacker braxi\_challenge_progress::processChallenge( "ch_" + w + "1" );
					break;
				/*case "deserteagle_mp":
					attacker processChallenge( "ch_deserteagle1" );
					break;
				case "m40a3_mp":
					attacker processChallenge( "ch_m40a31" );
					break;	
				case "deserteaglegold_mp":
					attacker processChallenge( "ch_deserteaglegold1" );
					break;	
				case "remington700_mp":
					attacker processChallenge( "ch_remington7001" );
					break;	
				case "colt44_mp":
					attacker processChallenge( "ch_colt441" );
					break;*/		
						
				case "knife_mp":
				case "hands_mp":
				case "tomahawk_mp":
					attacker braxi\_challenge_progress::processChallenge( "ch_knifemaster1" );
					break;					
			}
			
		}
		else
		{
			
		}
	}
}

ch_spray()
{
	self endon( "disconnect" );
	self endon( "death" );

	wait 0.2;
	while( self.sessionstate == "playing" )
	{
		self waittill( "spray", sprayNum, sprayPos );

		ents = getEntArray( "dr_deadbody", "targetname" );
		for( i = 0; i < ents.size; i++ )
		{
			if( /*ents[i].model == "body_mp_usmc_cqb" &&*/ distance( ents[i].origin, sprayPos ) < 64 )
			{
				self braxi\_challenge_progress::processChallenge( "ch_spray" );
				break;
			}
		}
	}
}
