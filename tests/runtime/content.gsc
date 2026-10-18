// Actual native asset/spawn/unlock coverage, only packaged in an isolated fixture.
run()
{
    wait 1;
    bot = addTestClient();
    check( isDefined( bot ), "create bot" );
    for( attempt = 0; attempt < 100 && !isDefined( bot.pers["prestige"] ); attempt++ ) wait 0.05;
    bot braxi\_teams::setTeam( "allies" );
    bot braxi\_player::spawnPlayer();
    weapons = 0;
    for( id = 0; id < level.numItems; id++ )
    {
        if( !level.itemInfo[id]["enabled"] ) continue;
        bot.pers["prestige"] = level.itemInfo[id]["prestige"];
        bot.pers["rank"] = level.itemInfo[id]["rank"];
        check( bot braxi\_rank::isItemUnlocked( id ), "weapon exact requirement "+id );
        if( bot.pers["rank"] > 0 )
        {
            bot.pers["rank"]--;
            check( !bot braxi\_rank::isItemUnlocked( id ), "weapon before requirement "+id );
        }
        weapon = level.itemInfo[id]["item"];
        bot takeAllWeapons();
        bot giveWeapon( weapon );
        bot giveMaxAmmo( weapon );
        bot switchToWeapon( weapon );
        check( bot hasWeapon( weapon ), "native weapon asset "+id );
        weapons++;
        wait 0.03;
    }
    knives = 0;
    for( id = 0; id < level.numKnives; id++ )
    {
        if( !level.knifeInfo[id]["enabled"] ) continue;
        bot.pers["prestige"] = level.knifeInfo[id]["prestige"];
        bot.pers["rank"] = level.knifeInfo[id]["rank"];
        check( bot braxi\_content_unlocks::knifeUnlocked( id ), "knife exact requirement "+id );
        if( bot.pers["rank"] > 0 )
        {
            bot.pers["rank"]--;
            check( !bot braxi\_content_unlocks::knifeUnlocked( id ), "knife before requirement "+id );
            bot.pers["rank"]++;
        }
        bot setStat( 2405, id );
        weapon = bot braxi\_content_unlocks::selectedKnife();
        check( weapon == level.knifeInfo[id]["item"], "selected knife "+id );
        bot takeAllWeapons();
        bot giveWeapon( weapon );
        bot switchToWeapon( weapon );
        check( bot hasWeapon( weapon ), "native knife asset "+id );
        knives++;
        wait 0.03;
    }
    characters = 0;
    check( weapons == 18, "only enabled primaries are precached/equippable" );
    for( id = 0; id < level.numCharacters; id++ )
    {
        if( !level.characterInfo[id]["enabled"] ) continue;
        bot.pers["prestige"] = level.characterInfo[id]["prestige"];
        bot.pers["rank"] = level.characterInfo[id]["rank"];
        check( bot braxi\_rank::isCharacterUnlocked( id ), "character exact requirement "+id );
        bot setModel( level.characterInfo[id]["model"] );
        bot setViewModel( level.characterInfo[id]["handsModel"] );
        characters++;
        wait 0.03;
    }
    for( tier = 1; tier <= level.maxPrestige; tier++ )
    {
        bot braxi\_content_unlocks::publishRewards( tier );
        check( bot.apxRewardTier == tier, "reward tier "+tier );
    }
    check( characters == 42 && knives == 9, "official client catalog counts" );
    bot.pers["prestige"] = level.maxPrestige; bot.pers["rank"] = 0;
    check( bot braxi\_rank::isItemUnlocked( 7 ), "earlier tier retained" );
    println( "APX_CONTENT_RUNTIME_PASS: "+weapons+" primaries; "+knives+" knives; "+characters+" characters; all prestige reward pages" );
}

check( condition, message )
{
    assertex( condition, "APX_CONTENT_RUNTIME_FAIL: "+message );
    println( "APX_CONTENT_CHECK: "+message );
}
