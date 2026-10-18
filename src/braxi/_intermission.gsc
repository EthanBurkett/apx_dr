// ApX match report, native map ballot and credits presentation.
// Original Death Run foundation (c) 2010-2020 Paulina Sokolowska.
#include braxi\_common;

validResult( stat, value )
{
    if( !isDefined( value ) || value <= 0 ) return false;
    if( stat == "time" && value >= 99999999 ) return false;
    return true;
}

betterResult( stat, candidate, record )
{
    if( !validResult( stat, candidate ) ) return false;
    if( !validResult( stat, record ) ) return true;
    if( stat == "time" ) return candidate < record;
    return candidate > record;
}

valueLabel( stat, value )
{
    if( !validResult( stat, value ) ) return "--";
    if( stat == "time" ) return (int(float(value)*100)/100.0) + " s";
    return int(value) + "";
}

prepareResults()
{
    level.apxResults = [];
    for( i = 0; i < level.bestScores.size; i++ )
    {
        stat = level.bestScores[i]["name"];
        row = spawnStruct();
        row.stat = stat;
        row.label = braxi\_records::statToString( stat );
        row.player = "No result";
        row.value = "--";
        row.isNew = false;
        player = getBestPlayerFromScore( stat );
        if( isDefined( player ) && validResult( stat, player.pers[stat] ) )
        {
            row.player = braxi\_scoreboard_panel::displayName( player.name );
            row.value = valueLabel( stat, player.pers[stat] );
            if( betterResult( stat, player.pers[stat], float(level.bestScores[i]["value"]) ) )
            {
                braxi\_records::updateRecord( i, player );
                row.isNew = true;
            }
        }
        row.recordPlayer = "Set the first record";
        row.recordValue = "--";
        if( validResult( stat, float(level.bestScores[i]["value"]) ) )
        {
            row.recordPlayer = braxi\_scoreboard_panel::displayName( level.bestScores[i]["player"] );
            row.recordValue = valueLabel( stat, float(level.bestScores[i]["value"]) );
        }
        if( stat == "time" && !level.mapHasTimeTrigger ) row.player = "No timed finish";
        level.apxResults[level.apxResults.size] = row;
    }
}

publishResults()
{
    for( i = 0; i < level.apxResults.size; i++ )
    {
        row = level.apxResults[i];
        prefix = "apx_post_"+i+"_";
        self setClientDvars( prefix+"player", row.player, prefix+"value", row.value,
            prefix+"record_player", row.recordPlayer, prefix+"record_value", row.recordValue,
            prefix+"new", row.isNew );
        wait .05;
        if( !isDefined( self ) ) return;
    }
}

open()
{
    self endon( "disconnect" );
    if( !isDefined( level.apxPostPhase ) ) return;
    self.apxPostPhase = level.apxPostPhase;
    self setClientDvars( "apx_post_active", 1, "apx_post_phase", level.apxPostPhase,
        "apx_post_map", braxi\_maps::getMapNameString( level.mapName ),
        "apx_post_seconds", max(0,int((level.apxPostEnds-getTime()+999)/1000)),
        "apx_post_message", level.dvar["lastmessage"] );
    self setClientDvar( "cg_drawSpectatorMessages", 0 );
    self publishResults();
    if( !isDefined( self ) ) return;
    if( level.apxPostPhase == 1 ) self publishBallot();
    self closeMenu();
    self closeInGameMenu();
    self openMenu( "apx_intermission" );
}

present( phase, seconds )
{
    level.apxPostPhase = phase;
    level.apxPostEnds = getTime()+int(seconds*1000);
    while( getTime() < level.apxPostEnds )
    {
        if( phase == 1 ) braxi\_vote_players::recount();
        players = getAllPlayers();
        for( i = 0; i < players.size; i++ )
        {
            player = players[i];
            if( !isDefined( player.apxPostPhase ) || player.apxPostPhase != phase ) player thread open();
            if( !isDefined( player ) ) continue;
            player setClientDvar( "apx_post_seconds", max(0,int((level.apxPostEnds-getTime()+999)/1000)) );
            if( phase == 1 ) player publishBallot();
        }
        wait 1;
    }
}

publishBallot()
{
    signature = "";
    for( i = 0; i < level.maps.size; i++ ) signature += level.maps[i].votes+":";
    selected = -1;
    if( isDefined( self.voteindex ) ) selected = self.voteindex;
    signature += selected;
    if( isDefined( self.apxBallotCache ) && self.apxBallotCache == signature ) return;
    if( !isDefined( self.apxBallotCache ) )
    {
        for( i = 0; i < 6; i++ )
        {
            name = "";
            if( i < level.maps.size ) name = level.maps[i].visname;
            self setClientDvars( "apx_vote_name_"+i, name, "apx_vote_show_"+i, i<level.maps.size );
        }
    }
    self.apxBallotCache = signature;
    for( i = 0; i < level.maps.size; i++ ) self setClientDvar( "apx_vote_count_"+i, level.maps[i].votes );
    winning = braxi\_vote_maps::getWinningMap();
    self setClientDvars( "apx_vote_selected", selected, "apx_vote_leader", winning.visname,
        "apx_vote_total", level.apxVoteTotal );
}

close()
{
    players = getAllPlayers();
    for( i = 0; i < players.size; i++ )
    {
        players[i] closeMenu( "apx_intermission" );
        players[i] setClientDvar( "apx_post_active", 0 );
    }
    level.apxPostPhase = undefined;
}
