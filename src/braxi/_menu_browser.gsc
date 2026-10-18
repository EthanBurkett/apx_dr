// Per-player catalog snapshots: text search, owned filter, direct page jump and
// previous/next selection. The menu has a fixed number of rows at any catalog size.
pageSize() { return 8; }

validCategory( category )
{
    return category == "weapon" || category == "character" || category == "ability" || category == "spray" || category == "knife" || category == "gloves";
}

isUnlocked( category, id )
{
    if( category == "weapon" ) return self braxi\_rank::isItemUnlocked( id );
    if( category == "character" ) return self braxi\_rank::isCharacterUnlocked( id );
    if( category == "ability" ) return id == 0 || self braxi\_rank::isAbilityUnlocked( id );
    if( category == "spray" ) return self braxi\_rank::isSprayUnlocked( id );
    if( category == "knife" ) return self braxi\_content_unlocks::knifeUnlocked( id );
    if( category == "gloves" ) return self braxi\_content_unlocks::glovesUnlocked( id );
    return false;
}

query( category, search, owned )
{
    if( !validCategory( category ) ) return false;
    search = toLower( getSubStr( search, 0, int( min( search.size, 32 ) ) ) );
    if( search == " " || search == "search" ) search = "";
    selectedStat = 981;
    if( category == "character" ) selectedStat = 980;
    if( category == "ability" ) selectedStat = 982;
    if( category == "spray" ) selectedStat = 979;
    if( category == "knife" ) selectedStat = 2405;
    if( category == "gloves" ) selectedStat = 2406;
    preferred = self getStat( selectedStat );
    if( isDefined( self.apxBrowser ) && self.apxBrowser.category == category ) preferred = self.apxBrowser.selected;
    state = spawnStruct();
    state.category = category;
    state.query = search;
    state.owned = owned;
    state.ids = [];
    state.page = 0;
    state.selected = -1;
    count = level.numItems;
    if( category == "character" ) count = level.numCharacters;
    if( category == "ability" ) count = level.numAbilities;
    if( category == "spray" ) count = level.numSprays;
    if( category == "knife" ) count = level.numKnives;
    if( category == "gloves" ) count = level.numGloves;
    for( id = 0; id < count; id++ )
    {
        key = category+":"+id;
        name = tableLookup( "mp/apx_catalog.csv", 0, key, 3 );
        if( name == "" ) continue;
        if( search != "" && !isSubStr( toLower( name ), search ) ) continue;
        if( owned && !self isUnlocked( category, id ) ) continue;
        if( id == preferred ) state.selected = id;
        state.ids[state.ids.size] = id;
    }
    if( state.ids.size && state.selected < 0 ) state.selected = state.ids[0];
    for( index = 0; index < state.ids.size; index++ )
        if( state.ids[index] == state.selected ) state.page = int( index/pageSize() );
    self.apxBrowser = state;
    self publish();
    return true;
}

