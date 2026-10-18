// Native execution coverage; packet counts are covered separately because bots
// bypass SV_AddServerCommand's reliable queue.
run()
{
    wait 1;
    bot = addTestClient();
    assertex( isDefined( bot ), "APX_MENU_TRAFFIC_FAIL: create client" );
    for( attempt = 0; attempt < 100 && !isDefined( bot.pers["rank"] ); attempt++ ) wait 0.05;
    xp = bot getStat( 2301 );
    bot.apxMenuMap = undefined;
    for( attempt = 0; attempt < 40; attempt++ )
    {
        bot notify( "menuresponse", "-1", "ui:team_select:apx_open" );
        wait 0.05;
    }
    assertex( bot.apxMenuMap == level.mapName, "APX_MENU_TRAFFIC_FAIL: overview metadata" );
    categories = strTok( "weapon;character;knife;ability;spray", ";" );
    for( index = 0; index < categories.size; index++ )
    {
        bot braxi\_menu_browser::query( categories[index], "", false );
        assertex( bot.apxBrowser.ids.size > 0, "APX_MENU_TRAFFIC_FAIL: browser "+categories[index] );
        wait 0.1;
    }
    assertex( bot getStat( 2301 ) == xp, "APX_MENU_TRAFFIC_FAIL: profile preserved" );
    println( "APX_MENU_TRAFFIC_RUNTIME_PASS: repeated menu envelopes, all five browser categories, saved XP retained" );
}
