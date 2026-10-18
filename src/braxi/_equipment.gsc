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

// Responsibility: equipment. See docs/ARCHITECTURE.md.

// Two carried weapons for human players; special free runs remain melee-only.
spawnEquipment()
{
	weapon = level.itemInfo[self getStat( 981 )]["item"];
	secondary = true;
	if( self.pers["team"] == "axis" ) weapon = "tomahawk_mp";
	if( level.trapsDisabled && (!isDefined( level.efrActive ) || !level.efrActive) )
	{
		weapon = self braxi\_content_unlocks::selectedKnife();
		secondary = false;
	}
	if( self.model == "german_sheperd_dog" ) { weapon = "dog_mp"; secondary = false; }
	self equipWeapons( weapon, secondary );
}

equipWeapons( weapon, secondary )
{
	self takeAllWeapons();
	self setActionSlot( 2, "" );
	self.pers["weapon"] = weapon;
	self giveWeapon( weapon );
	self giveMaxAmmo( weapon );
	if( secondary )
	{
		knife = self braxi\_content_unlocks::selectedKnife();
		if( knife != weapon ) self giveWeapon( knife );
		// Also expose direct selection without changing the player's bindings.
		self setActionSlot( 2, "weapon", knife );
	}
	self setSpawnWeapon( weapon );
}

watchDog()
{
    self endon( "disconnect" );
    self endon( "spawned_player" );
    self endon( "joined_spectators" );
    self endon( "death" );

	if( !self.pers["isDog"] )
		return;

	iPrintln( self.name + " ^7is a Dog!" );
	self.isDog = false;
	while( self isReallyAlive() )
	{
		if( self isOnLadder() || self isMantling() )
		{
			self makeMeHuman();
		}
		else 
		{
			self makeMeDog();
		}

		if( self.isDog && self getCurrentWeapon() != "dog_mp" )
		{
			self.isDog = false;
			self makeMeDog();
		}

		wait 0.05;
	}
}

makeMeDog()
{
	if( self.isDog )
		return;

	self.isDog = true;

	self setModel( "german_sheperd_dog" );
	weapon = "dog_mp";
	self equipWeapons( weapon, false );
	self switchToWeapon( weapon );
}

makeMeHuman()
{
	if( !self.isDog )
		return;

	self.isDog = false;

	self braxi\_teams::setPlayerModel();
	self spawnEquipment();
	self switchToWeapon( self.pers["weapon"] );
}

sprayLogo()
{
	self endon( "disconnect" );
	self endon( "spawned_player" );
	self endon( "joined_spectators" );
	self endon( "death" );

	if( !level.dvar["sprays"] )
		return;

	while( game["state"] != "playing" )
		wait 0.05;

	while( self isReallyAlive() )
	{
		while( !self fragButtonPressed() )
			wait .2;

		if( !self isOnGround() )
		{
			wait 0.2;
			continue;
		}

		angles = self getPlayerAngles();
		eye = self getTagOrigin( "j_head" );
		forward = eye + vector_scale( anglesToForward( angles ), 70 );
		trace = bulletTrace( eye, forward, false, self );
		
		if( trace["fraction"] == 1 ) //we didnt hit the wall or floor
		{
			wait 0.1;
			continue;
		}

		position = trace["position"] - vector_scale( anglesToForward( angles ), -2 );
		angles = vectorToAngles( eye - position );
		forward = anglesToForward( angles );
		up = anglesToUp( angles );

		sprayNum = self getStat( 979 );


		if( isDefined( self.pers["customSpray"] ) )
			sprayNum = 25;

		if( sprayNum < 0 )	
			sprayNum = 0;
		else if( sprayNum >= level.numSprays )
			sprayNum = level.numSprays - 1;

		playFx( level.sprayInfo[sprayNum]["effect"], position, forward, up );
		self playSound( "sprayer" );

		self notify( "spray", sprayNum, position, forward, up ); // ch_sprayit

		wait level.dvar["sprays_delay"];
	}
}

watchItems()
{
	if( !level.dvar["insertion"] || self.pers["team"] == "axis" /*|| !self.pers["lifes"]*/ )
		return;

	self endon( "spawned_player" );
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "joined_spectators" );


	insertionItem = "claymore_mp";
	self giveWeapon( insertionItem );
	self giveMaxAmmo( insertionItem );
	self setActionSlot( 3, "weapon", insertionItem );

	while( self isReallyAlive() )
	{
		self waittill( "grenade_fire", entity, weapName );

		if( weapName != insertionItem )
			continue;

		self giveMaxAmmo( insertionItem );

		entity waitTillNotMoving();
		if( !isDefined( entity ) ) continue;
		pos = entity.origin;
		angle = entity.angles;
		//entity delete();

		if( !self isOnGround() || distance( self.origin, pos ) > 48 )
		{
			self iPrintlnBold( "^1You can't use insertion here" );
			entity delete();
			continue;
		}

		self cleanUpInsertion();
		self.insertion = entity;
		/*self.insertion = spawn( "script_model", pos );
		self.insertion.angles = angle;
		self.insertion setModel( "mil_frame_charge" );*/

		self iPrintlnBold( "^2Insertion at " + pos );
	}
}

cleanUpInsertion()
{
	if( isDefined( self.insertion ) )
		self.insertion delete();
//	self.insertion = undefined;
}
