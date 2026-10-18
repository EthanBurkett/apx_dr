menuDef
	{
		IMPROVED_POPUP_SETUP( "join_game_popup", 4, 12, 112, ;, 1 )
		//CHOICE_BUTTON( 1, "Ranked Games", close self; close "main_text"; open pc_join_ranked )
		CHOICE_BUTTON( 3, "Ranked Games", close self; close "main_text"; open pc_join_unranked )
		CHOICE_BUTTON( 4, "Unranked Games", close self; close "main_text"; open pc_join_unranked )
		//CHOICE_BUTTON( 3, "@MENU_CANCEL", close self )
	}
