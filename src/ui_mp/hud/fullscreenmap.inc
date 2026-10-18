menuDef
	{
		name			"FullScreenMap"
 	   	rect			-100 -100 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_CENTER
 	   	fullScreen		0
  	   	visible			1
		
		#define FSM_VISIBILITY (selecting_location() && NOT_SPECTATING)
		
		itemDef
 	   	{
			name			"map_map"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			background		"compass_map_default"
			ownerdraw		CG_PLAYER_FULLMAP_MAP
			visible			when( FSM_VISIBILITY );
			decoration
 	   	}
		itemDef
 	   	{
			name			"map_locator"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			background		"compass_map_default"
			ownerdraw		CG_PLAYER_FULLMAP_LOCATION_SELECTOR
			visible			when( FSM_VISIBILITY );
			decoration
 	   	}
		// Objective pointers
		itemDef
		{
			name			"mappointers"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			background		"objective_line"
			ownerdraw		CG_PLAYER_FULLMAP_POINTERS
			visible			when( FSM_VISIBILITY );
			decoration
		}
 	   	// Friendlies pointers
		itemDef
		{
			name			"mapfriendlies"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			ownerdraw		CG_PLAYER_FULLMAP_FRIENDS
			visible			when( FSM_VISIBILITY );
		}
 	   	// Enemies pointers
		itemDef
		{
			name			"mapenemies"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			ownerdraw		CG_PLAYER_FULLMAP_ENEMIES
			visible			when( FSM_VISIBILITY );
		}
		// Player direction indicator
		itemDef
		{
			name			"mapplayer"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			background		"compassping_player"
			ownerdraw		CG_PLAYER_FULLMAP_PLAYER
			visible			when( FSM_VISIBILITY );
		}

		// border
		itemDef
		{
			name			"mapborder"
			rect			0 0 FULL_SCREEN_MAP_WIDTH FULL_SCREEN_MAP_HEIGHT
			forecolor		1 1 1 1
			background		"map_border"
			ownerdraw		CG_PLAYER_FULLMAP_BORDER
			visible			when( FSM_VISIBILITY );
			decoration
		}
		
		// instruction
		itemDef
		{
			name			"airstrikeinstruction"
			rect			100 -60 20 20
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_CENTER
			textscale		0.4
			forecolor		1 1 1 1
			text			"@PLATFORM_PRESS_TO_SET_AIRSTRIKE"
			visible			when( FSM_VISIBILITY );
			decoration
		}
	}
