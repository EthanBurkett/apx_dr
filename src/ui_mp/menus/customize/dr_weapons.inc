menuDef
	{
		name			"dr_weapons"
		rect			0 0 640 480
		focuscolor		COLOR_FOCUSED
		style			WINDOW_STYLE_EMPTY
		blurWorld		7.0
		legacySplitScreenScale
		
		onOpen
		{
			execNow "set menuName Weapons"
		}

		onClose
		{
		}

		onEsc
		{
			close self;
			open "character_stuff";
		}
		
		#include "ui_mp/dr_menu_frame.inc"
		
		// separator
		itemDef 
		{
			rect			319 90 2 360

			style			WINDOW_STYLE_SHADER
			background		"white"
			forecolor		1 1 1 0.6
			visible			1
			decoration
		}

		#include "ui_mp/dr_characters_common.inc"

		DR_WEAPON( 100, 1 )
		DR_WEAPON( 140, 2 )
		DR_WEAPON( 180, 3 )
		DR_WEAPON( 220, 4 )
		DR_WEAPON( 260, 5 )
		DR_WEAPON( 300, 6 )
		DR_WEAPON( 340, 7 )
		DR_WEAPON( 380, 8 )
	}
