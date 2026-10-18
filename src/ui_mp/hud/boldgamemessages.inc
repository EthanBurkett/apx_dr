menuDef
	{
		name			"boldgamemessages"
		// (todo: use VERTICAL_ALIGN_TOP in SP, origin 0 180)
		rect			0 -60 10 10 HORIZONTAL_ALIGN_CENTER_SAFEAREA VERTICAL_ALIGN_CENTER_SAFEAREA
		fullScreen		0
		visible			when( !inkillcam() );
		
		itemDef
		{
			origin				0 0
			type				ITEM_TYPE_GAME_MESSAGE_WINDOW
			gamemsgwindowindex	1
			gamemsgwindowmode	MODE_BOTTOMUP_ALIGN_BOTTOM
			textfont			UI_FONT_OBJECTIVE
			textstyle			ITEM_TEXTSTYLE_SHADOWED
			textalign			ITEM_ALIGN_CENTER
			textscale			0.417 // SP: 0.5
			visible				when ( dvarint( ui_hud_obituaries ) == 1 && !ui_active() );
		}
	}
