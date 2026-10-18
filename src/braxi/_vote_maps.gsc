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

/*********** MAPVOTING ***********

	Name: DMS
	Author: Bipo
	Design: Mr-X
	Desc: Dynamic Mapvoting Script
	Date: Feb. 2011
	
All rights reserved � iNext Gaming
**********************************/


#include braxi\_common;

// ApX: vote maps implementation.

changeMap( map ) 
{
	if( !isDefined( map ) ) map = addMapItem( getDvar( "mapname" ), "deathrun" ); 	
	//setDvar("sv_maprotationcurrent", "gametype "+map.gametype+ " map "+map.mapname);
	setDvar( "sv_maprotationcurrent", "gametype deathrun map " + map.mapname ); //BraX
	exitLevel(false);
}

retrieveMaps(useMaprotation) { //returns an array with spawnstructs containg map_name, visual name and gametype
	if (useMaprotation) {
		return getMaprotation();
	}
	return [];

}

getRandomSelection(mapList, no, illegal) {
	legal = [];
	if( !isDefined( mapList ) || no <= 0 ) return legal;
	for( i = 0; i < mapList.size; i++ )
		if( !isDefined( illegal ) || isLegal( mapList[i].mapname, illegal ) )
			legal[legal.size] = mapList[i];
	selected = [];
	remaining = legal.size;
	for( i = 0; i < no && remaining > 0; i++ )
	{
		index = randomInt( remaining );
		selected[selected.size] = legal[index];
		remaining--;
		legal[index] = legal[remaining];
	}
	return selected;
}

isLegal(name, illegal) { //check if map is specified in illegal list or string
	if (!isString(illegal)) {
		for (i=0; i<illegal.size; i++) {
			if (illegal[i].mapname == name)
			return false;
		}
	}
	else if (name == illegal)
	return false;
	
	return true;
}

getMaprotation()
{
	rotation = [];
	seen = [];
	tokens = strTok( getDvar( "sv_mapRotation" ), " " );
	for( i = 0; i + 1 < tokens.size; i++ )
	{
		if( toLower(tokens[i]) != "map" ) continue;
		name = toLower(tokens[i + 1]);
		i++;
		if( getSubStr(name,0,3) != "mp_" || isDefined( seen[name] ) ) continue;
		seen[name] = true;
		rotation[rotation.size] = addMapItem( name, "deathrun" );
	}
	return rotation;
}

addMapItem(mapname, gametype) {
	map = spawnstruct();
	if (mapname=="")
	return;
	if (!isdefined(gametype))
	gametype = getdvar("g_gametype");
	if (gametype=="")
	gametype = getdvar("g_gametype");
	
	map.mapname = mapname;
	map.visname = braxi\_maps::getMapNameString(mapname);
	
	map.gametype = gametype;
	map.votes = 0;
	return map;
}

getWinningMap() {
	if( !isDefined( level.maps ) || !level.maps.size )
		return addMapItem( getDvar( "mapname" ), "deathrun" );
	mostvotes = level.maps[0].votes;
	lastindex = 0;
	for (i=1; i<level.maps.size; i++) {
		if (level.maps[i].votes > mostvotes) {
			mostvotes = level.maps[i].votes;
		lastindex = i;
		}
	}
	return level.maps[lastindex];
}
