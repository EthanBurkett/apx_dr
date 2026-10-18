// Player-owned presentation preferences. Stat 2400 versions this small schema.
// These IDs are separate from progression, customization and integrity mirrors.
load()
{
    if( self getStat( 2400 ) != 1 ) self defaults();
    fov = self getStat( 2401 );
    if( fov < 65 || fov > 120 ) self setStat( 2401, 90 );
    for( stat = 2402; stat <= 2404; stat++ )
        if( self getStat( stat ) < 0 || self getStat( stat ) > 1 ) self setStat( stat, 0 );
    self apply();
}

defaults()
{
    self setStat( 2400, 1 );
    self setStat( 2401, 90 );
    self setStat( 2402, 0 ); // Fullbright
    self setStat( 2403, 0 ); // FPS display
    self setStat( 2404, 0 ); // Minimal HUD, zero preserves normal HUD
}

apply()
{
    fov = self getStat( 2401 );
    // Stock cg_fov caps at 80. Scale it for the wider CoD4x view choices.
    self setClientDvars( "cg_fov", 80, "cg_fovScale", float(fov)/80,
        "r_fullbright", self getStat( 2402 ), "cg_drawFPS", self getStat( 2403 ) );
    self setClientDvars( "apx_pref_fov", fov, "apx_pref_fullbright", self getStat( 2402 ),
        "apx_pref_fps", self getStat( 2403 ), "apx_pref_minimal", self getStat( 2404 ),
        "apx_pref_thirdperson", self getStat( 988 ) );
    self setClientDvars( "cg_thirdperson", self getStat( 988 ),
        "apx_minimal_hud", self getStat( 2404 ) );
}

set( key, value )
{
    if( key == "fov" )
    {
        value = braxi\_admin_progression::parseInteger( value, 65, 120 );
        if( value < 0 ) return false;
        self setStat( 2401, value );
    }
    else
    {
        stat = -1;
        if( key == "fullbright" ) stat = 2402;
        if( key == "fps" ) stat = 2403;
        if( key == "minimal" ) stat = 2404;
        if( key == "thirdperson" ) stat = 988;
        if( stat < 0 ) return false;
        value = braxi\_admin_progression::parseInteger( value, 0, 1 );
        if( value < 0 ) return false;
        self setStat( stat, value );
    }
    self apply();
    return true;
}
