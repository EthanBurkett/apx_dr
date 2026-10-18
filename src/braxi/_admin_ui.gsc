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
	x - none (non admin player)
*/

#include braxi\_common;

// ApX: admin ui implementation.

adminMenu()
{
	self notify( "apx_admin_listener" );
	self endon( "apx_admin_listener" );
	self endon( "disconnect" );
	
	self.selectedPlayer = 0;
	self showPlayerInfo();

	action = undefined;
	reason = undefined;

	while(1)
	{ 
		self waittill( "menuresponse", menu, response );
		action = undefined;
		reason = undefined;

		if( menu != "dr_admin" || !self.pers["admin"] )
			continue;

		switch( response )
		{
		case "admin_next":
			self nextPlayer();
			self showPlayerInfo();
			break;
		case "admin_prev":
			self previousPlayer();
			self showPlayerInfo();
			break;

		/* group 1 */
		case "admin_kill":
			if( self braxi\_admin_auth::hasPermission( "c" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;
		case "admin_wtf":
			if( self braxi\_admin_auth::hasPermission( "d" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;
		case "admin_spawn":
			if( self braxi\_admin_auth::hasPermission( "e" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;


		/* group 2 */
		case "admin_warn":
			if( self braxi\_admin_auth::hasPermission( "f" ) )
			{
				action = strTok(response, "_")[1];
				reason = self.name + " decission";
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_kick":
		case "admin_kick_1":
		case "admin_kick_2":
		case "admin_kick_3":
			if( self braxi\_admin_auth::hasPermission( "g" ) )
			{
				ref = strTok(response, "_");
				action = ref[1];
				reason = self.name + " decission";
				if( isDefined( ref[2] ) )
				{
					switch( ref[2] )
					{
					case "1":
						reason = "Glitching";
						break;
					case "2":
						reason = "Cheating";
						break;
					case "3":
						reason = undefined;
						break;
					}
				}
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_ban":
		case "admin_ban_1":
		case "admin_ban_2":
		case "admin_ban_3":
			if( self braxi\_admin_auth::hasPermission( "h" ) )
			{
				ref = strTok(response, "_");
				action = ref[1];

				reason = self.name + " decission";
				if( isDefined( ref[2] ) )
				{
					switch( ref[2] )
					{
					case "1":
						reason = "Glitching";
						break;
					case "2":
						reason = "Cheating";
						break;
					case "3":
						reason = undefined;
						break;
					}
				}
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_rw":
			if( self braxi\_admin_auth::hasPermission( "i" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_row":
			if( self braxi\_admin_auth::hasPermission( "i" ) ) //both share same permission
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		/* group 3 */
		case "admin_heal":
			if( self braxi\_admin_auth::hasPermission( "j" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;
		case "admin_bounce":
			if( self braxi\_admin_auth::hasPermission( "k" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;
		case "admin_drop":
			if( self braxi\_admin_auth::hasPermission( "l" ) )
				action = strTok(response, "_")[1];
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_teleport":
			if( self braxi\_admin_auth::hasPermission( "m" ) )
				action = "teleport";
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );	
			break;

		case "admin_teleport2":
			if( self braxi\_admin_auth::hasPermission( "m" ) )
			{
				player = undefined;
				if( isDefined( self.apxAdminTarget ) )
					player = braxi\_admin_commands::getPlayerByNum( self.apxAdminTarget );
				else
					continue;
				if( isDefined( player ) && player getGuid() == self.apxAdminTargetGuid && player.sessionstate == "playing" )
				{
					player setOrigin( self.origin );
					player iPrintlnBold( "You were teleported by admin" );
				}
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );	
			break;

		/* group 4 */
		case "admin_restart":
		case "admin_restart_1":
			if( self braxi\_admin_auth::hasPermission( "n" ) )
			{
				ref = strTok(response, "_");
				action = ref[1];
				if( isDefined( ref[2] ) )
					reason = ref[2];
				else
					reason = 0;
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;

		case "admin_finish":
		case "admin_finish_1":
			if( self braxi\_admin_auth::hasPermission( "o" ) )
			{
				ref = strTok(response, "_");
				action = ref[1];
				if( isDefined( ref[2] ) )
					reason = ref[2]; //sounds stupid but in this case reason is value
				else
					reason = 0;
			}
			else
				self thread ACPNotify( "You don't have permission to use this command", 3 );
			break;
		}

		target = undefined;
		if( isDefined( self.apxAdminTarget ) ) target = braxi\_admin_commands::getPlayerByNum( self.apxAdminTarget );
		if( isDefined( action ) && isDefined( target ) && isPlayer( target ) && target getGuid() == self.apxAdminTargetGuid )
		{
			cmd = [];
			cmd[0] = action;
			cmd[1] = target getEntityNumber();
			cmd[2] = reason;

			if( action == "restart" || action == "finish" )	
				cmd[1] = reason;	// BIG HACK HERE

			braxi\_admin_commands::adminCommands( cmd, "number" );
			action = undefined;
			reason = undefined;

			self showPlayerInfo();
		}
	}		
}

ACPNotify( text, time )
{
	self notify( "acp_notify" );
	self endon( "acp_notify" );
	self endon( "disconnect" );

	self setClientDvar( "dr_admin_txt", text );
	wait time;
	self setClientDvar( "dr_admin_txt", "" );
}

nextPlayer()
{
	players = getAllPlayers();

	self.selectedPlayer++;
	if( self.selectedPlayer >= players.size )
		self.selectedPlayer = players.size-1;
}

previousPlayer()
{
	self.selectedPlayer--;
	if( self.selectedPlayer <= -1 )
		self.selectedPlayer = 0;
}

showPlayerInfo()
{
	players = getAllPlayers();
	if( !players.size )
		return;
	if( self.selectedPlayer < 0 || self.selectedPlayer >= players.size )
		self.selectedPlayer = 0;
	player = players[self.selectedPlayer];
	self.apxAdminTarget = player getEntityNumber();
	self.apxAdminTargetGuid = player getGuid();
	
	self setClientDvars( "dr_admin_p_n", player.name,
						 "dr_admin_p_h", (player.health+"/"+player.maxhealth),
						 "dr_admin_p_t", teamString( player.pers["team"] ),
						 "dr_admin_p_s", statusString( player.sessionstate ),
						 "dr_admin_p_w", (player getStat(level.dvar["warns_stat"])+"/"+level.dvar["warns_max"]),
						 "dr_admin_p_skd", (player.score+"-"+player.kills+"-"+player.deaths),
						 "dr_admin_p_g", player getGuid() );
}

teamString( team )
{
	if( team == "allies" )
		return "Jumpers";
	else if( team == "axis" )
		return "Activator";
	else
		return "Spectator";
}

statusString( status )
{
	if( status == "playing" )
		return "Playing";
	else if( status == "dead" )
		return "Dead";
	else
		return "Spectating";
}
