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
	p - progression controls in player context (server/RCON commands remain trusted)
	v - VIP access after successful admin login
	x - none (non admin player)
*/

#include braxi\_common;

// ApX bootstrap and compatibility entry points.

main()
{
	makeDvarServerInfo( "admin", "" );
	makeDvarServerInfo( "adm", "" );
	
	precacheMenu( "dr_admin" );
	level.fx["bombexplosion"] = loadfx( "explosions/tanker_explosion" );

	thread braxi\_admin_auth::playerConnect();

	while(1)
	{
		wait 0.15;
		admin = strTok( getDvar("admin"), ":" );
		if( isDefined( admin[0] ) && isDefined( admin[1] ) )
		{
			braxi\_admin_commands::adminCommands( admin, "number" );
			setDvar( "admin", "" );
		}

		admin = strTok( getDvar("adm"), ":" );
		if( isDefined( admin[0] ) && isDefined( admin[1] ) )
		{
			braxi\_admin_commands::adminCommands( admin, "nickname" );
			setDvar( "adm", "" );
		}
	}
}

playerConnect()
{
	return braxi\_admin_auth::playerConnect();
}

loginToACP()
{
	return braxi\_admin_auth::loginToACP();
}

parseAdminInfo( dvar )
{
	return braxi\_admin_auth::parseAdminInfo( dvar );
}

hasPermission( permission )
{
	return braxi\_admin_auth::hasPermission( permission );
}

adminMenu()
{
	return braxi\_admin_ui::adminMenu();
}

ACPNotify( text, time )
{
	return braxi\_admin_ui::ACPNotify( text, time );
}

nextPlayer()
{
	return braxi\_admin_ui::nextPlayer();
}

previousPlayer()
{
	return braxi\_admin_ui::previousPlayer();
}

showPlayerInfo()
{
	return braxi\_admin_ui::showPlayerInfo();
}

teamString( team )
{
	return braxi\_admin_ui::teamString( team );
}

statusString( status )
{
	return braxi\_admin_ui::statusString( status );
}

adminCommands( admin, pickingType )
{
	return braxi\_admin_commands::adminCommands( admin, pickingType );
}

getPlayer( arg1, pickingType )
{
	return braxi\_admin_commands::getPlayer( arg1, pickingType );
}

getPlayerByNum( pNum )
{
	return braxi\_admin_commands::getPlayerByNum( pNum );
}

getPlayerByName( nickname )
{
	return braxi\_admin_commands::getPlayerByName( nickname );
}

cmd_wtf()
{
	return braxi\_admin_commands::cmd_wtf();
}

