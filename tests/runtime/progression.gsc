// Only packaged into tools/test-progression.ps1's isolated fixture, never the release.
run()
{
	wait 1;
	bot = addTestClient();
	check( isDefined( bot ), "create test client" );
	for( i = 0; i < 100 && !isDefined( bot.pers["prestige"] ); i++ ) wait 0.05;
	check( isDefined( bot.pers["prestige"] ), "test client profile initialized" );
	wait 0.2;
	cap = braxi\_rank_tables::getRankInfoMaxXP( level.maxRank );
	check( level.maxRank == 69 && level.maxPrestige == 5, "table caps" );
	for( rank = 0; rank <= 69; rank++ )
		check( braxi\_rank_progression::getRankForXp( braxi\_rank_tables::getRankInfoMinXP( rank ) ) == rank, "rank threshold " + rank );
	bot setStat( 2303, 321 );
	bot setStat( 2302, 9876 );
	bot setStat( 3200, 1 );
	bot setStat( 3000, 7 );
	for( prestige = 0; prestige < level.maxPrestige; prestige++ )
	{
		bot.pers["prestige"] = prestige;
		bot.pers["rankxp"] = cap;
		bot braxi\_prestige::syncProfile();
		check( bot getStat( 252 ) == 69, "level 70 saved" );
		check( bot braxi\_prestige::request(), "request " + prestige );
		check( bot braxi\_prestige::enter(), "enter " + prestige );
		check( bot getStat( 2326 ) == prestige+1, "prestige saved " + prestige );
		check( bot getStat( 252 ) == 0 && bot getStat( 2301 ) == 0, "rank/XP reset" );
		check( bot getStat( 2303 ) == 321 && bot getStat( 2302 ) == 9876, "lifetime counters retained" );
		check( bot getStat( 3200 ) == 1 && bot getStat( 3000 ) == 7, "ability/challenge retained" );
		check( !bot braxi\_prestige::enter(), "duplicate response rejected" );
	}
	bot.pers["rankxp"] = cap;
	bot braxi\_prestige::syncProfile();
	check( !bot braxi\_prestige::request(), "prestige beyond cap rejected" );
	// Exercise both icon material lookups and the real server menu-data sender.
	for( prestige = 1; prestige <= level.maxPrestige; prestige++ )
		check( braxi\_prestige::getIcon( prestige ) != "", "prestige icon " + prestige );
	bot.apxScorePage = 0;
	bot.apxScoreCache = [];
	bot braxi\_scoreboard_panel::update( braxi\_scoreboard_panel::getRows() );
	rows = [];
	for( i = 0; i < 64; i++ ) rows[i] = bot;
	bot.apxScorePage = 4;
	bot braxi\_scoreboard_panel::update( rows );
	check( bot.apxScorePage == 4, "64-player pagination" );
	bot.apxScorePage = 99;
	bot braxi\_scoreboard_panel::update( braxi\_scoreboard_panel::getRows() );
	check( bot.apxScorePage == 0 && bot.apxScoreCache[13] == "empty", "page shrink clears stale rows" );
	testAdminCommands( bot );
	println( "APX_PROGRESSION_RUNTIME_PASS: 70 levels, 5 prestige transitions, retained stats, duplicate/cap guards, scoreboard sender, admin progression commands" );
}

testAdminCommands( bot )
{
	bot.pers["rankxp"] = 0;
	bot.pers["prestige"] = level.maxPrestige-1;
	bot braxi\_prestige::syncProfile();
	bot setStat( 501, 255 );
	bot setStat( 2501, 99 );
	bot setStat( 3201, 1 );
	bot setStat( level.dvar["warns_stat"], 2 );
	bot setStat( 988, 1 );
	args = strTok( "xp:" + bot getEntityNumber() + ":500", ":" );
	bot braxi\_admin_progression::handle( args, "number" );
	check( bot getStat( 2301 ) == 0, "non-admin progression command rejected" );
	bot.pers["admin"] = true;
	bot.pers["permissions"] = "x";
	bot braxi\_admin_progression::handle( args, "number" );
	check( bot getStat( 2301 ) == 0, "admin without progression permission rejected" );
	bot.pers["permissions"] = "p";
	bot braxi\_admin_progression::handle( args, "number" );
	check( bot getStat( 2301 ) == 500, "progression permission accepted" );
	bot.pers["admin"] = false;
	bot.pers["permissions"] = "x";
	bot.pers["rankxp"] = 0;
	bot braxi\_prestige::syncProfile();
	// Exercise the exact server-dvar route used by RCON, not just the setter.
	sendAdmin( bot, "xp", 4000 );
	check( bot getStat( 2301 ) == 4000, "admin XP ignores free-run scaling and player life state" );
	check( bot getStat( 2302 ) == 9876 && bot getStat( 2303 ) == 321, "admin XP preserves lifetime score" );
	sendAdmin( bot, "setrank", 70 );
	check( bot getStat( 252 ) == 69 && bot braxi\_prestige::canEnter(), "admin level 70 ready for prestige" );
	sendAdmin( bot, "setprestige", 5 );
	check( bot getStat( 2326 ) == 5 && bot getStat( 252 ) == 69, "admin prestige preserves rank" );
	sendAdmin( bot, "setrank", 71 );
	check( bot getStat( 252 ) == 69, "invalid admin rank rejected" );
	sendAdmin( bot, "reset", undefined );
	check( bot getStat( 2301 ) == 0 && bot getStat( 252 ) == 0 && bot getStat( 2326 ) == 0, "admin full progression reset" );
	check( bot getStat( 2302 ) == 0 && bot getStat( 2303 ) == 0 && bot getStat( 3201 ) == 0, "admin reset clears lifetime and abilities" );
	check( bot getStat( 501 ) == 1 && bot getStat( 2501 ) == 0 && bot.challengeData["ch_risingstar"] == 1, "admin reset restores fresh challenges" );
	check( bot getStat( level.dvar["antiHackStat"] ) == 0 && bot getStat( level.dvar["antiHackStat"]+2 ) == 0, "admin reset refreshes integrity mirrors" );
	check( bot getStat( level.dvar["warns_stat"] ) == 2 && bot getStat( 988 ) == 1, "admin reset retains moderation and camera preference" );
	check( bot.score == 0 && bot.kills == 0 && bot.pers["lifes"] == 0, "admin reset clears live match caches" );
	bot braxi\_rank_integrity::antiHack();
	check( bot getStat( 2326 ) == 0, "reset profile passes native integrity verification" );
}

sendAdmin( bot, command, value )
{
	text = command + ":" + bot getEntityNumber();
	if( isDefined( value ) ) text = text + ":" + value;
	setDvar( "admin", text );
	for( attempt = 0; attempt < 30 && getDvar( "admin" ) != ""; attempt++ ) wait 0.05;
	check( getDvar( "admin" ) == "", "server consumed admin command " + command );
}

check( condition, message )
{
	assertex( condition, "APX_PROGRESSION_RUNTIME_FAIL: " + message );
}
