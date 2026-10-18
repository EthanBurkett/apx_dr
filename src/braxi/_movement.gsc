///////////////////////////////////////////////////////////////
////|         |///|        |///|       |/\  \/////  ///|  |////
////|  |////  |///|  |//|  |///|  |/|  |//\  \///  ////|__|////
////|  |////  |///|  |//|  |///|  |/|  |///\  \/  /////////////
////|          |//|  |//|  |///|       |////\    //////|  |////
////|  |////|  |//|         |//|  |/|  |/////    \/////|  |////
////|  |////|  |//|  |///|  |//|  |/|  |////  /\  \////|  |////
////|  |////|  |//|  | //|  |//|  |/|  |///  ///\  \///|  |////
////|__________|//|__|///|__|//|__|/|__|//__/////\__\//|__|////
///////////////////////////////////////////////////////////////
/*
	BraXi's Death Run Mod
	(c) 2010-2020 Paulina Sokołowska

	https://www.moddb.com/mods/braxs-death-run-mod

	Twitter: https://twitter.com/TheBraXi
	GitHub: https://github.com/BraXi/

	E-mail: paulinabraxi somewhere at gmail.com
*/

#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;

#include braxi\_common;
#include braxi\_dvar;

// Responsibility: movement. See docs/ARCHITECTURE.md.

bunnyHoop()
{
    self endon( "disconnect" );
    self endon( "spawned_player" );
    self endon( "joined_spectators" );
    self endon( "death" );

    while( game["state"] != "playing" )
		wait 0.05;

    if( !level.dvar["bunnyhoop"] )
        return; 

    while( isAlive( self ) )
    {
		wait 0.05;
        stance = self getStance();
        useButton = self useButtonPressed();
        onGround = self isOnGround();
        fraction = bulletTrace( self getEye(), self getEye() + vector_scale(anglesToForward(self.angles), 32 ), true, self )["fraction"];
        
        // Begin
        if( !self.doingBH && useButton && !onGround && fraction == 1 )
        {
            self setClientDvars( "bg_viewKickMax", 0, "bg_viewKickMin", 0, "bg_viewKickRandom", 0, "bg_viewKickScale", 0 );
            self.doingBH = true;
        }

        // Accelerate
        if( self.doingBH && useButton && onGround && stance == "stand" && fraction == 1 )
        {
            if( self.bh < 120 )
                self.bh += 30;
        }

        // Finish
        if( self.doingBH && !useButton || self.doingBH && stance != "stand" || self.doingBH && fraction < 1 )
        {
            self setClientDvars( "bg_viewKickMax", 90, "bg_viewKickMin", 5, "bg_viewKickRandom", 0.4, "bg_viewKickScale", 0.2 );
            self.doingBH = false;
            self.bh = 0;
            continue;
        }

        // Bounce
        if( self.bh && self.doingBH && onGround && fraction == 1 )
        {
            bounceFrom = (self.origin - vector_scale( anglesToForward( self.angles ), 50 )) - (0,0,42);
            bounceFrom = vectorNormalize( self.origin - bounceFrom );
            self bounce( bounceFrom, self.bh );
            self bounce( bounceFrom, self.bh );
            wait 0.1;
        }
    }
}

advancedJumping()
{
	// NOTE! This code is extremly EXPERIMENTAL AND GLITCHY
	self endon( "disconnect" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );
	self endon( "death" );

	if( !isDefined( self.bh ) )
		self.bh = 0;

	wait 1;

	while( self isReallyAlive() )
	{
		while( self isOnGround() || self.bh ) // don't do that if we're not on the ground or we're bunny hooping
			wait 0.1;

		while( self.sessionstate == "playing" && !self isOnGround() && !self.bh )
		{	
			// @BUG: looks like player can jump forward abit longer
			//iprintln( "advanced jump: " + num );
			vec = ( self.origin + (0,0,-1) + vector_scale( anglesToForward( self.angles ), 9 ) );
			endPos = playerPhysicsTrace( self.origin, vec );
			self setOrigin( (endPos[0], endPos[1], self.origin[2] ) );
			wait 0.05;
		}
		wait 0.1; // delay before another advanced jump
	}
}

isAngleOk( angles, min, max )
{
	diff = distance( angles, self.angles );
	iprintln( "diff:" + diff );
	if( diff >= min && diff <= max )
		return true;
	return false;
}
