// Isolated native HUD state test. No human clients or stored profiles.
run()
{
    wait 1;
    bot = addTestClient();
    assertex( isDefined( bot ), "APX_HUD_RUNTIME_FAIL: create bot" );
    wait 0.3;
    bot braxi\_teams::setTeam( "allies" );
    bot braxi\_player::spawnPlayer();
    wait 0.5;
    bot takeAllWeapons();
    bot giveWeapon( "colt45_mp" );
    bot setSpawnWeapon( "colt45_mp" );
    bot botWeapon( "colt45_mp" );
    bot switchToWeapon( "colt45_mp" );
    bot setWeaponAmmoClip( "colt45_mp", 5 );
    bot setWeaponAmmoStock( "colt45_mp", 37 );
    wait 1;
    println( "APX_HUD_TEST weapon=" + bot getCurrentWeapon() + " ammo=" + bot.apxHudAmmo + " state=" + bot.sessionstate );
    assertex( bot getCurrentWeapon() == "colt45_mp", "APX_HUD_RUNTIME_FAIL: active weapon" );
    assertex( bot.apxHudAmmo == "colt45_mp:5:37:1", "APX_HUD_RUNTIME_FAIL: numeric ammo" );
    bot.health = 80;
    wait 0.15;
    assertex( isDefined( bot.apxDamageText ) && bot.apxDamageTotal == 20, "APX_HUD_RUNTIME_FAIL: actual health delta" );
    bot.health = 65;
    wait 0.15;
    assertex( bot.apxDamageTotal == 35, "APX_HUD_RUNTIME_FAIL: burst damage coalesced" );
    bot.health = 90;
    wait 0.8;
    assertex( !isDefined( bot.apxDamageText ) && bot.apxDamageFlash == 0, "APX_HUD_RUNTIME_FAIL: feedback cleanup" );
    assertex( bot.apxHudPreviousHP == 90, "APX_HUD_RUNTIME_FAIL: healing tracked" );
    bot braxi\_teams::setTeam( "spectator" );
    wait 0.2;
    assertex( bot.apxHudAmmo == "none:0:0:0", "APX_HUD_RUNTIME_FAIL: spectator ammo hidden" );
    bot braxi\_teams::setTeam( "allies" );
    bot braxi\_player::spawnPlayer();
    wait 0.3;
    assertex( !isDefined( bot.apxDamageText ) && bot.apxDamageFlash == 0, "APX_HUD_RUNTIME_FAIL: spawn baseline" );
    println( "APX_HUD_RUNTIME_PASS: ammo, damage bursts, healing, cleanup, spectators and respawn" );
}
