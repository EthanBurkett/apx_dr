// ApX local round-testing clients. These are timed test players, not map AI.
#include braxi\_common;

isTestPlayer( player )
{
    return isDefined(player.pers["apxTestBot"]) && player.pers["apxTestBot"];
}

managedPlayers()
{
    result=[];
    players=getAllPlayers();
    for(i=0;i<players.size;i++)
        if(isTestPlayer(players[i])) result[result.size]=players[i];
    return result;
}

run()
{
    wait 3;
    for(;;)
    {
        target=int(braxi\_prestige::clamp(getDvarInt("g_bots"),0,8));
        bots=managedPlayers();
        if(bots.size>target)
        {
            // Only remove clients created by this controller, never humans.
            kick(bots[bots.size-1] getEntityNumber());
        }
        else if(bots.size<target)
        {
            bot=addTestClient("ApX Test Jumper "+(bots.size+1));
            if(isDefined(bot)) bot thread setup();
        }
        wait 2;
    }
}

setup()
{
    self endon("disconnect");
    for(i=0;i<100 && (!isDefined(self.pers["team"]) || !isDefined(self.pers["rank"]));i++) wait .05;
    if(!isDefined(self.pers["rank"])) return;
    self.pers["apxTestBot"]=true;
    self braxi\_teams::setTeam("allies");
    self braxi\_player::spawnPlayer();
    for(;;)
    {
        if(self.sessionstate=="playing") self thread expire();
        self waittill("spawned_player");
    }
}

expire()
{
    self endon("disconnect");
    self endon("spawned_player");
    self endon("death");
    self endon("joined_spectators");
    // Practice must remain stable while enough participants are joining.
    while(isDefined(level.efrActive) && level.efrActive) wait .25;
    wait 20;
    if(self.sessionstate=="playing" && game["state"]=="playing") self suicide();
}
