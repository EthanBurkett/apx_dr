// Changed-only client HUD state. All layout remains in ui_mp/hud includes.
#include braxi\_common;

fraction( value, minimum, maximum )
{
	if( maximum <= minimum ) return 0;
	return braxi\_prestige::clamp( float(value-minimum)/(maximum-minimum), 0, 1 );
}

run()
{
	level endon( "intermission" );
	for(;;)
	{
		mode = "DEATHRUN";
		detail = "";
		warmup = isDefined( level.efrActive ) && level.efrActive;
		if( warmup )
		{
			mode = "PRACTICE";
			detail = plugins\_efr::participantCount() + " / " + level.dvar["pi_efr_min"] + " players ready";
			if( level.efrCountdown > 0 ) detail = "Match starts in " + level.efrCountdown;
		}
		else if( game["state"] == "readyup" ) mode = "GET READY";
		else if( level.freeRun || level.trapsDisabled ) mode = "FREE RUN";
		players = getAllPlayers();
		for( i = 0; i < players.size; i++ ) players[i] updatePlayer( mode, detail, warmup );
        wait 0.1;
	}
}

updatePlayer( mode, detail, warmup )
{
	self braxi\_menu_service::syncAccess();
	if( !isDefined( self.pers["rank"] ) || !isDefined( self.pers["rankxp"] ) ) return;
	metadata = mode + ":" + detail;
	if( !isDefined( self.apxHudMeta ) || self.apxHudMeta != metadata )
	{
		self setClientDvars( "apx_hud_mode", mode, "apx_hud_detail", detail, "apx_efr_active", warmup );
		self.apxHudMeta = metadata;
	}
	minimum = braxi\_rank_tables::getRankInfoMinXP( self.pers["rank"] );
	maximum = braxi\_rank_tables::getRankInfoMaxXP( self.pers["rank"] );
	xp = self.pers["rankxp"];
	label = (xp-minimum) + " / " + (maximum-minimum) + " XP";
	if( warmup ) label = "Practice / XP paused";
	else if( self.pers["rank"] == level.maxRank && xp >= maximum )
	{
		label = "PRESTIGE READY";
		if( self.pers["prestige"] >= level.maxPrestige ) label = "MAX PRESTIGE";
	}
	progress = xp + ":" + self.pers["rank"] + ":" + self.pers["prestige"] + ":" + label;
	if( !isDefined( self.apxHudProgress ) || self.apxHudProgress != progress )
	{
		self setClientDvars( "apx_hud_xp", fraction( xp, minimum, maximum ), "apx_hud_progress", label );
		self.apxHudProgress = progress;
	}
	hp = 0;
	maximumHealth = 0;
	if( self.sessionstate == "playing" && isDefined( self.health ) && isDefined( self.maxhealth ) )
	{
		hp = self.health;
		maximumHealth = self.maxhealth;
	}
	// Observe actual health loss, including map damage that bypasses the callback.
	// Spawn/spectator transitions reset this baseline instead of displaying damage.
	if( hp > 0 && isDefined( self.apxHudPreviousHP ) && self.apxHudPreviousHP > hp &&
		isDefined( self.apxHudPreviousMaxHP ) && self.apxHudPreviousMaxHP == maximumHealth )
		self braxi\_hud_damage::show( self.apxHudPreviousHP - hp );
	self.apxHudPreviousHP = hp;
	self.apxHudPreviousMaxHP = maximumHealth;
	self braxi\_hud_damage::updateFlash();
	self updateAmmo( hp > 0 );
	healthState = hp + ":" + maximumHealth;
	if( !isDefined( self.apxHudHealth ) || self.apxHudHealth != healthState )
	{
		self setClientDvars( "apx_hud_hp", hp, "apx_hud_health", fraction( hp, 0, maximumHealth ),
			"ui_healthbar", fraction( hp, 0, maximumHealth ) );
		self.apxHudHealth = healthState;
	}
}

updateAmmo( alive )
{
	weapon = "none";
	clip = 0;
	stock = 0;
	if( alive ) weapon = self getCurrentWeapon();
	show = isDefined( weapon ) && weapon != "none" && weapon != "";
	if( show )
	{
		clip = self getWeaponAmmoClip( weapon );
		stock = self getWeaponAmmoStock( weapon );
	}
	state = weapon + ":" + clip + ":" + stock + ":" + show;
	if( !isDefined( self.apxHudAmmo ) || self.apxHudAmmo != state )
	{
		self setClientDvars( "apx_hud_clip", clip, "apx_hud_stock", stock, "apx_hud_ammo_visible", show );
		self.apxHudAmmo = state;
	}
}
