menuDef
	{
		name			"DPad"
		rect			0 0 640 480
		legacySplitScreenScale

 	   //	rect			BOTTOM_RECT_X (BOTTOM_RECT_Y-32) 25 25 HORIZONTAL_ALIGN_CENTER VERTICAL_ALIGN_BOTTOM
		//exp				rect Y( (BOTTOM_RECT_Y-42) - (ONLINEGAME * ONLINEGAME_OFFSET) );
 	   	fullScreen		0
		visible			when( !inkillcam() && !flashbanged() && !ui_active() && !scoped() && (dvarString( "show_hud" ) == "true") );


		// first : actionslot 2
		itemDef 
        {
			name			"slot2"
			rect			612 324 DPAD_BASE_SIZE DPAD_BASE_SIZE
			ownerdraw		CG_PLAYER_ACTIONSLOT_2
			forecolor		1 1 1 HUD_ALPHA
			visible			1
			decoration
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_LEFT
			textscale		TEXTSIZE_SMALL
			textfont		UI_FONT_OBJECTIVE
        }

		itemDef 
		{
			rect		600 342 1 1
			exp text	( "[" + KeyBinding( "+actionslot 2" ) + "]" );
			forecolor	1 1 1 0
			exp forecolor A	( HUD_ALPHA * HudFade( "dpad" ) )
			textfont	UI_FONT_OBJECTIVE
			textscale	0.25
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWED
			visible 	when( ActionSlotUsable( 2 ) )
			decoration 
		}
		
		// second : actionslot 3
		itemDef 
        {
			name			"slot3"
			rect			612 354 DPAD_BASE_SIZE DPAD_BASE_SIZE
			ownerdraw		CG_PLAYER_ACTIONSLOT_3
			forecolor		1 1 1 HUD_ALPHA
			visible			1
			decoration
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_LEFT
			textscale		TEXTSIZE_SMALL
			textfont		UI_FONT_OBJECTIVE
        }

		itemDef 
		{
			rect		600 372 1 1
			exp text	( "[" + KeyBinding( "+actionslot 3" ) + "]" );
			forecolor	1 1 1 0
			exp forecolor A	( HUD_ALPHA * HudFade( "dpad" ) )
			textfont	UI_FONT_OBJECTIVE
			textscale	0.25
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWED
			visible 	when( ActionSlotUsable( 3 ) )
			decoration 
		}

		// third : actionslot 1
		itemDef 
        {
			name			"slot1"
			rect			612 384 DPAD_BASE_SIZE DPAD_BASE_SIZE
			ownerdraw		CG_PLAYER_ACTIONSLOT_1
			forecolor		1 1 1 HUD_ALPHA
			visible			1
			decoration
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_LEFT
			textscale		TEXTSIZE_SMALL
			textfont		UI_FONT_OBJECTIVE
        }

		itemDef 
		{
			rect		600 402 1 1
			exp text	( "[" + KeyBinding( "+actionslot 1" ) + "]" );
			forecolor	1 1 1 0
			exp forecolor A	( HUD_ALPHA * HudFade( "dpad" ) )
			textfont	UI_FONT_OBJECTIVE
			textscale	0.25
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWED
			visible 	when( ActionSlotUsable( 1 ) )
			decoration 
		}

		/*itemDef // Left
        {
            name			"slot3"
            rect			(-DPAD_ICON_SPACING - DPAD_BASE_SIZE) DPAD_ICON_Y DPAD_BASE_SIZE DPAD_BASE_SIZE
			ownerdraw		CG_PLAYER_ACTIONSLOT_3
			forecolor		1 1 1 HUD_ALPHA
			visible			1 
			decoration
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_LEFT
			textscale		TEXTSIZE_SMALL
			textfont		UI_FONT_DEFAULT
        }
		itemDef 
		{
			rect		(-DPAD_ICON_SPACING - DPAD_BASE_SIZE_HALF) DPAD_LABEL_Y 1 1
			exp text	( "[" + KeyBinding( "+actionslot 3" ) + "]" );
			forecolor	1 1 1 0
			exp forecolor A	( HUD_ALPHA * HudFade( "dpad" ) )
			textfont	UI_FONT_OBJECTIVE
			textscale	0.25
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWED
			visible 	when( ActionSlotUsable( 3 ) )
			decoration 
		}

		itemDef // Right
        {
            name			"slot4"
            rect			DPAD_ICON_SPACING DPAD_ICON_Y DPAD_BASE_SIZE DPAD_BASE_SIZE
			ownerdraw		CG_PLAYER_ACTIONSLOT_4
			forecolor		1 1 1 HUD_ALPHA
			visible			1
			decoration
			textstyle		ITEM_TEXTSTYLE_SHADOWED
			textalign		ITEM_ALIGN_LEFT
			textscale		TEXTSIZE_SMALL
			textfont		UI_FONT_DEFAULT
        }
		itemDef 
		{
			rect		(DPAD_ICON_SPACING + DPAD_BASE_SIZE_HALF) DPAD_LABEL_Y 1 1
			exp text	( "[" + KeyBinding( "+actionslot 4" ) + "]" );
			forecolor	1 1 1 0
			exp forecolor A	( HUD_ALPHA * HudFade( "dpad" ) )
			textfont	UI_FONT_OBJECTIVE
			textscale	0.25
			textalign	ITEM_ALIGN_CENTER
			textstyle	ITEM_TEXTSTYLE_SHADOWED
			visible 	when( ActionSlotUsable( 4 ) )
			decoration 
		}*/
    }
