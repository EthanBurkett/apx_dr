// ApX live scoreboard. Menu-owned updates; no permanent HUD or per-player icon slots.
// The engine-owned scoreboard menu opens on +scores and closes on -scores.
#include braxi\_common;

comesBefore( a, b )
{
	aTeam = teamOrder( a );
	bTeam = teamOrder( b );
	if( aTeam != bTeam ) return aTeam < bTeam;
	if( a.score != b.score ) return a.score > b.score;
	return a getEntityNumber() < b getEntityNumber();
}

teamOrder( player )
{
	if( player.pers["team"] == "allies" ) return 0;
	if( player.pers["team"] == "axis" ) return 1;
	return 2;
}

getRows()
{
	players = getAllPlayers();
	rows = [];
	for( i = 0; i < players.size; i++ )
	{
		player = players[i];
		if( !isPlayer( player ) || !isDefined( player.pers["rank"] ) ) continue;
		position = rows.size;
		while( position > 0 && comesBefore( player, rows[position-1] ) )
		{
			rows[position] = rows[position-1];
			position--;
		}
		rows[position] = player;
	}
	return rows;
}

pageCount( count )
{
	if( count <= 0 ) return 1;
	return int( (count + 13) / 14 );
}

menuResponse( response )
{
	if( response == "open" )
	{
		self notify( "apx_scores_stop" );
		self.apxScorePage = 0;
		self.apxScoreCache = [];
		self.apxScoreOpen = true;
		self thread watch();
	}
	else if( response == "close" )
	{
		self.apxScoreOpen = false;
		self notify( "apx_scores_stop" );
	}
	else if( isDefined( self.apxScoreOpen ) && self.apxScoreOpen )
	{
		if( response == "next" ) self.apxScorePage++;
		else if( response == "previous" ) self.apxScorePage--;
		else return;
		self update( getRows() );
	}
}

watch()
{
	self endon( "disconnect" );
	self endon( "apx_scores_stop" );
	level endon( "endround" );
	for(;;)
	{
		self update( getRows() );
		wait 1;
	}
}

update( rows )
{
	pages = pageCount( rows.size );
	self.apxScorePage = braxi\_prestige::clamp( self.apxScorePage, 0, pages-1 );
	summary = rows.size + " PLAYERS";
	if( rows.size == 1 ) summary = "1 PLAYER";
	// ui_mapname belongs to the client's map-selection UI and can be stale.
	self setClientDvars( "apx_sb_page", self.apxScorePage+1, "apx_sb_pages", pages, "apx_sb_count", rows.size,
		"apx_sb_summary", summary, "apx_sb_map", getDvar( "mapname" ) );
	for( row = 0; row < 14; row++ )
	{
		prefix = "apx_sb_" + row + "_";
		index = self.apxScorePage*14 + row;
		if( index >= rows.size )
		{
			if( !isDefined( self.apxScoreCache[row] ) || self.apxScoreCache[row] != "empty" )
				self setClientDvar( prefix + "has", 0 );
			self.apxScoreCache[row] = "empty";
			continue;
		}
		player = rows[index];
		team = "SPECTATOR";
		state = "SPEC";
		if( player.pers["team"] == "allies" ) team = "JUMPER";
		if( player.pers["team"] == "axis" ) team = "ACTIVATOR";
		if( team != "SPECTATOR" )
		{
			state = "OUT";
			if( player.sessionstate == "playing" ) state = "ALIVE";
		}
		signature = player getEntityNumber() + ":" + player.name + ":" + player.pers["rank"] + ":" +
			player.pers["prestige"] + ":" + player.score + ":" + player.kills + ":" + player.deaths + ":" + team + ":" + state;
		if( isDefined( self.apxScoreCache[row] ) && self.apxScoreCache[row] == signature ) continue;
		self.apxScoreCache[row] = signature;
		name = displayName( player.name );
		self setClientDvars( prefix+"has", 1, prefix+"name", name, prefix+"rank", player.pers["rank"],
			prefix+"prestige", player.pers["prestige"], prefix+"score", player.score, prefix+"kills", player.kills,
			prefix+"deaths", player.deaths, prefix+"team", team, prefix+"state", state );
	}
}

displayName( name )
{
	name = removeColorFromString( name );
	if( name.size > 24 ) name = getSubStr( name, 0, 23 ) + ".";
	return name;
}

prime()
{
	self endon( "disconnect" );
	wait 0.2;
	self.apxScorePage = 0;
	self.apxScoreCache = [];
	self update( getRows() );
}
