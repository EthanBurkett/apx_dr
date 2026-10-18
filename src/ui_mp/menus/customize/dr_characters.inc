menuDef
	{
		name			"dr_characters"
		rect			0 0 640 480
		focuscolor		COLOR_FOCUSED
		style			WINDOW_STYLE_EMPTY
		blurWorld		7.0
		legacySplitScreenScale
		
		onOpen
		{
			execNow "set menuName Characters"
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

		DR_CHARACTER( 100, 1 )
		DR_CHARACTER( 127, 5 )
		DR_CHARACTER( 154, 6 )
		DR_CHARACTER( 181, 7 )
		DR_CHARACTER( 208, 8 )
		DR_CHARACTER( 235, 9 )
		DR_CHARACTER( 262, 11 )
		DR_CHARACTER( 289, 12 )

// specialty_locked specialty_new
	}
