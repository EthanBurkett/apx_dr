menuDef 
	{
		name			"HoldBreathHint"
		rect			0 -130 0 0 HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_CENTER
		fullScreen		0
		visible when ( !adsjavelin() && dvarString( "show_hud" ) == "true" && !inkillcam() && NOT_SPECTATING );

		itemDef 
		{
			name			"chRect"
			rect			0 0 0 0
			textscale		TEXTSIZE_SMALL
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			ownerdraw		CG_HOLD_BREATH_HINT
			visible			1
			decoration
		}
	}
