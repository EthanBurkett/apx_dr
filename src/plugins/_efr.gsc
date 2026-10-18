// ApX Endless Free Run, rebuilt from Rycoon's EFR 1.0 concept.

#include braxi\_common;

init( modVers )
{
    level.efrPluginLoaded = true;
}

isEnabled()
{
    return level.dvar["usePlugins"] && isDefined( level.efrPluginLoaded ) && getDvarInt( "plugin_efr_enable" );
}

participantCount()
{
    players = getAllPlayers();
    count = 0;
    for( i = 0; i < players.size; i++ )
        if( isPlayer( players[i] ) && isDefined( players[i].pers["team"] ) &&
            (players[i].pers["team"] == "allies" || players[i].pers["team"] == "axis") ) count++;
    return count;
}

nextDeadline( count, required, now, deadline, delay )
{
    if( count < required ) return -1;
    if( deadline < 0 ) return now + delay*1000;
    return deadline;
}

secondsLeft( now, deadline )
{
    if( deadline < 0 || now >= deadline ) return 0;
    return int( (deadline-now+999)/1000 );
}

runWarmup()
{
    level endon( "intermission" );
    level.efrActive = false;
    level.efrCountdown = 0;
    if( !isEnabled() ) return false;
    required = level.dvar["pi_efr_min"];
    delay = level.dvar["pi_efr_rt"];
    // Let clients finish the restart handoff without immediately re-entering
    // practice while their team assignments are still being restored.
    if( isDefined( game["efr_ready"] ) && game["efr_ready"] )
    {
        game["efr_ready"] = false;
        grace = getTime() + 5000;
        while( participantCount() < required && getTime() < grace ) wait 0.25;
    }
    if( participantCount() >= required ) return false;
    level.efrActive = true;
    level.freeRun = true;
    level.allowSpawn = true;
    game["state"] = "playing";
    game["roundStarted"] = false;
    visionSetNaked( level.mapName, 0 );
    braxi\_rounds::disableTraps();
    players = getAllPlayers();
    for( i = 0; i < players.size; i++ )
    {
        if( players[i].pers["team"] == "axis" ) players[i] braxi\_teams::setTeam( "allies" );
        if( players[i].sessionstate == "playing" )
        {
            players[i] unLink();
            players[i] enableWeapons();
        }
        else if( players[i].pers["team"] == "allies" ) players[i] thread braxi\_player::respawn();
    }
    deadline = -1;
    while( isEnabled() )
    {
        count = participantCount();
        now = getTime();
        deadline = nextDeadline( count, required, now, deadline, delay );
        level.efrCountdown = secondsLeft( now, deadline );
        if( deadline >= 0 && now >= deadline && participantCount() >= required ) break;
        wait 0.25;
    }
    // Reset map-owned traps and practice state once, preserving profiles and
    // round number. Normal first-free-round settings still apply afterward.
    game["efr_ready"] = true;
    level.efrRestarting = true;
    println( "APX_EFR_HANDOFF: restarting practice into the regular round controller" );
    map_restart( true );
    return true;
}
