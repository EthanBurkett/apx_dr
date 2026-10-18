menuDef
	{
    	name			"stance"
    	// place this offscreen so it doesn't show the stance indicator but only shows the "prone blocked"
		rect			-1000 -1000 48 48 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_BOTTOM
    	fullScreen		0
		visible			when( !flashbanged() && !ui_active() && NOT_SPECTATING );

		itemDef
		{
			name			"chRect"
			rect			0 0 80 80 // 64x64
			ownerdraw		CG_PLAYER_STANCE
			textfont		UI_FONT_OBJECTIVE
			visible			when( !inkillcam() && !selecting_location() && dvarint( ui_hud_hardcore ) == 0 );
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			forecolor		1 1 1 HUD_ALPHA
			decoration
		}
	}
