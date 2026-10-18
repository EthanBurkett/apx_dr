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

// Responsibility: assets. See docs/ARCHITECTURE.md.

precache()
{
	level.text = [];
	level.fx = [];

	precacheModel( "german_sheperd_dog" );
	precacheModel( "viewmodel_hands_zombie" );
	precacheModel( "tag_origin" );
	//precacheModel( "com_teddy_bear" );
	precacheModel( "body_mp_usmc_cqb" );
	precacheModel( "body_alice" );
	//precacheModel( "body_mp_sas_urban_sniper" );
	precacheModel( "mil_frame_charge" /*"aftermath_power_stationthing3"*/ );

	precacheItem( "colt45_mp" );
	precacheItem( "tomahawk_mp" );
	precacheItem( "claymore_mp" );
	precacheItem( "knife_mp" );
	precacheItem( "dog_mp" );

	precacheMenu( "clientcmd" );
	
	precacheShader( "black" );
	precacheShader( "white" );
	precacheShader( "killiconsuicide" );
	precacheShader( "killiconmelee" );
	precacheShader( "killiconheadshot" );
	precacheShader( "killiconfalling" );
	precacheShader( "stance_stand" );
	precacheShader( "hudstopwatch" );
	precacheShader( "score_icon" );

	precacheStatusIcon( "hud_status_connecting" );
	precacheStatusIcon( "hud_status_dead" );
	precacheHeadIcon( "headicon_admin" );
	
	level.text["round_begins_in"] = &"BRAXI_ROUND_BEGINS_IN";
	level.text["waiting_for_players"] = &"BRAXI_WAITING_FOR_PLAYERS";
	//level.text["spectators_count"] = &"BRAXI_SPECTATING1";
	level.text["jumpers_count"] = &"BRAXI_ALIVE_JUMPERS";
	level.text["call_freeround"] = &"BRAXI_CALL_FREEROUND";

	precacheString( level.text["round_begins_in"] );
	precacheString( level.text["waiting_for_players"] );
	//precacheString( level.text["spectators_count"] );
	precacheString( level.text["jumpers_count"] );
	precacheString( level.text["call_freeround"] );
	precacheString( &"Your Time: ^2&&1" );
	precacheString( &"TIME  &&1" );
	precacheString( &"JUMPERS &&1" );

	level.fx["falling_teddys"] = loadFx( "deathrun/falling_teddys" );
	level.fx["gib_splat"] = loadFx( "deathrun/gib_splat" );
	level.fx["light_blink"] = loadFx( "misc/light_c4_blink" );
}

init_spawns()
{
	level.spawn = [];
	level.spawn["allies"] = getEntArray( "mp_jumper_spawn", "classname" );
	level.spawn["axis"] = getEntArray( "mp_activator_spawn", "classname" );
	if( !level.spawn["allies"].size ) level.spawn["allies"] = getEntArray( "mp_dm_spawn", "classname" );
	if( !level.spawn["axis"].size ) level.spawn["axis"] = getEntArray( "mp_tdm_spawn", "classname" );
	intermissions = getEntArray( "mp_global_intermission", "classname" );
	if( intermissions.size ) level.spawn["spectator"] = intermissions[0];
	else if( level.spawn["allies"].size ) level.spawn["spectator"] = level.spawn["allies"][0];
	else if( level.spawn["axis"].size ) level.spawn["spectator"] = level.spawn["axis"][0];
	else
	{
		println( "ApX Deathrun: map has no spawn points; using a safe placeholder spawn." );
		level.spawn["spectator"] = spawn( "script_origin", (0,0,128) );
		level.spawn["spectator"].angles = (0,0,0);
	}
	if( !level.spawn["allies"].size ) level.spawn["allies"][0] = level.spawn["spectator"];
	if( !level.spawn["axis"].size ) level.spawn["axis"][0] = level.spawn["allies"][0];
	for( i = 0; i < level.spawn["allies"].size; i++ ) level.spawn["allies"][i] placeSpawnPoint();
	for( i = 0; i < level.spawn["axis"].size; i++ ) level.spawn["axis"][i] placeSpawnPoint();
}

buildSprayInfo()
{
	level.sprayInfo = [];
	level.numSprays = 0;
	
	tableName = "mp/sprayTable.csv";

	for( idx = 1; isdefined( tableLookup( tableName, 0, idx, 0 ) ) && tableLookup( tableName, 0, idx, 0 ) != ""; idx++ )
	{
		id = int( tableLookup( tableName, 0, idx, 1 ) );
		level.sprayInfo[id]["rank"] = (int(tableLookup( tableName, 0, idx, 2 )) - 1);
		level.sprayInfo[id]["shader"] = tableLookup( tableName, 0, idx, 3 );
		level.sprayInfo[id]["effect"] = loadFx( tableLookup( tableName, 0, idx, 4 ) );
		
		precacheShader( level.sprayInfo[id]["shader"] );
		level.numSprays++;
	}
}

