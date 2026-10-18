// ApX Deathrun. Based on BraXi's Death Run (c) 2010-2020 Paulina Sokolowska.
// Bounded activator selection: one snapshot, no recursive retries or counter searches.
#include braxi\_common;

getCandidates()
{
	players = getAllPlayers();
	candidates = [];
	for( i = 0; i < players.size; i++ )
	{
		player = players[i];
		if( !isPlayer( player ) || !isDefined( player.pers["team"] ) )
			continue;
		if( level.dvar["dont_pick_spec"] && (player.pers["team"] == "spectator" || !player isReallyAlive()) )
			continue;
		if( !isDefined( player.pers["activator"] ) )
			player.pers["activator"] = 0;
		candidates[candidates.size] = player;
	}
	return candidates;
}

chooseCandidate( candidates, fair )
{
	if( !candidates.size )
		return undefined;
	pool = [];
	minimum = undefined;
	for( i = 0; i < candidates.size; i++ )
	{
		count = candidates[i].pers["activator"];
		if( !fair || !isDefined( minimum ) || count < minimum )
		{
			if( fair ) pool = [];
			minimum = count;
		}
		if( !fair || count == minimum )
			pool[pool.size] = candidates[i];
	}
	if( level.dvar["dont_make_peoples_angry"] && pool.size > 1 )
	{
		alternatives = [];
		for( i = 0; i < pool.size; i++ )
			if( pool[i] getEntityNumber() != getDvarInt( "last_picked_player" ) )
				alternatives[alternatives.size] = pool[i];
		if( alternatives.size ) pool = alternatives;
	}
	return pool[randomInt( pool.size )];
}

pick( fair )
{
	if( game["state"] != "playing" || level.activatorKilled || level.activators )
		return;
	player = chooseCandidate( getCandidates(), fair );
	if( !isDefined( player ) )
		return;
	// Claim the role before callbacks or spawning can start another selection.
	level.activ = player;
	level.activators = 1;
	player.pers["activator"]++;
	setDvar( "last_picked_player", player getEntityNumber() );
	player braxi\_teams::setTeam( "axis" );
	player braxi\_player::spawnPlayer();
	player braxi\_rank::giveRankXP( "activator" );
	level notify( "activator", player );
	bxLogPrint( "A: " + player.name + " ; guid: " + player.guid );
	iPrintlnBold( player.name + " ^7was picked to be ^1Activator" );
}