publish()
{
    state = self.apxBrowser;
    total = state.ids.size;
    pages = int( max( 1, int( (total+pageSize()-1)/pageSize() ) ) );
    state.page = int( max( 0, min( state.page, pages-1 ) ) );
    // Edit buffers belong to the client. Echoing snapshots into an active field
    // interferes with its caret; publish output under distinct browse dvars.
    self setClientDvars( "apx_browse_count", total, "apx_browse_page", state.page+1,
        "apx_browse_pages", pages, "apx_browse_owned", state.owned );
    for( slot = 0; slot < pageSize(); slot++ )
    {
        index = state.page*pageSize()+slot;
        shown = index < total;
        name = "";
        detail = "";
        selected = false;
        if( shown )
        {
            id = state.ids[index];
            key = state.category+":"+id;
            name = tableLookup( "mp/apx_catalog.csv", 0, key, 3 );
            rank = int( tableLookup( "mp/apx_catalog.csv", 0, key, 6 ) )-1;
            detail = braxi\_content_unlocks::requirement( state.category, id, rank );
            if( state.category == "ability" ) detail = "Challenge unlock";
            if( state.category == "gloves" ) detail = "Operator unlock";
            if( self isUnlocked( state.category, id ) ) detail = "Unlocked";
            selected = state.selected == id;
        }
        self setClientDvars( "apx_browse_show_"+slot, shown, "apx_browse_name_"+slot, name,
            "apx_browse_detail_"+slot, detail, "apx_browse_selected_"+slot, selected );
    }
    exists = state.selected >= 0;
    name = "No matches";
    description = "Try a shorter name or show all items.";
    preview = "white";
    turn = "white";
    cell = 0;
    turnCell = 0;
    unlocked = false;
    equipped = false;
    requirement = "";
    if( exists )
    {
        key = state.category+":"+state.selected;
        name = tableLookup( "mp/apx_catalog.csv", 0, key, 3 );
        description = tableLookup( "mp/apx_catalog.csv", 0, key, 4 );
        preview = tableLookup( "mp/apx_catalog.csv", 0, key, 5 );
        turn = tableLookup( "mp/apx_catalog.csv", 0, key, 7 );
        cell = int( tableLookup( "mp/apx_catalog.csv", 0, key, 8 ) );
        turnCell = int( tableLookup( "mp/apx_catalog.csv", 0, key, 9 ) );
        if( turn == "" ) turn = preview;
        if( state.category == "gloves" && state.selected == 0 )
        {
            preview = tableLookup( "mp/apx_character_previews.csv", 0, self getStat( 980 ), 3 );
            turn = tableLookup( "mp/apx_character_previews.csv", 0, self getStat( 980 ), 4 );
            cell = int( tableLookup( "mp/apx_character_previews.csv", 0, self getStat( 980 ), 8 ) );
            turnCell = int( tableLookup( "mp/apx_character_previews.csv", 0, self getStat( 980 ), 9 ) );
        }
        unlocked = self isUnlocked( state.category, state.selected );
        rank = int( tableLookup( "mp/apx_catalog.csv", 0, key, 6 ) )-1;
        requirement = "Requires "+braxi\_content_unlocks::requirement( state.category, state.selected, rank );
        if( state.category == "ability" ) requirement = "Complete the ability challenge";
        if( state.category == "gloves" ) requirement = "Unlock an operator with these arms";
        if( unlocked ) requirement = "Unlocked / equips next spawn";
        stat = 981;
        if( state.category == "character" ) stat = 980;
        if( state.category == "ability" ) stat = 982;
        if( state.category == "spray" ) stat = 979;
        if( state.category == "knife" ) stat = 2405;
        if( state.category == "gloves" ) stat = 2406;
        equipped = self getStat( stat ) == state.selected;
    }
    self setClientDvars( "apx_browse_name", name, "apx_browse_description", description,
        "apx_browse_preview", preview, "apx_browse_turn", turn, "apx_browse_cell", cell );
    self setClientDvars( "apx_browse_exists", exists, "apx_browse_unlocked", unlocked,
        "apx_browse_equipped", equipped, "apx_browse_requirement", requirement,
        "apx_browse_turn_cell", turnCell );
}

handle( args )
{
    if( args.size < 3 || !validCategory( args[1] ) ) return;
    category = args[1];
    action = args[2];
    if( !isDefined( self.apxBrowser ) || self.apxBrowser.category != category ) self query( category, "", false );
    state = self.apxBrowser;
    if( action == "open" )
    {
        self query( category, "", false );
        return;
    }
    if( action == "search" )
    {
        self query( category, self getUserinfo( "apx_catalog_search" ), state.owned );
        return;
    }
    if( action == "all" || action == "owned" )
    {
        self query( category, state.query, action == "owned" );
        return;
    }
    if( action == "equip" )
    {
        if( state.selected >= 0 ) self braxi\_menu_catalog::equip( category, ""+state.selected );
        self publish();
        return;
    }
    if( args.size != 4 ) return;
    value = braxi\_admin_progression::parseInteger( args[3], 0, 255 );
    if( args[3] == "-1" && (action == "page" || action == "step") ) value = -1;
    else if( value < 0 ) return;
    if( action == "select" && value >= 0 && value < pageSize() )
    {
        index = state.page*pageSize()+value;
        if( index < state.ids.size ) state.selected = state.ids[index];
    }
    else if( action == "page" ) state.page += value;
    else if( action == "jump" )
    {
        page = braxi\_admin_progression::parseInteger( self getUserinfo( "apx_catalog_page" ), 1, 256 );
        if( page >= 1 ) state.page = page-1;
    }
    else if( action == "step" && state.ids.size )
    {
        index = 0;
        for( i = 0; i < state.ids.size; i++ ) if( state.ids[i] == state.selected ) index = i;
        index = (index+state.ids.size+value)%state.ids.size;
        state.selected = state.ids[index];
        state.page = int( index/pageSize() );
    }
    self publish();
}
