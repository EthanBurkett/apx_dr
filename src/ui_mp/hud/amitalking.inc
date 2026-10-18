menuDef
	{
    	name			"amitalking"
		rect			116 22 32 32 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_TOP
    	fullScreen		0
    	visible			when( dvarString( "show_hud" ) == "true" );

		itemDef
		{
			name			"talkingRect"
			rect			0 0 26 26
			forecolor		1 1 1 1
			textscale		0.4
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		UI_AMITALKING
			visible			1
			decoration
		}
	}
