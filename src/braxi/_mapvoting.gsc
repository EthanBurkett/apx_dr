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

// ApX bootstrap and compatibility entry points.

init() 
{
	level.mapvote = 0;

	precacheString( &"MAPVOTE_PRESSFIRE" );
	precacheString( &"MAPVOTE_WAIT4VOTES" );
}

startMapvote() 
{
	if( !level.dvar["mapvote"] )
		return;

	level notify("pre_mapvote");
	mapList = braxi\_vote_maps::retrieveMaps(1); //these are all maps available for mapvoting
	level.maps = braxi\_vote_maps::getRandomSelection(mapList, 5, getdvar("mapname")); //size can be 0!
	//level.maps[level.maps.size] = addMapItem(getdvar("mapname"), "Replay this map");
	if( !level.maps.size )
	{
		println( "ApX: no alternate maps available for voting; retaining the current map." );
		return;
	}
	level.mapvote = 1;
	level notify("mapvote");
	level.mapitems = 3;
	if( level.maps.size <= level.mapitems ) level.mapitems = level.maps.size - 1;
	beginVoting( level.dvar["mapvote_time"] ); //BraX
	level notify("post_mapvote");
	wait 1;
	braxi\_vote_hud::delVisuals();
}

changeMap( map )
{
	return braxi\_vote_maps::changeMap( map );
}

retrieveMaps( useMaprotation )
{
	return braxi\_vote_maps::retrieveMaps( useMaprotation );
}

getRandomSelection( mapList, no, illegal )
{
	return braxi\_vote_maps::getRandomSelection( mapList, no, illegal );
}

isLegal( name, illegal )
{
	return braxi\_vote_maps::isLegal( name, illegal );
}

getMaprotation()
{
	return braxi\_vote_maps::getMaprotation();
}

addMapItem( mapname, gametype )
{
	return braxi\_vote_maps::addMapItem( mapname, gametype );
}

beginVoting(time) {
	level.alphaintensity = .5;
	level.voteswitchtime = .5;
	level.voteavg = int((level.mapitems+1)/2);
	level.votesup = level.mapitems - level.voteavg;
	
	braxi\_vote_hud::createVisuals();
	level.votingplayers = getAllPlayers();
	//level.maps[0].votes = level.votingplayers.size;
	for (i=0; i<level.votingplayers.size; i++) {
		level.votingplayers[i] thread braxi\_vote_players::playerVote();
	}
	
//	level thread neon(int(time/5)-1); //BraX
	level thread braxi\_vote_hud::updateWinningMap();
	
	wait time;
}

playerVote()
{
	return braxi\_vote_players::playerVote();
}

playerUpdateVotes()
{
	return braxi\_vote_players::playerUpdateVotes();
}

playerStartVoting()
{
	return braxi\_vote_players::playerStartVoting();
}

playerVisuals()
{
	return braxi\_vote_hud::playerVisuals();
}

playerDelVisuals()
{
	return braxi\_vote_hud::playerDelVisuals();
}

getIndex( i )
{
	return braxi\_vote_hud::getIndex( i );
}

updateVotes()
{
	return braxi\_vote_hud::updateVotes();
}

incVote()
{
	return braxi\_vote_players::incVote();
}

decVote()
{
	return braxi\_vote_players::decVote();
}

changeVotes( index, dif )
{
	return braxi\_vote_players::changeVotes( index, dif );
}

nextIndex()
{
	return braxi\_vote_hud::nextIndex();
}

prevIndex()
{
	return braxi\_vote_hud::prevIndex();
}

scaleFont( new,time )
{
	return braxi\_vote_hud::scaleFont( new,time );
}

getFontSize( i )
{
	return braxi\_vote_hud::getFontSize( i );
}

getAlpha( i )
{
	return braxi\_vote_hud::getAlpha( i );
}

getX( i )
{
	return braxi\_vote_hud::getX( i );
}

getY( i )
{
	return braxi\_vote_hud::getY( i );
}

createVisuals()
{
	return braxi\_vote_hud::createVisuals();
}

delVisuals()
{
	return braxi\_vote_hud::delVisuals();
}

updateWinningMap()
{
	return braxi\_vote_hud::updateWinningMap();
}

getWinningMap()
{
	return braxi\_vote_maps::getWinningMap();
}

