// Isolated native inventory, first-person arms and in-game route coverage.
run()
{
    wait 1;
    bot = addTestClient();
    check( isDefined( bot ), "create bot" );
    for( attempt = 0; attempt < 100 && !isDefined( bot.pers["rank"] ); attempt++ ) wait 0.05;
    // The ready-up controller otherwise relinks/disables this lone test bot.
    // Exercise the live-game equipment paths without competing round changes.
    level notify( "kill logic" );
    bot braxi\_teams::setTeam( "allies" );
    bot.isDog = false;
    println( "APX_EQUIPMENT_ARMS: count="+level.numGloves+" first="+tableLookup( "mp/gloveTable.csv", 0, "1", 0 )+" trailing="+tableLookup( "mp/gloveTable.csv", 0, "2", 5 ) );
    check( level.numGloves == 13, "stable arms registry count" );
    bot.pers["prestige"] = level.maxPrestige;
    bot.pers["rank"] = level.maxRank;
    println( "APX_EQUIPMENT_ARMS_MODEL: first="+level.gloveInfo[1]["model"]+" operator="+level.characterInfo[0]["handsModel"] );
    check( bot braxi\_content_unlocks::glovesUnlocked( 1 ), "base arms available" );
    bot setStat( 981, 0 ); bot setStat( 980, 0 ); bot setStat( 2406, 0 );
    level.efrActive = true;
    game["state"] = "playing";
    primary = level.itemInfo[0]["item"];
    sets = 0;
    for( id = 1; id < level.numGloves; id++ )
    {
        if( !level.gloveInfo[id]["enabled"] ) continue;
        check( bot braxi\_menu_catalog::equip( "gloves", ""+id ), "save arms "+id );
        bot braxi\_player::spawnPlayer();
        check( bot getViewModel() == level.gloveInfo[id]["model"], "spawn arms "+id );
        bot setStat( 980, 1 ); bot braxi\_teams::setPlayerModel();
        check( bot getViewModel() == level.gloveInfo[id]["model"], "operator preserves arms "+id );
        sets++;
        wait 0.05;
    }
    check( sets == 5, "five active arms sets" );
    bot setStat( 2406, 0 ); bot braxi\_teams::setPlayerModel();
    check( bot getViewModel() == level.characterInfo[bot getStat( 980 )]["handsModel"], "automatic arms" );
    bot.pers["prestige"] = 0; bot.pers["rank"] = 0;
    check( !bot braxi\_menu_catalog::equip( "knife", "8" ), "locked knife rejected" );
    check( !bot braxi\_menu_catalog::equip( "gloves", "9" ), "locked Kermit arms rejected" );
    bot setStat( 2405, 8 ); bot setStat( 2406, 9 );
    bot braxi\_player::spawnPlayer();
    check( bot getStat( 2405 ) == 0 && bot getStat( 2406 ) == 0, "locked saved selections sanitized" );
    bot braxi\_equipment::makeMeDog();
    check( bot hasWeapon( "dog_mp" ) && !bot hasWeapon( primary ), "dog inventory isolated" );
    bot braxi\_equipment::makeMeHuman();
    check( bot hasWeapon( primary ) && bot hasWeapon( "knife_mp" ) && !bot hasWeapon( "dog_mp" ), "human loadout restored" );
    level.efrActive = false; level.trapsDisabled = true;
    bot braxi\_player::spawnPlayer();
    check( bot hasWeapon( "knife_mp" ) && !bot hasWeapon( primary ), "knife-only respawn" );
    level.trapsDisabled = false;
    bot.pers["team"] = "axis"; bot braxi\_player::spawnPlayer();
    check( bot hasWeapon( "tomahawk_mp" ) && bot hasWeapon( "knife_mp" ), "Activator tomahawk and knife" );
    routes = strTok( "apx_knife;apx_gloves;apx_rewards", ";" );
    for( index = 0; index < routes.size; index++ )
    {
        check( bot braxi\_menu_service::route( routes[index] ), "registered in-game route "+routes[index] );
        bot notify( "menuresponse", "-1", "ui:"+routes[index]+":apx_open" );
        wait 0.1;
    }
    bot notify( "menuresponse", "-1", "ui:apx_gloves:browse:gloves:open" );
    wait 0.2;
    check( bot.apxBrowser.category == "gloves" && bot.apxBrowser.ids.size == 6, "arms selection browser" );
    bot notify( "menuresponse", "-1", "ui:apx_rewards:content:open" ); wait 0.2;
    check( bot.apxRewardTier == 0, "reward menu opens" );
    bot notify( "menuresponse", "-1", "ui:apx_rewards:content:next" ); wait 0.2;
    check( bot.apxRewardTier == 1, "reward tier navigation" );
    bot notify( "menuresponse", "-1", "ui:apx_rewards:content:nextpage" ); wait 0.2;
    check( bot.apxRewardPage == 1, "reward page navigation" );
    bot.pers["team"] = "allies";
    bot.pers["prestige"] = level.maxPrestige; bot.pers["rank"] = level.maxRank;
    bot setStat( 980, 0 ); bot setStat( 981, 0 ); bot setStat( 2406, 0 );
    level.trapsDisabled = false; level.efrActive = true; game["state"] = "playing";
    previous = "";
    for( id = 0; id < level.numKnives; id++ )
    {
        bot setStat( 2405, id );
        bot braxi\_player::spawnPlayer();
        bot enableWeapons();
        bot botWeapon( primary );
        knife = level.knifeInfo[id]["item"];
        check( bot hasWeapon( primary ) && bot hasWeapon( knife ), "spawn pair "+id );
        if( previous != "" && previous != knife ) check( !bot hasWeapon( previous ), "old knife removed "+id );
        wait 0.8;
        check( bot getCurrentWeapon() == primary, "primary is initial weapon "+id );
        bot botWeapon( knife ); bot switchToWeapon( knife );
        bot waitForWeapon( knife );
        check( bot getCurrentWeapon() == knife, "switch to knife "+id );
        wait 0.8;
        bot botWeapon( primary ); bot switchToWeapon( primary );
        bot waitForWeapon( primary );
        check( bot getCurrentWeapon() == primary, "switch back to primary "+id );
        previous = knife;
    }
    println( "APX_EQUIPMENT_RUNTIME_PASS: all nine knife pairs, native selection commands, respawns, five arms sets, unlock validation, dog/round rules and menu/reward navigation" );
}

waitForWeapon( weapon )
{
    // Bots do not execute CG_NextWeapon_f / the human client's animation/input
    // path. Verify command acceptance, then set the bot's native draw state.
    // This is inventory/asset coverage, not client keyboard or animation QA.
    check( self switchToWeapon( weapon ), "native selection accepted "+weapon );
    self botWeapon( weapon );
    self setSpawnWeapon( weapon );
    wait 0.1;
    println( "APX_EQUIPMENT_SWITCH: wanted="+weapon+" actual="+self getCurrentWeapon()+" state="+self.sessionstate+" health="+self.health );
}

check( condition, message )
{
    assertex( condition, "APX_EQUIPMENT_RUNTIME_FAIL: "+message );
    println( "APX_EQUIPMENT_CHECK: "+message );
}
