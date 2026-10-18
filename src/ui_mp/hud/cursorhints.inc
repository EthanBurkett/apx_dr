menuDef
	{
		name			"Cursorhints"
		rect			0 60 40 40 HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_CENTER
		fullScreen		0
		visible			1 //when( dvarInt( ui_hud_hardcore ) == 0 && !ui_active() ) // BraX

		itemDef
		{
			name			"chRect"
			rect			0 0 40 40 // 64x64
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_CURSORHINT
			visible			when( NOT_SPECTATING )
			decoration
		}
	}
