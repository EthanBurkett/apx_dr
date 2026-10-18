// ApX progression: rank IDs are 0..69; displayed levels are 1..70.
// Prestige resets only level/XP. Lifetime counters, challenges and abilities survive.

clamp( value, minimum, maximum )
{
	if( value < minimum ) return minimum;
	if( value > maximum ) return maximum;
	return value;
}

getIcon( prestige )
{
	prestige = int( clamp( prestige, 0, level.maxPrestige ) );
	return tableLookup( "mp/apx_prestiges.csv", 0, "" + prestige, 1 );
}

syncProfile()
{
	xp = clamp( self.pers["rankxp"], 0, braxi\_rank_tables::getRankInfoMaxXP( level.maxRank ) );
	prestige = clamp( self.pers["prestige"], 0, level.maxPrestige );
	rank = braxi\_rank_progression::getRankForXp( xp );
	self.pers["rankxp"] = xp;
	self.pers["rank"] = rank;
	self.pers["prestige"] = prestige;
	self.cur_rankNum = rank;
	self setRank( rank, prestige );
	// Write the existing profile IDs directly, including on non-pure LAN servers.
	self setStat( 2301, xp );
	self setStat( 2326, prestige );
	self setStat( 2350, rank );
	self setStat( 251, rank );
	self setStat( 252, rank );
	self setStat( 2351, braxi\_rank_tables::getRankInfoMinXP( rank ) );
	self setStat( 2352, braxi\_rank_tables::getRankInfoMaxXP( rank ) );
	self updateMenu();
}

canEnter()
{
	if( !isDefined( self.pers["rank"] ) || !isDefined( self.pers["prestige"] ) ) return false;
	return self.pers["prestige"] < level.maxPrestige && self.pers["rank"] == level.maxRank &&
		self.pers["rankxp"] >= braxi\_rank_tables::getRankInfoMaxXP( level.maxRank );
}

updateMenu()
{
	next = self.pers["prestige"] + 1;
	if( next > level.maxPrestige ) next = level.maxPrestige;
	self setClientDvars( "apx_prestige_ready", self canEnter(), "apx_prestige", self.pers["prestige"],
		"apx_prestige_next", next, "apx_level", self.pers["rank"] + 1 );
}

request()
{
	self.prestigeConfirmationUntil = undefined;
	self updateMenu();
	if( !self canEnter() ) return false;
	self.prestigeConfirmationUntil = getTime() + 30000;
	return true;
}

enter()
{
	if( !isDefined( self.prestigeConfirmationUntil ) || getTime() > self.prestigeConfirmationUntil ) return false;
	// Consume confirmation before changing any state. A repeated response cannot reset twice.
	self.prestigeConfirmationUntil = undefined;
	if( !self canEnter() ) return false;
	self.pers["prestige"]++;
	self.pers["rankxp"] = 0;
	self.pers["rank"] = 0;
	self syncProfile();
	self braxi\_profile::sanitizeCustomization();
	self braxi\_rank_integrity::updateAntiHackValues();
	self iPrintlnBold( "Prestige " + self.pers["prestige"] + " reached. Level reset to 1." );
	self playLocalSound( "mp_level_up" );
	return true;
}
