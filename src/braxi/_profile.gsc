// ApX Deathrun: validate persisted customization before using table indices.
sanitizeCustomization()
{
	character = self getStat( 980 );
	if( character < 0 || character >= level.numCharacters ) character = 0;
	if( !level.characterInfo[character]["enabled"] ) character = 0;
	item = self getStat( 981 );
	if( item < 0 || item >= level.numItems ) item = 0;
	if( !level.itemInfo[item]["enabled"] ) item = 0;
	spray = self getStat( 979 );
	if( spray < 0 || spray >= level.numSprays ) spray = 0;
	ability = self getStat( 982 );
	if( ability < 0 || ability >= level.numAbilities ) ability = 0;
	if( isDefined( self.pers["rank"] ) )
	{
		if( !self braxi\_rank::isCharacterUnlocked( character ) ) character = 0;
		if( !self braxi\_rank::isItemUnlocked( item ) ) item = 0;
		if( !self braxi\_rank::isSprayUnlocked( spray ) ) spray = 0;
	}
	if( ability && !self braxi\_rank::isAbilityUnlocked( ability ) ) ability = 0;
	knife = self getStat( 2405 );
	if( knife < 0 || knife >= level.numKnives ) knife = 0;
	if( isDefined( self.pers["rank"] ) && !self braxi\_content_unlocks::knifeUnlocked( knife ) ) knife = 0;
	self setStat( 2405, knife );
	gloves = self getStat( 2406 );
	if( gloves < 0 || gloves >= level.numGloves ) gloves = 0;
	if( isDefined( self.pers["rank"] ) && !self braxi\_content_unlocks::glovesUnlocked( gloves ) ) gloves = 0;
	self setStat( 2406, gloves );
	self setStat( 980, character );
	self setStat( 981, item );
	self setStat( 979, spray );
	self setStat( 982, ability );
	self setClientDvars( "drui_character", character, "drui_weapon", item,
		"drui_spray", spray, "drui_ability", ability );
}
