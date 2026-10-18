menuDef
	{
    	name			"MantleHint"
    	rect			0 105 40 40 HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_CENTER
		fullScreen		0
		visible			when( dvarInt( ui_hud_hardcore ) == 0 )

		itemDef
		{
			name			"chRect"
			rect			0 0 40 40
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_MANTLE_HINT
			visible			when( NOT_SPECTATING )
			decoration
		}
	}
