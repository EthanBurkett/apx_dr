// Legacy DMS entry points backed by ApX's native menu ballot.
// Original DMS: Bipo / Mr-X / iNext Gaming. No carousel or FIRE hooks.
playerVisuals() { self braxi\_intermission::open(); }
playerDelVisuals() { self closeMenu( "apx_intermission" ); }
updateVotes() { braxi\_vote_players::recount(); }
createVisuals() { }
delVisuals() { }
updateWinningMap() { }
nextIndex() { }
prevIndex() { }
scaleFont( value, duration ) { }
getIndex( index )
{
    if( !isDefined(level.maps) || !level.maps.size ) return 0;
    return ((index%level.maps.size)+level.maps.size)%level.maps.size;
}
getFontSize( index ) { return 1; }
getAlpha( index ) { return 1; }
getX( index ) { return 0; }
getY( index ) { return 0; }
