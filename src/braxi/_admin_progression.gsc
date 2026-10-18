// Trusted server/RCON progression controls, separate from gameplay XP rewards.
#include braxi\_common;

handle( args, pickingType )
{
	if( !isDefined( args[0] ) ) return false;
	command = toLower( args[0] );
	if( command != "xp" && command != "reset" && command != "setrank" && command != "setprestige" ) return false;
	// A player-context caller must be an authenticated progression administrator.
	// The server/RCON dvar consumer runs in level context.
	if( isPlayer( self ) && (!isDefined( self.pers["admin"] ) || !self.pers["admin"] ||
		!self braxi\_admin_auth::hasPermission( "p" )) )
	{
		self iPrintlnBold( "No permission to change progression." );
		return true;
	}
	if( !isDefined( args[1] ) || args.size > 3 || (command == "reset" && args.size > 2) )
	{
		usage();
		return true;
	}
	player = getTarget( args[1], pickingType );
	if( !isDefined( player ) )
	{
		println( "[ApX admin] Player not found or name is ambiguous. Use status and a client number." );
		return true;
	}
	if( !isDefined( player.pers["rankxp"] ) || !isDefined( player.pers["rank"] ) || !isDefined( player.pers["prestige"] ) )
	{
		println( "[ApX admin] Player profile is still loading. Try again shortly." );
		return true;
	}
	value = 0;
	if( command == "xp" )
	{
		value = 4000; // Preserve the original command's advertised default.
		if( isDefined( args[2] ) ) value = parseInteger( args[2], 1, braxi\_rank_tables::getRankInfoMaxXP( level.maxRank ) );
	}
	else if( command == "setrank" ) value = parseInteger( args[2], 1, level.maxRank+1 );
	else if( command == "setprestige" ) value = parseInteger( args[2], 0, level.maxPrestige );
	if( value < 0 )
	{
		player iPrintlnBold( "Invalid progression value. Level: 1-70; prestige: 0-" + level.maxPrestige + "; XP: 1-994000." );
		usage();
		return true;
	}
	player apply( command, value );
	return true;
}

parseInteger( text, minimum, maximum )
{
	if( !isDefined( text ) ) return -1;
	text = "" + text;
	if( text.size == 0 || text.size > 7 ) return -1;
	value = 0;
	for( i = 0; i < text.size; i++ )
	{
		if( !isSubStr( "0123456789", text[i] ) ) return -1;
		value = value*10 + int( text[i] );
	}
	if( value < minimum || value > maximum ) return -1;
	return value;
}

getTarget( target, pickingType )
{
	if( pickingType == "number" )
	{
		number = parseInteger( target, 0, 63 );
		if( number < 0 ) return undefined;
		return braxi\_admin_commands::getPlayerByNum( number );
	}
	if( pickingType != "nickname" ) return undefined;
	needle = toLower( removeColorFromString( target ) );
	if( needle == "" ) return undefined;
	players = getAllPlayers();
	matches = 0;
	exactMatches = 0;
	match = undefined;
	exact = undefined;
	for( i = 0; i < players.size; i++ )
	{
		name = toLower( removeColorFromString( players[i].name ) );
		if( name == needle )
		{
			exactMatches++;
			exact = players[i];
		}
		if( isSubStr( name, needle ) )
		{
			matches++;
			match = players[i];
		}
	}
	if( exactMatches == 1 ) return exact;
	if( exactMatches == 0 && matches == 1 ) return match;
	return undefined;
}

apply( command, value )
{
	before = self.pers["rankxp"];
	previousRank = self.pers["rank"];
	self.prestigeConfirmationUntil = undefined;
	if( command == "xp" )
		self.pers["rankxp"] = braxi\_prestige::clamp( before+value, 0, braxi\_rank_tables::getRankInfoMaxXP( level.maxRank ) );
	else if( command == "setrank" )
	{
		self.pers["rankxp"] = braxi\_rank_tables::getRankInfoMinXP( value-1 );
		// Maximum level is ready for a real menu-driven prestige test.
		if( value == level.maxRank+1 ) self.pers["rankxp"] = braxi\_rank_tables::getRankInfoMaxXP( level.maxRank );
	}
	else if( command == "setprestige" ) self.pers["prestige"] = value;
	else if( command == "reset" ) self resetProfile();
	self braxi\_prestige::syncProfile();
	self braxi\_profile::sanitizeCustomization();
	self braxi\_rank_integrity::updateAntiHackValues();
	self showFeedback( command, previousRank, self.pers["rankxp"]-before );
	message = "Level " + (self.pers["rank"]+1) + " / 70 | Prestige " + self.pers["prestige"] + " / " + level.maxPrestige + " | XP " + self.pers["rankxp"];
	if( command == "xp" ) message = "+" + (self.pers["rankxp"]-before) + " XP | " + message;
	if( command == "reset" ) message = "Full progression profile reset. " + message;
	self iPrintlnBold( message );
	println( "[ApX admin] " + command + " -> " + self.name + ": " + message );
	logPrint( "ADMIN_PROGRESSION;" + command + ";" + self getEntityNumber() + ";" + self getGuid() + ";" + value + ";" + self.pers["rankxp"] + ";" + self.pers["prestige"] + "\n" );
}

