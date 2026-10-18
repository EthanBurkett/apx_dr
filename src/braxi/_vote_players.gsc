// ApX native-menu ballots. Original DMS: Bipo / Mr-X / iNext Gaming.
#include braxi\_common;

cast( requested )
{
    if( !isDefined( level.apxPostPhase ) || level.apxPostPhase != 1 || !level.mapvote ||
        getTime() >= level.apxPostEnds ) return false;
    if( requested == "clear" ) index = -1;
    else
    {
        if( requested.size != 1 || !isSubStr( "012345", requested ) ) return false;
        index = int(requested);
        if( index+"" != requested || index < 0 || index >= level.maps.size ) return false;
    }
    self.voteindex = index;
    recount();
    self braxi\_intermission::publishBallot();
    return true;
}

recount()
{
    // Count connected players so disconnects/repeated requests cannot leak votes.
    for( i = 0; i < level.maps.size; i++ ) level.maps[i].votes = 0;
    level.apxVoteTotal = 0;
    players = getAllPlayers();
    for( i = 0; i < players.size; i++ )
    {
        index = players[i].voteindex;
        if( !isDefined( index ) || index < 0 || index >= level.maps.size ) continue;
        level.maps[index].votes++;
        level.apxVoteTotal++;
    }
}

playerVote() { self braxi\_intermission::open(); }
playerStartVoting() { self braxi\_intermission::open(); }
playerUpdateVotes() { self braxi\_intermission::publishBallot(); }

incVote()
{
    index = 0;
    if( isDefined( self.voteindex ) ) index = (self.voteindex+1)%level.maps.size;
    self cast( index+"" );
}

decVote()
{
    index = 0;
    if( isDefined( self.voteindex ) ) index = (self.voteindex+level.maps.size-1)%level.maps.size;
    self cast( index+"" );
}

changeVotes( index, difference )
{
    if( difference > 0 ) self cast( index+"" );
    else self cast( "clear" );
}