buildAbilityInfo()
{
	level.abilityInfo = [];
	level.numAbilities = 0;
	
	tableName = "mp/abilityTable.csv";

	for( idx = 1; isdefined( tableLookup( tableName, 0, idx, 0 ) ) && tableLookup( tableName, 0, idx, 0 ) != ""; idx++ )
	{
		id = int( tableLookup( tableName, 0, idx, 1 ) );
		level.abilityInfo[id]["stat"] = int(tableLookup( tableName, 0, idx, 2 ));
		level.abilityInfo[id]["codeName"] = tableLookup( tableName, 0, idx, 3 );
		level.abilityInfo[id]["shader"] = tableLookup( tableName, 0, idx, 4 );
		level.abilityInfo[id]["name"] =  tableLookup( tableName, 0, idx, 5 );
		level.abilityInfo[id]["desc"] = tableLookup( tableName, 0, idx, 6 );
		
//		precacheString( level.abilityInfo[id]["desc"]  );		
		precacheShader( level.abilityInfo[id]["shader"] );
		level.numAbilities++;
	}
}

buildGloveInfo()
{
	level.gloveInfo = [];
	level.numGloves = 0;
	table = "mp/gloveTable.csv";
	for( row = 1; tableLookup( table, 0, row, 0 ) != ""; row++ )
	{
		id = int( tableLookup( table, 0, row, 1 ) );
		level.gloveInfo[id]["model"] = tableLookup( table, 0, row, 2 );
		level.gloveInfo[id]["enabled"] = tableLookup( "mp/apx_catalog.csv", 0, "gloves:"+id, 3 ) != "";
		level.numGloves++;
	}
}

buildCharacterInfo()
{
	level.characterInfo = [];
	level.numCharacters = 0;
	
	tableName = "mp/characterTable.csv";

	for( idx = 1; isdefined( tableLookup( tableName, 0, idx, 0 ) ) && tableLookup( tableName, 0, idx, 0 ) != ""; idx++ )
	{
		id = int( tableLookup( tableName, 0, idx, 1 ) );
		level.characterInfo[id]["rank"] = (int(tableLookup( tableName, 0, idx, 2 )) - 1);
		level.characterInfo[id]["shader"] = tableLookup( tableName, 0, idx, 3 );
		level.characterInfo[id]["model"] = tableLookup( tableName, 0, idx, 4 );
		level.characterInfo[id]["handsModel"] = tableLookup( tableName, 0, idx, 5 );
		level.characterInfo[id]["name"] = tableLookup( tableName, 0, idx, 6 );
		level.characterInfo[id]["desc"] = tableLookup( tableName, 0, idx, 7 );
		level.characterInfo[id]["enabled"] = tableLookup( "mp/apx_catalog.csv", 0, "character:"+id, 3 ) != "";
		level.characterInfo[id]["prestige"] = braxi\_content_unlocks::prestige( "character", id );
		
		if( level.characterInfo[id]["enabled"] )
		{
			precacheShader( level.characterInfo[id]["shader"] );
			precacheModel( level.characterInfo[id]["model"] );
			precacheModel( level.characterInfo[id]["handsModel"] );
		}
		level.numCharacters++;
	}
}

buildItemInfo()
{
	level.itemInfo = [];
	level.numItems = 0;
	
	tableName = "mp/itemTable.csv";

	for( idx = 1; isdefined( tableLookup( tableName, 0, idx, 0 ) ) && tableLookup( tableName, 0, idx, 0 ) != ""; idx++ )
	{
		id = int( tableLookup( tableName, 0, idx, 1 ) );
		level.itemInfo[id]["rank"] = (int(tableLookup( tableName, 0, idx, 2 )) - 1);
		level.itemInfo[id]["shader"] = tableLookup( tableName, 0, idx, 3 );
		level.itemInfo[id]["item"] = (tableLookup( tableName, 0, idx, 4 ) + "_mp");
		level.itemInfo[id]["name"] = tableLookup( tableName, 0, idx, 5 );
		level.itemInfo[id]["desc"] = tableLookup( tableName, 0, idx, 6 );
		level.itemInfo[id]["prestige"] = braxi\_content_unlocks::prestige( "weapon", id );
		// The generated catalog is the shared allow-list for browsing and equip.
		// Legacy itemTable rows contain empty trailing columns in native CSV data.
		level.itemInfo[id]["enabled"] = tableLookup( "mp/apx_catalog.csv", 0, "weapon:"+id, 3 ) != "";
		
		if( level.itemInfo[id]["enabled"] )
		{
			precacheShader( level.itemInfo[id]["shader"] );
			precacheItem( level.itemInfo[id]["item"] );
		}
		//precacheString( level.itemInfo[id]["name"] );
		//precacheString( level.itemInfo[id].desc );
		level.numItems++;
	}
}

buildKnifeInfo()
{
	level.knifeInfo = [];
	level.numKnives = 0;
	tableName = "mp/knifeTable.csv";
	for( row = 1; tableLookup( tableName, 0, row, 0 ) != ""; row++ )
	{
		id = int( tableLookup( tableName, 0, row, 1 ) );
		level.knifeInfo[id]["rank"] = int( tableLookup( tableName, 0, row, 2 ) )-1;
		level.knifeInfo[id]["shader"] = tableLookup( tableName, 0, row, 3 );
		level.knifeInfo[id]["item"] = tableLookup( tableName, 0, row, 4 )+"_mp";
		level.knifeInfo[id]["name"] = tableLookup( tableName, 0, row, 5 );
		level.knifeInfo[id]["prestige"] = int( tableLookup( tableName, 0, row, 7 ) );
		level.knifeInfo[id]["enabled"] = tableLookup( tableName, 0, row, 8 ) != "0";
		if( level.knifeInfo[id]["enabled"] )
		{
			precacheItem( level.knifeInfo[id]["item"] );
			precacheShader( level.knifeInfo[id]["shader"] );
		}
		level.numKnives++;
	}
}
