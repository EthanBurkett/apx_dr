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

// Responsibility: records. See docs/ARCHITECTURE.md.

fastestTime()
{
	trig = getEntArray( "endmap_trig", "targetname" );
	if( !trig.size || trig.size > 1 )
		return;

	level.mapHasTimeTrigger = true;

	trig = trig[0];
	while( 1 )
	{
		trig waittill( "trigger", user );

		if( !isPlayer( user ) || !user isReallyAlive() || user.pers["team"] == "axis" )
			continue;

		user thread endTimer();
	}
}

endTimer()
{
	if( isDefined( self.finishedMap ) || !isDefined( self.timerStartTime ) || !self isReallyAlive() || game["state"] != "playing" )
		return;

	self.finishedMap = true;

	time = (getTime() - self.timerStartTime) / 1000;

	if( isDefined( self.hud_time ) ) self.hud_time destroy();
	self.hud_time = braxi\_hud::addTextHud( self, 24, -92, 1, "left", "bottom", 1.4 );
	self.hud_time.horzAlign = "left";
    self.hud_time.vertAlign = "bottom";
	self.hud_time.glowAlpha = 0;
	self.hud_time.glowColor = (0.4,0.5,0);

	//self.hud_time reset();
	self.hud_time setText( "TIME  " + time );

	self iPrintlnBold( "You've finished map in ^2" + time + " ^7seconds" );

	if( (!isDefined( level.efrActive ) || !level.efrActive) && time < self.pers["time"] )
		self.pers["time"] = time;
}

playerTimer()
{
	self endon( "disconnect" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );
	self endon( "death" );

	if( !level.mapHasTimeTrigger || isDefined( self.finishedMap ) || self.pers["team"] == "axis" )
		return;

	while( game["state"] != "playing"  )
		wait 0.05;

	//self.hud_time.horzAlign = "fullscreen";
    //self.hud_time.vertAlign = "fullscreen";

	
	self.hud_time = braxi\_hud::addTextHud( self, 24, -92, 1, "left", "bottom", 1.4 );
	self.hud_time.horzAlign = "left";
    self.hud_time.vertAlign = "bottom";
	self.hud_time.glowAlpha = 0;
	self.hud_time.glowColor = (0.4,0.5,0);
	self.hud_time.label = &"TIME  &&1";
	self.hud_time setTenthsTimerUp( 1 );

	self.timerStartTime = getTime();

	//while( !self meleeButtonPressed() )
	//	wait 0.05;
	//self waittill( "finished map" );
}

initScoresStat( num, name )
{
	//level.bestScores[name] = spawnStruct();
	level.bestScores[num]["name"] = name;
	level.bestScores[num]["value"] = 0;
	level.bestScores[num]["player"] = " ";
	level.bestScores[num]["guid"] = "123";
}

bestMapScores()
{
	level.statDvar = ("dr_info_" + level.mapName);
	level.bestScores = [];

	//initScoresStat( "time" );
	initScoresStat( 0, "kills" );
	initScoresStat( 1, "deaths" );
	initScoresStat( 2, "headshots" );
	initScoresStat( 3, "score" );
	initScoresStat( 4, "knifes" );
	initScoresStat( 5, "time" );

	addDvar( "best_scores", level.statDvar, "", "", "", "string" );
	
	data = strTok( level.dvar["best_scores"], ";" );
	if( !data.size ) return;

	for( i = 0; i < data.size; i++ )
	{
		stat = strTok( data[i], "," );
		//if( !stat.size ) continue;
		if( !isDefined( stat[0] ) || !isDefined( stat[1] ) || !isDefined( stat[2] ) || !isDefined( stat[3] ) )
		{
			iprintln( "Error reading " + level.statDvar + " (" + i + "), stat size is " + stat.size );
			continue;
		}
		for( x = 0; x < level.bestScores.size; x++ )
		{
			if( level.bestScores[x]["name"] == stat[0] )
			{
				level.bestScores[x]["value"] = stat[1];
				level.bestScores[x]["guid"] = stat[2];
				level.bestScores[x]["player"] = stat[3];
				//iprintln( "stat " + stat[0] );
			}
		}
	}

	logPrint( "COPY TO CFG: set dr_info_"+level.mapName+" \""+level.dvar["best_scores"]+"\"\n" );
}

appendToDvar( dvar, string )
{
	setDvar( dvar, getDvar( dvar ) + string );
}

saveMapScores()
{
	setDvar( level.statDvar, "" );
	for( i = 0; i < level.bestScores.size; i++ )
	{
		var = ";" + level.bestScores[i]["name"] + "," + level.bestScores[i]["value"];
		var = var + "," + level.bestScores[i]["guid"];
		var = var + "," + level.bestScores[i]["player"];

		appendToDvar( level.statDvar, var );
		level.dvar["best_scores"] = getDvar( level.statDvar );
		//iprintln( var );
	}
	logPrint( "MAP_STATS: set dr_info_"+level.mapName+" \""+level.dvar["best_scores"]+"\"\n" );
}

saveAllScores()
{
	logPrint( "===== BEGIN SCORES =====\n");
	for( i = 0; i < game["playedmaps"].size; i++ )
	{
		logPrint( "set dr_info_" + game["playedmaps"][i] + " \"" + getDvar( "dr_info_"+game["playedmaps"][i] )  + "\"\n" );
	}
	logPrint( "===== END SCORES =====\n");
}

statToString( stat )
{
	name = "unknown";
	switch( stat )
	{
	case "kills":
		name = "Kills";
		break;
	case "deaths":
		name = "Deaths";
		break;
	case "headshots":
		name = "Head Shots";
		break;
	case "score":
		name = "Score";
		break;
	case "knifes":
		name = "Melee Kills";
		break;
	case "time":
		name = "Fastest Time";
		break;
	}
	return name;
}

updateRecord( num, player )
{
	level.bestScores[num]["value"] = player.pers[level.bestScores[num]["name"]];
	level.bestScores[num]["player"] = player.name;
	level.bestScores[num]["guid"] = player getGuid();

	if( level.bestScores[num]["player"] == "" )
		level.bestScores[num]["player"] = " ";

	if( level.bestScores[num]["guid"] == "" )
		level.bestScores[num]["guid"] = "123";
}
