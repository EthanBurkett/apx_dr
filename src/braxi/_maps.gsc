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
//	In this script you can add following:
//		- blockers that will create invisible walls for players [ spawnCollision( (X,Y,Z), width, height ) ]
//		- arrays of activation triggers for specified maps, used for freerun and detection of trap usage


#include braxi\_common;

// ApX bootstrap and compatibility entry points.

getMapNameString( mapName ) 
{
	tokens = strTok( mapName, "_" );
	if( tokens.size < 2 ) return mapName;
	start = 1;
	if( tokens.size > 2 && (toLower(tokens[1]) == "dr" || toLower(tokens[1]) == "deathrun") ) start = 2;
	name = "";
	for( i = start; i < tokens.size; i++ )
	{
		if( name != "" ) name = name + " ";
		name = name + tokens[i];
	}
	return name;
}

init()
{
	braxi\_map_data::createTimeTrigger();
	if( !isDefined( level.trapTriggers ) )
	{
		level.trapTriggers = braxi\_map_data::findTrapTriggers();
		braxi\_map_data::createCollisions();
	}
	if( level.trapTriggers.size ) level thread braxi\_map_traps::checkTrapUsage();
}

checkTrapUsage()
{
	return braxi\_map_traps::checkTrapUsage();
}

processTrapChallenge()
{
	return braxi\_map_traps::processTrapChallenge();
}

killFreeRunIfActivated()
{
	return braxi\_map_traps::killFreeRunIfActivated();
}

giveXpIfActivated()
{
	return braxi\_map_traps::giveXpIfActivated();
}

