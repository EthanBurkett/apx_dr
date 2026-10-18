menuDef
	{
		name			"main_text"
		fullScreen		1
		rect			0 0 640 480
		focusColor		COLOR_FOCUSED
		soundloop 		"music_mainmenu_mp"
		onOpen
		{ 
			exec "selectStringTableEntryInDvar mp/didyouknow.csv 0 didyouknow";
			//execondvarintvalue ui_close_main 1 "closemenu main_text";
			
			// temp CAC (for dev only)
			//exec "set customclass1 @CLASS_CLASS1";
			//exec "set customclass2 @CLASS_CLASS2";
			//exec "set customclass3 @CLASS_CLASS3";
			//exec "set customclass4 @CLASS_CLASS4";
			//exec "set customclass5 @CLASS_CLASS5";	
		}
		onClose
		{
		}
		onESC 
		{
		}

		// Menu items -------------------------------------------
		#include "ui/bg.inc"

		//#include "ui/background_bars.menu"

		APX_LOGO(400,48,160,80,0 0,1,when(!localvarBool(ui_hideBack)))

		
		#define SETUP_ACTION_CREATEACLASS \
				execnow "statset 260 1"; \
				play "mouse_click"; \
				open pc_cac_popup;
				
		#define CLEARUIHINT	exec "set ui_hint_text @MP_NULL"
				
		CHOICE_BUTTON_VIS( 1, "@MENU_AUTO_UPDATE", open auconfirm;, when( dvarbool( cl_updateAvailable ) && !localvarBool( ui_hideBack ) ) )
		CHOICE_BUTTON_VIS( 2, "@MENU_JOIN_GAME", open pc_join_unranked;, when( !localvarBool( ui_hideBack ) ) )
		CHOICE_BUTTON_VIS( 3, "@MENU_START_NEW_SERVER", close self; open createserver;, when( !localvarBool( ui_hideBack ) ) )

		CHOICE_SEPARATOR_VIS( CHOICE_SEP_1, when( !localvarBool( ui_hideBack ) ) )

		CHOICE_BUTTON_VIS( 4, "@MENU_SELECT_PROFILE", setdvar ui_playerProfileAlreadyChosen 0; open player_profile;, when( !localvarBool( ui_hideBack ) ) )
		
		//CHOICE_BUTTON_VIS( 5, "Create a Class", open pc_cac_popup;, when( !localvarBool( ui_hideBack ) && stat(260) ) )
		CHOICE_BUTTON_VIS( 5, "@MENU_RANK_AND_CHALLENGES", open menu_challenges;, when( !localvarBool( ui_hideBack ) ) )
	
		CHOICE_SEPARATOR_VIS( CHOICE_SEP_2, when( !localvarBool( ui_hideBack ) ) )
		
		CHOICE_BUTTON_VIS( 6, "@MENU_CONTROLS", open main_controls;, when( !localvarBool( ui_hideBack ) ) )
		CHOICE_BUTTON_VIS( 7, "@MENU_OPTIONS", open main_options;, when( !localvarBool( ui_hideBack ) ) )
		
		CHOICE_SEPARATOR_VIS( CHOICE_SEP_3, when( !localvarBool( ui_hideBack ) ) )
		
		CHOICE_BUTTON_VIS( 8, "@BRAXI_ABOUT", open single_popmenu;, when( !localvarBool( ui_hideBack ) ) )
		CHOICE_BUTTON_VIS( 9, "@MENU_MODS", close self; open mods_menu;, when( !localvarBool( ui_hideBack ) ) )
		CHOICE_BUTTON_VIS( 10, "@MENU_QUIT", open quit_popmenu;, when( !localvarBool( ui_hideBack ) ) )

		CHOICE_FOOTNOTE_VIS( "@BRAXI_GAME_EXPERIENCE_CHANGED", 40, 420, when( !localvarBool( ui_hideBack ) ) )


//////// ADMIN TOOLS ////////
		itemDef
		{
			visible			1
			rect			-800 -800 2000 2000
			forecolor		1 1 1 1
			style			WINDOW_STYLE_SHADER
			background		"black"
			//visible 		when( stat(990) == 1 );
			visible 		when( dvarstring(ui_dr_info) != "" );
			decoration
		}

		itemDef 
		{
			visible 		when( dvarstring(ui_dr_info) != "" );
			rect			-800 -800 2000 2000
			forecolor		1 1 1 1
			type			ITEM_TYPE_BUTTON
			text			" . "
			textfont		UI_FONT_NORMAL
			textscale		.3
			textalignx		8
			textaligny		16
			action
			{
				play "mouse_click";
				execnow "exec cleanup.cfg";
			}
			onFocus
			{
			}
		}

		itemDef
		{
			visible 		when( dvarstring(ui_dr_info) != "" );
			origin			320 200
			forecolor		1 1 1 1
			text			"@BRAXI_NOTICE"
			textfont		UI_FONT_NORMAL
			textalign		ITEM_ALIGN_CENTER
			textscale		.4
			decoration
		}
		APX_LOGO(264,139,112,56,0 0,1,when(dvarString(ui_dr_info)!=""))

		itemDef
		{
			visible 		when( dvarstring(ui_dr_info) != "" );
			origin			320 220
			forecolor		1 1 1 1
			exp				text( dvarstring(ui_dr_info) );
			textfont		UI_FONT_NORMAL
			textalign		ITEM_ALIGN_CENTER
			textscale		.44
			decoration
		}
		itemDef
		{
			visible 		when( dvarstring(ui_dr_info2) != "" );
			origin			320 238
			forecolor		1 1 1 1
			exp				text( dvarstring(ui_dr_info2) );
			textfont		UI_FONT_NORMAL
			textalign		ITEM_ALIGN_CENTER
			textscale		.44
			decoration
		}
////////////////////////
	}
