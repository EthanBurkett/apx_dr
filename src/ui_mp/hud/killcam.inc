menuDef
	{
		name			"killcam"
		rect			0 0 640 480 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN
		fullScreen		0
		visible 		when ( inkillcam() );

		itemDef
		{
			style			WINDOW_STYLE_SHADER
			rect			0 0 640 112 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN
			background		"white"
			forecolor		.49 .05 .03 0.5
			visible			1
			decoration
		}
		
		itemDef
		{
			style			WINDOW_STYLE_SHADER
			rect			0 368 640 112 HORIZONTAL_ALIGN_FULLSCREEN VERTICAL_ALIGN_FULLSCREEN
			background		"white"
			forecolor		.49 .05 .03 0.5
			visible			1
			decoration
		}

		itemDef 
		{
			rect		0 45 1 1 HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_TOP
			origin		0 0
			exp text	( "KILLCAM" );
			textfont	UI_FONT_OBJECTIVE
			textscale	0.90
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWEDMORE
			visible 	1
			decoration 
		}
	}
