menuDef
	{
    	name			"talkers"
		rect			0 120 24 24 HORIZONTAL_ALIGN_LEFT VERTICAL_ALIGN_TOP
    	fullScreen		0
    	visible			when( dvarString( "show_hud" ) == "true" );

		itemDef
		{
			name			"talker1Rect"
			rect			0 0 24 24
			forecolor		1 1 1 1
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_TALKER1
			visible			1
			decoration
		}

		itemDef
		{
			name			"talker2Rect"
			rect			0 24 24 24
			forecolor		1 1 1 1
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_TALKER2
			visible			1
			decoration
		}

		itemDef
		{
			name			"talker3Rect"
			rect			0 48 24 24
			forecolor		1 1 1 1
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_TALKER3
			visible			1
			decoration
		}

		itemDef
		{
			name			"talker4Rect"
			rect			0 72 24 24
			forecolor		1 1 1 1
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_TALKER4
			visible			1
			decoration
		}
	}
