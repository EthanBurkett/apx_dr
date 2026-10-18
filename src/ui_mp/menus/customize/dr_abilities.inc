menuDef
	{
		name			"dr_abilities"
		rect			0 0 640 480
		focuscolor		COLOR_FOCUSED
		style			WINDOW_STYLE_EMPTY
		blurWorld		7.0
		legacySplitScreenScale
		
		onOpen
		{
			execNow "set menuName Abilities"
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

		DR_ABILITY( 100, 1 )
		DR_ABILITY( 140, 2 )
		DR_ABILITY( 180, 3 )
		DR_ABILITY( 220, 4 )
		DR_ABILITY( 260, 5 )
		DR_ABILITY( 300, 6 )
		DR_ABILITY( 340, 7 )
		DR_ABILITY( 380, 8 )
	}
