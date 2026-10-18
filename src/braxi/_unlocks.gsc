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


// ApX: unlocks implementation.

unlockSpray()
{
	for( i = 0; i < level.sprayInfo.size /*level.numSprays+1*/; i++ )
	{
		if( self.pers["rank"] == level.sprayInfo[i]["rank"] )
		{
			notifyData = spawnStruct();
			notifyData.title = "New Spray!";
			notifyData.description = level.sprayInfo[i]["name"];
			notifyData.icon = level.sprayInfo[i]["shader"];
			notifyData.duration = 2.9;
			self thread braxi\_rank_hud::unlockMessage( notifyData );
			break;
		}
	}

}

isSprayUnlocked( num )
{
	if( num >= level.sprayInfo.size /*level.numSprays*/ || num <= -1)
		return false;
	if( self.pers["rank"] >= level.sprayInfo[num]["rank"] )
		return true;
	return false;
}

unlockCharacter()
{
	for( i = 0; i < level.characterInfo.size /*level.numCharacters+1*/; i++ )
	{
		if( !level.characterInfo[i]["enabled"] ) continue;
		if( self.pers["rank"] == level.characterInfo[i]["rank"] &&
			self.pers["prestige"] == level.characterInfo[i]["prestige"] )
		{
			notifyData = spawnStruct();
			notifyData.title = "New Character!";
			notifyData.description = level.characterInfo[i]["name"];
			notifyData.icon = level.characterInfo[i]["shader"];
			notifyData.duration = 2.9;
			self thread braxi\_rank_hud::unlockMessage( notifyData );
			break;
		}
	}

}

isCharacterUnlocked( num )
{
	if( num >= level.characterInfo.size || num <= -1)
		return false;
	if( !level.characterInfo[num]["enabled"] ) return false;
	if( self braxi\_content_unlocks::meets( level.characterInfo[num]["prestige"], level.characterInfo[num]["rank"] ) )
		return true;
	return false;
}

unlockItem()
{
	for( i = 0; i < level.itemInfo.size /*level.numItems+1*/; i++ )
	{
		if( self.pers["rank"] == level.itemInfo[i]["rank"] &&
			self.pers["prestige"] == level.itemInfo[i]["prestige"] && level.itemInfo[i]["enabled"] )
		{
		notifyData = spawnStruct();
		notifyData.title = "New Weapon!";
		notifyData.description = level.itemInfo[i]["name"];
		notifyData.icon = level.itemInfo[i]["shader"];
		notifyData.duration = 2.9;
		self thread braxi\_rank_hud::unlockMessage( notifyData );
			break;
		}
	}
}

isItemUnlocked( num )
{
	if( num >= level.numItems || num <= -1)
		return false;
	if( isDefined( level.itemInfo[num]["enabled"] ) && !level.itemInfo[num]["enabled"] ) return false;
	if( self braxi\_content_unlocks::meets( level.itemInfo[num]["prestige"], level.itemInfo[num]["rank"] ) )
		return true;
	return false;
}

isAbilityUnlocked( num )
{
	if( num >= level.numAbilities || num <= -1)
		return false;

	if( self getStat( level.abilityInfo[num]["stat"] ) == 1 )
		return true;

	return false;
}

unlockAbility( name )
{
	for( i = 0; i < level.abilityInfo.size; i++ )
	{
		if( level.abilityInfo[i]["codeName"] == name )
		{
			notifyData = spawnStruct();
			notifyData.title = "New Ability!";
			notifyData.description = level.abilityInfo[i]["name"];
			notifyData.icon = level.abilityInfo[i]["shader"];
			notifyData.duration = 2.9;
	
			self thread braxi\_rank_hud::unlockMessage( notifyData );
			break;
		}
	}
}
