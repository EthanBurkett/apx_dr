// Real bot tests for the unregistered menu bridge, saved prefs and access gates.
run()
{
    wait 1;
    players = braxi\_common::getAllPlayers();
    if( players.size ) bot = players[0];
    else bot = addTestClient();
    check( isDefined( bot ), "create test client" );
    wait 0.4;
    if( isDefined( game["apx_menu_test_restart"] ) )
    {
        check( bot getStat( 2401 ) == 110 && bot getStat( 2402 ) == 1, "FOV/fullbright survive preserving restart" );
        println( "APX_MENUS_RUNTIME_PASS: bridge, preferences, validation, unlocks, access gates and restart persistence" );
        return;
    }
    bot braxi\_teams::setTeam( "allies" );
    bot braxi\_player::spawnPlayer();
    wait 0.5;
    bot braxi\_preferences::defaults();
    bot braxi\_preferences::load();
    check( bot getStat( 2401 ) == 90 && bot getStat( 2402 ) == 0, "new profile defaults" );
    bot notify( "menuresponse", "-1", "ui:dr_options:pref:fov:110" );
    wait 0.1;
    bot notify( "menuresponse", "-1", "ui:dr_options:pref:fullbright:1" );
    wait 0.1;
    check( bot getStat( 2401 ) == 110 && bot getStat( 2402 ) == 1, "real menu envelope saves preferences" );
    bot notify( "menuresponse", "-1", "ui:dr_options:pref:fov:999" );
    wait 0.1;
    check( bot getStat( 2401 ) == 110, "invalid FOV rejected" );
    bot notify( "menuresponse", "-1", "ui:dr_options:pref:fullbright:2" );
    wait 0.1;
    check( bot getStat( 2402 ) == 1, "invalid toggle rejected" );
    bot notify( "menuresponse", "-1", "ui:dr_characters:browse:character:open" );
    wait 0.1;
    bot braxi\_menu_browser::query( "character", "zoey", false );
    check( bot.apxBrowser.ids.size == 1 && bot.apxBrowser.selected == 4, "case-insensitive character search" );
    bot braxi\_menu_browser::query( "character", "zoey", true );
    check( !bot.apxBrowser.ids.size && bot.apxBrowser.selected == -1, "owned filter and empty result" );
    originalItems = level.numItems;
    level.numItems = originalItems+100;
    for( id = originalItems; id < level.numItems; id++ )
    {
        level.itemInfo[id] = [];
        level.itemInfo[id]["rank"] = 999;
        level.itemInfo[id]["prestige"] = 0;
    }
    bot braxi\_menu_browser::query( "weapon", "fixture item", false );
    check( bot.apxBrowser.ids.size == 100, "100-choice filtered catalog" );
    bot.apxBrowser.page = 12;
    bot braxi\_menu_browser::publish();
    bot notify( "menuresponse", "-1", "ui:dr_weapons:browse:weapon:select:3" );
    wait 0.1;
    check( bot.apxBrowser.selected == originalItems+99, "direct last-page selection" );
    bot notify( "menuresponse", "-1", "ui:dr_weapons:browse:weapon:step:1" );
    wait 0.1;
    check( bot.apxBrowser.selected == originalItems && bot.apxBrowser.page == 0, "selection wraps in 100-choice result" );
    bot braxi\_menu_browser::query( "weapon", "FIXTURE ITEM 99", false );
    check( bot.apxBrowser.ids.size == 1 && bot.apxBrowser.selected == originalItems+99, "direct name lookup across 100 choices" );
    level.numItems = originalItems;
    bot braxi\_menu_browser::query( "weapon", "", false );
    previous = bot getStat( 981 );
    bot notify( "menuresponse", "-1", "ui:dr_weapons:equip:weapon:255" );
    wait 0.1;
    check( bot getStat( 981 ) == previous, "out-of-range equipment rejected" );
    bot notify( "menuresponse", "-1", "ui:dr_characters:equip:character:1" );
    wait 0.1;
    check( bot getStat( 980 ) == 0, "retired character rejected" );
    bot notify( "menuresponse", "-1", "ui:dr_weapons:equip:weapon:7" );
    wait 0.1;
    check( bot getStat( 981 ) == previous, "locked equipment rejected" );
    bot notify( "menuresponse", "-1", "ui:apx_admin_progression:progression:setrank:70" );
    wait 0.1;
    check( bot.pers["rank"] == 0, "forged admin page rejected" );
    bot.pers["isDog"] = false;
    bot notify( "menuresponse", "-1", "ui:vip:vip_dog" );
    wait 0.1;
    check( !bot.pers["isDog"], "VIP denied for regular player" );
    bot.pers["vip"] = true;
    bot braxi\_menu_service::syncAccess();
    bot notify( "menuresponse", "-1", "ui:vip:vip_dog" );
    wait 0.1;
    check( bot.pers["isDog"], "VIP feature allowed for entitled player" );
    bot.pers["isDog"] = false;
    bot.pers["admin"] = true;
    bot.pers["permissions"] = "p";
    bot thread braxi\_admin_ui::adminMenu();
    wait 0.1;
    bot notify( "menuresponse", "-1", "ui:apx_admin_progression:progression:setrank:55" );
    wait 0.2;
    check( bot.pers["rank"] == 54, "authenticated progression control" );
    bot notify( "menuresponse", "-1", "ui:dr_weapons:equip:weapon:7" );
    wait 0.1;
    check( bot getStat( 981 ) == 7, "unlocked selection saved" );
    targetGuid = bot.apxAdminTargetGuid;
    bot.apxAdminTargetGuid = "stale-target-guid";
    bot notify( "menuresponse", "-1", "ui:apx_admin_progression:progression:setrank:70" );
    wait 0.1;
    check( bot.pers["rank"] == 54, "stale target identity rejected" );
    bot.apxAdminTargetGuid = targetGuid;
    bot.pers["admin"] = false;
    bot notify( "menuresponse", "-1", "ui:apx_admin_progression:progression:setrank:70" );
    wait 0.1;
    check( bot.pers["rank"] == 54, "revoked admin cannot use stale menu" );
    bot braxi\_menu_service::syncAccess();
    game["apx_menu_test_restart"] = true;
    map_restart( true );
}

check( condition, message )
{
    if( !condition ) println( "APX_MENUS_RUNTIME_FAIL: "+message );
    assertex( condition, "APX_MENUS_RUNTIME_FAIL: "+message );
    println( "APX_MENUS_CHECK: "+message );
}
