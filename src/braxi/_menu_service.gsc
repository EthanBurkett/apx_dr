// Server-owned navigation and access. Client visibility is only presentation.
#include braxi\_common;

load()
{
    self setClientDvars( "apx_access_admin", 0, "apx_access_vip", 0 );
    if( !isDefined( self.pers["vip"] ) ) self.pers["vip"] = false;
    // Optional server-owned GUID entitlement list, compatible with the VIP plugin.
    guids = strTok( getDvar( "apx_vip_guids" ), ";" );
    for( i = 0; i < guids.size; i++ )
        if( guids[i] != "" && toLower( guids[i] ) == toLower( self getGuid() ) ) self.pers["vip"] = true;
    self.apxMenuAccess = undefined;
    self syncAccess();
}

allowed( access )
{
    if( access == "public" ) return true;
    if( access == "admin" ) return isDefined( self.pers["admin"] ) && self.pers["admin"];
    if( access == "vip" ) return isDefined( self.pers["vip"] ) && self.pers["vip"];
    return false;
}

syncAccess()
{
    admin = self allowed( "admin" );
    vip = self allowed( "vip" );
    permissions = "";
    if( admin && isDefined( self.pers["permissions"] ) ) permissions = self.pers["permissions"];
    signature = admin + ":" + vip + ":" + permissions;
    if( isDefined( self.apxMenuAccess ) && self.apxMenuAccess == signature ) return;
    self.apxMenuAccess = signature;
    self setClientDvars( "apx_access_admin", admin, "apx_access_vip", vip );
    permissionList = "abcdefghijklmnop";
    for( i = 0; i < 16; i++ )
    {
        permission = permissionList[i];
        self setClientDvar( "apx_admin_"+permission, admin && isSubStr( permissions, permission ) );
    }
}

route( destination )
{
    access = tableLookup( "mp/apx_menu_routes.csv", 0, destination, 1 );
    if( access == "" || !self allowed( access ) || tableLookup( "mp/apx_menu_routes.csv", 0, destination, 3 ) != "1" ) return false;
    self syncAccess();
    self braxi\_menu_catalog::refresh();
    if( destination == "dr_admin" ) self braxi\_admin_ui::showPlayerInfo();
    self closeMenu();
    self closeInGameMenu();
    self openMenu( destination );
    return true;
}

handle( menu, response )
{
    args = strTok( response, ":" );
    if( !args.size ) return false;
    if( args[0] == "browse" )
    {
        self braxi\_menu_browser::handle( args );
        return true;
    }
    if( args[0] == "content" )
    {
        if( args.size != 2 ) return true;
        tier = self.pers["prestige"];
        if( args[1] == "nextpage" || args[1] == "previouspage" )
        {
            if( !isDefined( self.apxRewardTier ) || !isDefined( self.apxRewardPage ) ) return true;
            page = self.apxRewardPage+1;
            if( args[1] == "previouspage" ) page = self.apxRewardPage-1;
            self braxi\_content_unlocks::publishRewards( self.apxRewardTier, page );
            return true;
        }
        if( isDefined( self.apxRewardTier ) && args[1] != "current" ) tier = self.apxRewardTier;
        if( args[1] == "next" ) tier++;
        else if( args[1] == "previous" ) tier--;
        else if( args[1] != "current" && args[1] != "open" ) return true;
        self braxi\_content_unlocks::publishRewards( tier );
        return true;
    }
    if( args[0] == "nav" )
    {
        if( args.size == 2 ) self route( args[1] );
        return true;
    }
    if( response == "apx_open" )
    {
        access = tableLookup( "mp/apx_menu_routes.csv", 0, menu, 1 );
        if( access != "" && !self allowed( access ) ) self closeMenu();
        else self braxi\_menu_catalog::refresh();
        self syncAccess();
        if( menu == "dr_admin" && self allowed( "admin" ) ) self braxi\_admin_ui::showPlayerInfo();
        return true;
    }
    if( isSubStr( menu, "apx_confirm_admin_" ) )
    {
        if( self allowed( "admin" ) && menu == "apx_confirm_"+response ) self notify( "menuresponse", "dr_admin", response );
        return true;
    }
    if( args[0] == "pref" )
    {
        if( args.size == 3 ) self braxi\_preferences::set( args[1], args[2] );
        return true;
    }
    if( response == "preferences_reset" )
    {
        self braxi\_preferences::defaults();
        self braxi\_preferences::apply();
        return true;
    }
    if( args[0] == "equip" )
    {
        if( args.size == 3 ) self braxi\_menu_catalog::equip( args[1], args[2] );
        return true;
    }
    if( response == "vip_dog" || response == "vip_spray" || response == "dog" )
    {
        if( !self allowed( "vip" ) ) return true;
        if( !isDefined( self.pers["isDog"] ) ) self.pers["isDog"] = false;
        if( response == "vip_dog" || response == "dog" ) self.pers["isDog"] = !self.pers["isDog"];
        else if( isDefined( self.pers["customSpray"] ) ) self.pers["customSpray"] = undefined;
        else self.pers["customSpray"] = true;
        self setClientDvars( "apx_vip_dog", self.pers["isDog"], "apx_vip_spray", isDefined( self.pers["customSpray"] ) );
        return true;
    }
    if( args[0] == "progression" )
    {
        if( !self allowed( "admin" ) || !self braxi\_admin_auth::hasPermission( "p" ) || args.size != 3 ) return true;
        if( !isDefined( self.apxAdminTarget ) ) return true;
        target = braxi\_admin_commands::getPlayerByNum( self.apxAdminTarget );
        if( !isDefined( target ) || !isDefined( self.apxAdminTargetGuid ) || target getGuid() != self.apxAdminTargetGuid ) return true;
        command = [];
        command[0] = args[1];
        command[1] = self.apxAdminTarget;
        command[2] = args[2];
        if( command[0] == "reset" )
        {
            if( !isDefined( self.apxResetTarget ) || self.apxResetTarget != self.apxAdminTarget || self.apxResetUntil < getTime() ) return true;
            command = strTok( "reset:"+self.apxAdminTarget, ":" );
            self.apxResetUntil = 0;
        }
        self braxi\_admin_progression::handle( command, "number" );
        self braxi\_admin_ui::showPlayerInfo();
        return true;
    }
    if( response == "reset_confirm_open" )
    {
        if( self allowed( "admin" ) && self braxi\_admin_auth::hasPermission( "p" ) )
        {
            self.apxResetTarget = self.apxAdminTarget;
            self.apxResetUntil = getTime()+30000;
            self route( "apx_reset_confirm" );
        }
        return true;
    }
    return false;
}
