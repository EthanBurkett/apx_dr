// Real server/bot decisions and native-menu opening. No human profiles touched.
run()
{
    wait 1;
    if(isDefined(game["apxPresentationRestart"]))
    {
        managed=[];
        for(i=0;i<40;i++)
        {
            managed=braxi\_test_bots::managedPlayers();
            if(managed.size==2 && game["apxTestBotRun"]>=2 &&
                isDefined(managed[0].apxBotRunSerial) && managed[0].apxBotRunSerial==game["apxTestBotRun"] &&
                isDefined(managed[1].apxBotRunSerial) && managed[1].apxBotRunSerial==game["apxTestBotRun"]) break;
            wait .25;
        }
        check(managed.size==2,"test players survive preserving restart without duplicates");
        check(managed[0].apxBotRunSerial==game["apxTestBotRun"] && managed[1].apxBotRunSerial==game["apxTestBotRun"],"bot lifecycle reattached after restart");
        setDvar("g_bots",0);
        println("APX_PRESENTATION_RUNTIME_PASS: records, rotation, ballots, native menu phases and bot restart lifecycle");
        return;
    }
    bot = addTestClient();
    check( isDefined(bot), "create bot" );
    for(i=0;i<100 && !isDefined(bot.pers["rank"]);i++) wait .05;
    check(isDefined(bot.pers["rank"]),"profile initialized");
    setDvar("g_bots",2);
    managed=[];
    for(i=0;i<40;i++)
    {
        managed=braxi\_test_bots::managedPlayers();
        if(managed.size==2) break;
        wait .25;
    }
    check(managed.size==2,"two managed test Jumpers created");
    check(managed[0].pers["team"]=="allies" && managed[1].pers["team"]=="allies","managed bots join Jumpers");
    setDvar("g_bots",0);
    for(i=0;i<32;i++)
    {
        managed=braxi\_test_bots::managedPlayers();
        if(!managed.size) break;
        wait .25;
    }
    check(!managed.size && isDefined(bot),"remove only managed test players");
    check( !braxi\_intermission::validResult("time",99999999), "sentinel rejected" );
    check( braxi\_intermission::betterResult("time",31.25,0), "first valid finish sets record" );
    check( !braxi\_intermission::betterResult("time",45.0,31.25), "slower finish rejected" );
    setDvar("apx_rotation_page_count",2);
    setDvar("apx_rotation_0","map mp_backlot map mp_dr_lithium");
    setDvar("apx_rotation_1","map mp_deathrun_long map mp_backlot");
    rotation=braxi\_vote_maps::getMaprotation();
    check( rotation.size==3, "bounded rotation pages deduplicated" );
    next=braxi\_vote_maps::nextMap();
    check( next.mapname=="mp_dr_lithium", "sequential rotation crosses full collection" );
    bot.pers["time"]=99999999;
    check( !isDefined(braxi\_common::getBestPlayerFromTime()), "unfinished bot is not time leader" );
    bot.pers["time"]=31.25;
    braxi\_intermission::prepareResults();
    check( level.bestScores[5]["value"]==31.25, "fractional finish record retained" );
    level.maps=[];
    level.maps[0]=braxi\_vote_maps::addMapItem("mp_dr_lithium","deathrun");
    level.maps[1]=braxi\_vote_maps::addMapItem("mp_deathrun_long","deathrun");
    level.apxPostPhase=1;
    level.apxPostEnds=getTime()+10000;
    level.mapvote=1;
    for(i=0;i<20;i++) bot braxi\_vote_players::cast("0");
    check(level.maps[0].votes==1,"repeated requests remain one ballot");
    bot braxi\_vote_players::cast("1");
    check(level.maps[0].votes==0 && level.maps[1].votes==1,"ballot replaced");
    bot braxi\_vote_players::cast("clear");
    check(level.apxVoteTotal==0,"ballot cleared");
    check(!bot braxi\_vote_players::cast("abc"),"malformed ballot rejected");
    check(!bot braxi\_vote_players::cast("99"),"out-of-range ballot rejected");
    braxi\_intermission::present(0,1);
    level thread braxi\_intermission::present(1,2);
    wait .7;
    bot notify("menuresponse","-1","ui:apx_intermission:vote:0");
    wait .1;
    check(bot.voteindex==0,"real menu envelope casts ballot");
    wait 2;
    check(!bot braxi\_vote_players::cast("1"),"expired vote rejected");
    braxi\_intermission::present(2,1);
    braxi\_intermission::close();
    setDvar("g_bots",2);
    for(i=0;i<40;i++)
    {
        managed=braxi\_test_bots::managedPlayers();
        if(managed.size==2) break;
        wait .25;
    }
    check(managed.size==2,"test players ready for preserving restart");
    game["apxPresentationRestart"]=true;
    map_restart(true);
}

check(condition,message)
{
    assertex(condition,"APX_PRESENTATION_RUNTIME_FAIL: "+message);
    println("APX_PRESENTATION_CHECK: "+message);
}
