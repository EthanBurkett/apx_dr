menuDef
	{
		name			"character_stuff"
		rect			0 0 640 480
		focuscolor		COLOR_FOCUSED
		style			WINDOW_STYLE_EMPTY
		blurWorld		7.0
		legacySplitScreenScale
		
		onOpen
		{
			execNow "set menuName Customize Character";
			//UPDATE_CHARACTER;
		}
		onClose
		{
		}
		onEsc
		{
			close self;
			open "team_select";
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

		DR_BUTTON( "0", 100, 110, 180, 20, "Characters", close self; open "dr_characters";, 1 )
		DR_BUTTON( "1", 100, 135, 180, 20, "Sprays", close self; open "dr_sprays";, 1 )
		
		DR_BUTTON( "2", 100, 170, 180, 20, "Weapons", close self; open "dr_weapons";, 1 )
		DR_BUTTON( "3", 100, 195, 180, 20, "Abilities", close self; open "dr_abilities";, 1 )

		DR_BUTTON( "4", 100, 230, 180, 20, "Challenges", close self; open "menu_challenges";, 1 )
		DR_BUTTON( "5", 100, 255, 180, 20, "Prestige", close self; open "apx_prestige";, 1 )

		DR_BUTTON( "6", 100, 290, 180, 20, "Done", close self; open "team_select";, 1 )
	}
