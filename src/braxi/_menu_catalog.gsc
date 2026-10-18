// Keep UI snapshots authoritative and apply only unlocked catalog selections.
refresh()
{
    if( !isDefined( self.pers["rank"] ) ) return;
    // Browsers publish only their visible page and selected item's unlock state.
    // Broadcasting one dvar per catalog ID overflows the reliable command ring
    // on real clients; bots bypass that queue entirely.
    if( isDefined( self.apxMenuMap ) && self.apxMenuMap == level.mapName ) return;
    self.apxMenuMap = level.mapName;
    self setClientDvar( "apx_menu_map", level.mapName );
}

equip( category, text )
{
    id = braxi\_admin_progression::parseInteger( text, 0, 255 );
    if( id < 0 || !isDefined( self.pers["rank"] ) ) return false;
    stat = -1;
    if( category == "weapon" && self braxi\_rank::isItemUnlocked( id ) ) stat = 981;
    if( category == "character" && self braxi\_rank::isCharacterUnlocked( id ) ) stat = 980;
    if( category == "ability" && (id == 0 || self braxi\_rank::isAbilityUnlocked( id )) ) stat = 982;
    if( category == "spray" && self braxi\_rank::isSprayUnlocked( id ) ) stat = 979;
    if( category == "knife" && self braxi\_content_unlocks::knifeUnlocked( id ) ) stat = 2405;
    if( category == "gloves" && self braxi\_content_unlocks::glovesUnlocked( id ) ) stat = 2406;
    if( stat < 0 ) return false;
    self setStat( stat, id );
    self braxi\_profile::sanitizeCustomization();
    self braxi\_rank_integrity::updateAntiHackValues();
    self setClientDvar( "apx_menu_feedback", "Selection saved for your next spawn" );
    self refresh();
    return true;
}
