menuDef
	{
		name			"gamemessages"
		// (todo: use VERTICAL_ALIGN_TOP in SP)
		rect			6 -65 10 10 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_BOTTOM
		fullScreen		0
		visible			when( !inkillcam() );
		
		itemDef
		{
			origin				0 0
			type				ITEM_TYPE_GAME_MESSAGE_WINDOW
			gamemsgwindowindex	0
			gamemsgwindowmode	MODE_BOTTOMUP_ALIGN_BOTTOM
			textfont			UI_FONT_DEFAULT
			textstyle			ITEM_TEXTSTYLE_SHADOWED
			textalign			ITEM_ALIGN_LEFT
			textscale			(TEXTSIZE_SMALL*0.75)
			visible				when ( dvarint( ui_hud_obituaries ) == 1 && !ui_active() );
		}
	}
