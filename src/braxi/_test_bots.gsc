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
    if(!isDefined(game["apxTestBotRun"])) game["apxTestBotRun"]=0;
    game["apxTestBotRun"]++;
    // map_restart(true) preserves client pers data but terminates old threads.
    // Reattach the lifecycle to surviving test players once per new controller.
    existing=managedPlayers();
    for(i=0;i<existing.size;i++) existing[i] thread setup();
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
    self.apxBotRunSerial=game["apxTestBotRun"];
    if(self.pers["team"]!="allies" && self.pers["team"]!="axis") self braxi\_teams::setTeam("allies");
    if(self.sessionstate!="playing") self braxi\_player::spawnPlayer();
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
