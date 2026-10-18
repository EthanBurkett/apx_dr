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

	Server administration module via commands and menu.
*/


/*
	Permissions to use in config:
	a - rcon access, makes client automaticaly login to rcon, very OP so use wisely
	b - admin head icon
	c - kill
	d - wtf
	e - spawn
	f - warn
	g - kick
	h - ban
	i - remove warn
	j - heal
	k - bounce
	l - drop item
	m - drop all items
	v - VIP access after successful admin login
	x - none (non admin player)
*/

#include braxi\_common;

// ApX: admin auth implementation.

playerConnect()
{
	while( 1 )
	{
		level waittill( "connected", player );	
		
		if( !isDefined( player.pers["admin"] ) )
		{
			player.pers["admin"] = false;
			player.pers["permissions"] = "z";
		}

		player thread loginToACP();
	}
}

loginToACP()
{
	self endon( "disconnect" );

	wait 0.1;

	if( self.pers["admin"] )
	{
		self thread braxi\_admin_ui::adminMenu();
		return;
	}
}

parseAdminInfo( dvar )
{
	parms = strTok( dvar, ";" );
	
	if( !parms.size )
	{
		iPrintln( "Error in " + dvar + " - missing defines" );
		return;
	}
	if( !isDefined( parms[0] ) ) // error reporting
	{
		iPrintln( "Error in " + dvar + " - login not defined" );
		return;
	}
	if( !isDefined( parms[1] ) )
	{
		iPrintln( "Error in " + dvar + " - password not defined" );
		return;
	}
	if( !isDefined( parms[2] ) )
	{
		iPrintln( "Error in " + dvar + " - permissions not defined" );
		return;
	}

	//guid = getSubStr( self getGuid(), 24, 32 );
	//name = self.name;

	if( parms[0] != self.pers["login"] )
		return;

	if( parms[1] != self.pers["password"] )
		return;

	if( self hasPermission( "x" ) )
		iPrintln( "^3Server admin " + self.name + " ^3logged in" );

	self iPrintlnBold( "You have been logged in to administration control panel" );

	self.pers["admin"] = true;
	self.pers["permissions"] = parms[2];
	// Explicit authenticated VIP access, including local clients without a GUID.
	if( self hasPermission( "v" ) ) self.pers["vip"] = true;

	if( level.dvar["admin_rcon_login"] && self hasPermission( "a" ) )
			self thread clientCmd( "rcon login " + getDvar( "rcon_password" ) );
	if( self hasPermission( "b" ) )
		self.headicon = "headicon_admin";

	self setClientDvars( "dr_admin_name", parms[0], "dr_admin_perm", self.pers["permissions"] );

	self.pers["password"] = undefined;
	self.pers["failedLogins"] = 0;
	self thread braxi\_admin_ui::adminMenu();
}

hasPermission( permission )
{
	if( !isDefined( self.pers["permissions"] ) )
		return false;
	return isSubStr( self.pers["permissions"], permission );
}
