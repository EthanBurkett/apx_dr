menuDef
	{
		name			"Low Health"
		rect			0 0 640 480 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN
		fullScreen		0
		visible			1

		itemDef
		{
			name			"healthoverlay"
			rect			0 0 640 480
			forecolor		1 1 1 0.3
			background		"overlay_low_health"
			ownerdraw		CG_PLAYER_LOW_HEALTH_OVERLAY
			visible			1
			decoration
		}
	}
