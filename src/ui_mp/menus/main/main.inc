menuDef
	{
		name			"main"
		fullScreen		1
		rect			0 0 640 480
		focusColor		COLOR_FOCUSED
		soundloop 		"music_mainmenu_mp"
		onOpen
		{ 
			// Restore native scoreboard dimensions after leaving this mod's server.
			setdvar cg_scoreboardWidth "500";
			setdvar cg_scoreboardBannerHeight "35";
			setdvar cg_scoreboardHeight "435";
			setdvar cg_scoreboardItemHeight "18";
			open main_text;
			uiScript addPlayerProfiles;
			uiScript openMenuOnDvar com_playerProfile "" player_profile;
			uiScript openMenuOnDvarNot ui_playerProfileCount 1 player_profile;
			uiScript stopRefresh;
			setdvar ui_showEndOfGame "0";
		}
		onClose
		{
		}
		onESC 
		{
		}
	}
