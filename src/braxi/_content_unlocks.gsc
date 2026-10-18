// Catalog requirements are ordered by prestige, then level. Earlier tiers stay
// available after prestiging; the current tier still requires its rank milestone.
meets( prestige, rank )
{
    current = 0;
    playerRank = 0;
    if( isDefined( self.pers["prestige"] ) ) current = self.pers["prestige"];
    if( isDefined( self.pers["rank"] ) ) playerRank = self.pers["rank"];
    return current > prestige || (current == prestige && playerRank >= rank);
}

prestige( category, id )
{
    // A separate table preserves every legacy catalog column and saved ID.
    value = tableLookup( "mp/apx_content_unlocks.csv", 0, category+":"+id, 1 );
    if( value == "" ) return 0;
    return int( value );
}

requirement( category, id, rank )
{
    tier = prestige( category, id );
    if( tier ) return "Prestige "+tier+" / Level "+(rank+1);
    return "Level "+(rank+1);
}

publishRewards( tier, page )
{
    tier = int( max( 0, min( tier, level.maxPrestige ) ) );
    self.apxRewardTier = tier;
    rewards = [];
    for( category = 0; category < 3; category++ )
    {
        info = level.itemInfo;
        kind = "PRIMARY";
        code = "weapon";
        if( category == 1 ) { info = level.characterInfo; kind = "OPERATOR"; code = "character"; }
        if( category == 2 ) { info = level.knifeInfo; kind = "MELEE"; code = "knife"; }
        for( id = 0; id < info.size; id++ )
        {
            if( !info[id]["enabled"] || info[id]["prestige"] != tier ) continue;
            reward = spawnStruct();
            reward.rank = info[id]["rank"];
            reward.name = tableLookup( "mp/apx_catalog.csv", 0, code+":"+id, 3 );
            reward.kind = kind;
            reward.owned = self meets( tier, reward.rank );
            position = rewards.size;
            while( position > 0 && rewards[position-1].rank > reward.rank )
            {
                rewards[position] = rewards[position-1];
                position--;
            }
            rewards[position] = reward;
        }
    }
    if( !isDefined( page ) ) page = 0;
    pages = int( max( 1, int( (rewards.size+7)/8 ) ) );
    page = int( max( 0, min( page, pages-1 ) ) );
    self.apxRewardPage = page;
    self setClientDvars( "apx_rewards_tier", tier, "apx_rewards_count", rewards.size,
        "apx_rewards_page", page+1, "apx_rewards_pages", pages );
    for( slot = 0; slot < 8; slot++ )
    {
        name = ""; kind = ""; status = ""; rank = "";
        index = page*8+slot;
        if( index < rewards.size )
        {
            name = rewards[index].name; kind = rewards[index].kind;
            rank = "LV "+(rewards[index].rank+1);
            status = "LOCKED";
            if( rewards[index].owned ) status = "UNLOCKED";
        }
        self setClientDvars( "apx_reward_name_"+slot, name, "apx_reward_kind_"+slot, kind,
            "apx_reward_rank_"+slot, rank, "apx_reward_status_"+slot, status );
    }
}

knifeUnlocked( id )
{
    if( id < 0 || id >= level.numKnives ) return false;
    return level.knifeInfo[id]["enabled"] && self meets( level.knifeInfo[id]["prestige"], level.knifeInfo[id]["rank"] );
}

selectedKnife()
{
    id = self getStat( 2405 );
    if( !self knifeUnlocked( id ) ) id = 0;
    return level.knifeInfo[id]["item"];
}

glovesUnlocked( id )
{
    if( id < 0 || id >= level.numGloves ) return false;
    if( id == 0 ) return true;
    if( !level.gloveInfo[id]["enabled"] ) return false;
    for( character = 0; character < level.numCharacters; character++ )
        if( level.characterInfo[character]["handsModel"] == level.gloveInfo[id]["model"] &&
            self braxi\_rank::isCharacterUnlocked( character ) ) return true;
    return false;
}

selectedHands()
{
    id = self getStat( 2406 );
    if( id > 0 && self glovesUnlocked( id ) ) return level.gloveInfo[id]["model"];
    if( self.pers["team"] == "axis" ) return "viewmodel_hands_zombie";
    character = self getStat( 980 );
    if( character < 0 || character >= level.numCharacters ) character = 0;
    return level.characterInfo[character]["handsModel"];
}
