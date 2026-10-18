// One bounded, client-owned feedback element. Burst hits reuse the same number.
show( loss )
{
	if( loss <= 0 ) return;
	now = getTime();
	if( !isDefined( self.apxDamageTime ) || now - self.apxDamageTime > 250 )
		self.apxDamageTotal = 0;
	self.apxDamageTotal += loss;
	self.apxDamageTime = now;
	self.apxDamageUntil = now + 350;
	self setClientDvar( "apx_hud_damage_flash", 1 );
	self.apxDamageFlash = 1;
	self notify( "apx_damage_feedback" );
	if( isDefined( self.apxDamageText ) ) self.apxDamageText destroy();
	hud = newClientHudElem( self );
	// Center-relative coordinates match UI's 640x480 subleft/subtop canvas.
	hud.horzAlign = "center";
	hud.vertAlign = "middle";
	hud.alignX = "right";
	hud.alignY = "bottom";
	hud.x = -204;
	hud.y = 197;
	hud.font = "objective";
	hud.fontScale = 1.4;
	hud.color = (1, 0.48, 0.36);
	hud.alpha = 0.9;
	hud.sort = 10;
	hud.hideWhenInMenu = true;
	hud setValue( 0 - self.apxDamageTotal );
	hud moveOverTime( 0.65 );
	hud.y = 181;
	hud fadeOverTime( 0.65 );
	hud.alpha = 0;
	self.apxDamageText = hud;
	self thread retire( hud );
}

reset()
{
	self notify( "apx_damage_feedback" );
	if( isDefined( self.apxDamageText ) ) self.apxDamageText destroy();
	self.apxDamageText = undefined;
	self.apxDamageTime = undefined;
	self.apxDamageTotal = 0;
	self.apxDamageUntil = 0;
	self.apxDamageFlash = 0;
	self setClientDvar( "apx_hud_damage_flash", 0 );
	self.apxHudPreviousHP = self.health;
	self.apxHudPreviousMaxHP = self.maxhealth;
}

retire( hud )
{
	self endon( "disconnect" );
	self endon( "apx_damage_feedback" );
	for( i = 0; i < 14; i++ )
	{
		wait 0.05;
		if( self.sessionstate != "playing" || self.health <= 0 ) break;
	}
	hud destroy();
	self.apxDamageText = undefined;
}

updateFlash()
{
	flash = 0;
	if( self.sessionstate == "playing" && self.health > 0 && isDefined( self.apxDamageUntil ) )
		flash = braxi\_prestige::clamp( float(self.apxDamageUntil-getTime())/350, 0, 1 );
	if( !isDefined( self.apxDamageFlash ) || self.apxDamageFlash != flash )
	{
		self setClientDvar( "apx_hud_damage_flash", flash );
		self.apxDamageFlash = flash;
	}
}
