// Isolated bot-only EFR lifecycle test, never included in the release.
run()
{
    wait 1;
    if( isDefined( game["efr_test_handoff"] ) )
    {
        ensureParticipants( 3 );
        wait 1;
        check( !level.efrActive, "handoff does not loop back into practice" );
        check( game["roundsplayed"] == 1, "practice does not consume a round" );
        println( "APX_EFR_RUNTIME_PASS: practice, population, respawn, XP guard, cancellation and restart handoff" );
        return;
    }
    check( level.efrActive && level.freeRun && !game["roundStarted"], "practice owns the readyup phase" );
    ensureParticipants( 2 );
    wait 0.5;
    players = braxi\_common::getAllPlayers();
    bot = players[0];
    bot setStat( 2301, 1234 );
    bot.pers["rankxp"] = 1234;
    bot braxi\_prestige::syncProfile();
    bot braxi\_rank_integrity::updateAntiHackValues();
    bot braxi\_rank::giveRankXP( "kill", 100 );
    check( bot getStat( 2301 ) == 1234 && !braxi\_missions::mayProcessChallenges(), "practice does not farm XP or challenges" );
    bot suicide();
    check( plugins\_efr::participantCount() == 2, "dead participant still counts" );
    wait 0.5;
    check( bot.sessionstate == "playing", "practice respawn" );
    ensureParticipants( 3 );
    wait 0.5;
    check( level.efrCountdown > 0, "start countdown" );
    players = braxi\_common::getAllPlayers();
    third = players[2];
    third braxi\_teams::setTeam( "spectator" );
    wait 0.5;
    check( plugins\_efr::participantCount() == 2 && level.efrCountdown == 0, "spectating cancels countdown" );
    game["efr_test_handoff"] = true;
    third braxi\_teams::setTeam( "allies" );
    third braxi\_player::spawnPlayer();
}

ensureParticipants( count )
{
    players = braxi\_common::getAllPlayers();
    while( players.size < count )
    {
        bot = addTestClient();
        check( isDefined( bot ), "add practice bot" );
        wait 0.2;
        players = braxi\_common::getAllPlayers();
    }
    for( i = 0; i < count; i++ )
    {
        players[i] braxi\_teams::setTeam( "allies" );
        if( players[i].sessionstate != "playing" ) players[i] braxi\_player::spawnPlayer();
    }
}

check( condition, message )
{
    assertex( condition, "APX_EFR_RUNTIME_FAIL: " + message );
}