showFeedback( command, previousRank, gainedXp )
{
	if( self.sessionstate != "playing" ) return;
	if( (command == "xp" || command == "setrank") && self.pers["rank"] > previousRank )
		self thread braxi\_rank_hud::updateRankAnnounceHUD();
	if( command == "xp" && gainedXp > 0 && isDefined( self.hud_rankscroreupdate ) )
		self thread braxi\_rank_hud::updateRankScoreHUD( gainedXp );
}

resetProfile()
{
	// Clear only stats owned by this mod's progression tables.
	for( stat = 2300; stat <= 2357; stat++ )
		if( tableLookup( "mp/playerStatsTable.csv", 0, ""+stat, 1 ) != "" ) self setStat( stat, 0 );
	challenges = getArrayKeys( level.challengeInfo );
	for( i = 0; i < challenges.size; i++ )
	{
		info = level.challengeInfo[challenges[i]];
		self setStat( info["stateid"], 0 );
		self setStat( info["statid"], 0 );
	}
	for( tier = 1; tier <= level.numChallengeTiers; tier++ ) self setStat( 269+tier, 0 );
	for( stat = 3200; stat < 3208; stat++ ) self setStat( stat, 0 );
	for( stat = 979; stat < 983; stat++ ) self setStat( stat, 0 );
	self setStat( 2405, 0 );
	self setStat( 2406, 0 );
	self.pers["rankxp"] = 0;
	self.pers["rank"] = 0;
	self.pers["prestige"] = 0;
	self.challengeData = [];
	self.ch_kills = 0;
	self notify( "update_score" );
	self.rankUpdateTotal = 0;
	if( isDefined( self.hud_rankscroreupdate ) ) self.hud_rankscroreupdate.alpha = 0;
	// Restore the same initial challenge availability as a fresh connection.
	self braxi\_challenge_progress::unlockChallenge( "tier_1" );
	self braxi\_challenge_data::updateChallenges();
	fields = strTok( "score;kills;deaths;assists;headshots;knifes;activator;participation;lifes", ";" );
	for( i = 0; i < fields.size; i++ ) self.pers[fields[i]] = 0;
	self.score = 0;
	self.kills = 0;
	self.deaths = 0;
	self.assists = 0;
	self.pers["time"] = 99999999;
	self.usedLife = undefined;
	if( isDefined( self.hud_lifes ) )
		for( i = 0; i < self.hud_lifes.size; i++ )
			if( isDefined( self.hud_lifes[i] ) ) self.hud_lifes[i].alpha = 0;
	// Remove the currently equipped earned perk without respawning mid-round.
	if( isDefined( self.pers["ability"] ) && self.pers["ability"] != "specialty_null" && self.pers["ability"] != "" )
	{
		self unsetPerk( self.pers["ability"] );
		if( self.pers["ability"] == "specialty_armorvest" && isDefined( self.maxhealth ) )
		{
			self.maxhealth = self.maxhealth - int( self.maxhealth/11 );
			if( self.health > self.maxhealth ) self.health = self.maxhealth;
		}
	}
	self.pers["ability"] = "specialty_null";
	self notify( "show ability" );
	if( isDefined( self.abilityHud ) ) self.abilityHud destroy();
	self.abilityHud = undefined;
}

usage()
{
	println( "[ApX admin] set admin \"xp:<clientnum>[:amount]\" | \"setrank:<clientnum>:1-70\" | \"setprestige:<clientnum>:0-" + level.maxPrestige + "\" | \"reset:<clientnum>\"" );
	println( "[ApX admin] Use set adm with a unique player name instead of a client number. Reset erases lifetime progress." );
}
